#include "liquidglass_effect.h"

#include <core/rendertarget.h>
#include <core/renderviewport.h>
#include <effect/effecthandler.h>
#include <effect/effectwindow.h>
#include <opengl/glplatform.h>
#include <opengl/glshadermanager.h>
#include <opengl/glvertexbuffer.h>

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusVariant>
#include <QMatrix4x4>
#include <QSettings>
#include <QStandardPaths>
#include <algorithm>
#include <cmath>
#include <epoxy/gl.h>

namespace Conjunction
{

namespace
{

const QByteArray kCommonVertexShader = R"(
uniform mat4 modelViewProjectionMatrix;
in vec4 position;
in vec2 texcoord;
out vec2 v_uv;

void main() {
    v_uv = texcoord;
    gl_Position = modelViewProjectionMatrix * position;
}
)";

// Separable bilinear-paired Gaussian blur shader (stepPt = 2.0 at 0.5x tex size)
const QByteArray kBlurFragmentShader = R"(
uniform sampler2D u_tex;
uniform vec2 u_dirInvTex; // direction * (1/texW, 1/texH)
uniform float u_sigmaPt;
uniform float u_stepPt;
in vec2 v_uv;
out vec4 fragColor;

void main() {
    float sigma = max(u_sigmaPt, 0.01);
    float stepPt = max(u_stepPt, 1.0);
    float inv2Sigma2 = 1.0 / (2.0 * sigma * sigma);
    vec4 accum = texture(u_tex, v_uv);
    float wSum = 1.0;

    for (int k = 1; k <= 15; ++k) {
        float nA = float(2 * k - 1);
        float nB = float(2 * k);
        float xA = nA * stepPt;
        float xB = nB * stepPt;
        float wA = exp(-(xA * xA) * inv2Sigma2);
        float wB = exp(-(xB * xB) * inv2Sigma2);
        float wPair = wA + wB;
        if (wPair > 1e-6) {
            float t = nA + wB / wPair;
            vec2 off = t * u_dirInvTex;
            accum += texture(u_tex, clamp(v_uv + off, 0.001, 0.999)) * wPair;
            accum += texture(u_tex, clamp(v_uv - off, 0.001, 0.999)) * wPair;
            wSum += 2.0 * wPair;
        }
    }
    fragColor = accum / wSum;
}
)";

// SPEC §1.6 Liquid Glass Optical Pipeline
const QByteArray kLiquidGlassFragmentShader = R"(
uniform sampler2D u_backdropBlur;
uniform vec2  u_sizePt;
uniform vec2  u_backdropSizePt;
uniform float u_marginPt;
uniform float u_cornerRadius;
uniform int   u_variant;            // 0 = Regular, 1 = Clear
uniform int   u_darkMode;           // 0 = Light, 1 = Dark
uniform int   u_reduceTransparency;
uniform int   u_highContrast;
uniform vec4  u_tintColor;
uniform float u_opacity;

in vec2 v_uv;
out vec4 fragColor;

float continuousRectSDF(vec2 p, vec2 halfSize, float r) {
    float minHalf = min(halfSize.x, halfSize.y);
    if (r <= 0.001 || minHalf <= 0.001) {
        vec2 q0 = abs(p) - halfSize;
        return -(length(max(q0, 0.0)) + min(max(q0.x, q0.y), 0.0));
    }
    float pillBlend = clamp((minHalf - r) / max(0.35 * r, 1.0), 0.0, 1.0);
    float extR = min(r * mix(1.0, 1.528665, pillBlend), minHalf);
    float expN = mix(2.0, 3.2, pillBlend);
    vec2 q = abs(p) - halfSize + vec2(extR);
    vec2 k = max(q, 0.0);
    float cornerDist = pow(pow(k.x, expN) + pow(k.y, expN), 1.0 / expN);
    return -(min(max(q.x, q.y), 0.0) + cornerDist - extR);
}

vec2 continuousGrad(vec2 p, vec2 halfSize, float r) {
    const float eps = 0.25;
    float dx = continuousRectSDF(p + vec2(eps, 0.0), halfSize, r) - continuousRectSDF(p - vec2(eps, 0.0), halfSize, r);
    float dy = continuousRectSDF(p + vec2(0.0, eps), halfSize, r) - continuousRectSDF(p - vec2(0.0, eps), halfSize, r);
    vec2 g = vec2(dx, dy);
    float l = length(g);
    return l > 1e-5 ? g / l : vec2(0.0, 1.0);
}

void main() {
    vec2 halfSize = 0.5 * u_sizePt;
    vec2 p = (v_uv - 0.5) * u_sizePt;
    float d = continuousRectSDF(p, halfSize, u_cornerRadius);
    float aa = clamp(d + 0.5, 0.0, 1.0);
    if (aa <= 0.0) discard;

    if (u_reduceTransparency == 1) {
        vec3 opaqueBg = (u_darkMode == 1) ? vec3(0.1569) : vec3(0.9255);
        if (u_highContrast == 1 && d < 1.0) {
            opaqueBg = (u_darkMode == 1) ? vec3(0.58) : vec3(0.28);
        }
        float a = aa * u_opacity;
        fragColor = vec4(opaqueBg * a, a);
        return;
    }

    float m = min(u_sizePt.x, u_sizePt.y);

    vec2 normal = continuousGrad(p, halfSize, u_cornerRadius);
    float refrAmp = (u_variant == 0) ? 31.5 : 45.21;
    float dr = (d < 24.0) ? refrAmp * exp(-max(d, 0.0) / 6.79) : 0.0;

    vec2 samplePt = vec2(u_marginPt) + v_uv * u_sizePt - normal * dr;
    vec2 uvRefr = clamp(samplePt / max(u_backdropSizePt, vec2(1.0)), 0.001, 0.999);
    // Flip Y for OpenGL FBO texture coordinates if captured upright by blit
    vec3 blurRGB = texture(u_backdropBlur, vec2(uvRefr.x, 1.0 - uvRefr.y)).rgb;

    float maxLuma = 1.0;
    if (u_variant == 0) {
        maxLuma = (u_darkMode == 1)
            ? (0.60 - 0.25 * clamp((m - 64.0) / 40.0, 0.0, 1.0))
            : 0.94;
    }
    vec3 clamped = min(blurRGB, vec3(maxLuma));

    float Y = dot(clamped, vec3(0.2126, 0.7152, 0.0722));
    float sat = (u_variant == 1) ? 1.0 : ((u_darkMode == 1) ? 1.30 : 1.20);
    float blackLvl = (u_variant == 1) ? ((u_darkMode == 1) ? 0.05 : 0.20)
                                      : ((u_darkMode == 1) ? 0.08 : 0.40);
    float whiteLvl = (u_variant == 1) ? ((u_darkMode == 1) ? 0.80 : 0.95)
                                      : ((u_darkMode == 1) ? 1.125 : 0.96);
    vec3 satRGB = vec3(Y) + sat * (clamped - vec3(Y));
    vec3 face = clamp(mix(vec3(blackLvl), vec3(whiteLvl), satRGB), 0.0, 1.0);

    vec4 faceFill = (u_variant == 1)
        ? ((u_darkMode == 1) ? vec4(1.0, 1.0, 1.0, 0.05) : vec4(1.0, 1.0, 1.0, 0.10))
        : ((u_darkMode == 1) ? vec4(0.0, 0.0, 0.0, 0.00) : vec4(1.0, 1.0, 1.0, 0.20));
    face = mix(face, faceFill.rgb, faceFill.a);

    if (u_tintColor.a > 0.001) {
        if (u_variant == 0) {
            float lumaM = dot(face, vec3(0.7638, 0.2145, 0.0217)) + ((u_darkMode == 1) ? 0.10 : -0.10);
            face = mix(face, vec3(clamp(lumaM, 0.0, 1.0)), u_tintColor.a * 0.70);
        } else {
            vec3 tinted = u_tintColor.rgb * mix(1.0, Y + 0.35, 0.45);
            face = mix(face, clamp(tinted, 0.0, 1.0), u_tintColor.a);
        }
    }

    float rimMask = 1.0 - smoothstep(0.0, 1.25, max(d, 0.0));
    float specTop = smoothstep(0.0, (u_variant == 0) ? 0.86 : 0.50, abs(-normal.y));
    float sideShade = 1.0 - smoothstep(0.3, 0.9, 1.0 - abs(normal.y));
    vec3 rimColor = (u_darkMode == 1)
        ? mix(vec3(0.29), clamp(0.3125 * face + 0.9375, 0.0, 1.35) * 0.62, specTop)
        : mix(vec3(0.73), vec3(1.0), specTop);
    float rimAmt = (u_variant == 0) ? 0.50 : 0.40;
    face = mix(face, clamp(rimColor, 0.0, 1.0), rimMask * rimAmt * (0.45 + 0.55 * max(specTop, sideShade)));

    if (u_highContrast == 1 && d < 1.0) {
        face = (u_darkMode == 1) ? vec3(0.58) : vec3(0.28);
    }

    float outA = aa * u_opacity;
    fragColor = vec4(face * outA, outA);
}
)";

void drawQuad(KWin::GLVertexBuffer *vbo, float x, float y, float w, float h, bool flipV = false)
{
    const float v0 = flipV ? 1.0f : 0.0f;
    const float v1 = flipV ? 0.0f : 1.0f;
    if (auto verts = vbo->map<KWin::GLVertex2D>(6)) {
        (*verts)[0] = {{x, y}, {0.0f, v0}};
        (*verts)[1] = {{x + w, y}, {1.0f, v0}};
        (*verts)[2] = {{x + w, y + h}, {1.0f, v1}};
        (*verts)[3] = {{x, y}, {0.0f, v0}};
        (*verts)[4] = {{x + w, y + h}, {1.0f, v1}};
        (*verts)[5] = {{x, y + h}, {0.0f, v1}};
        vbo->unmap();
        vbo->setAttribLayout(std::span(KWin::GLVertexBuffer::GLVertex2DLayout), sizeof(KWin::GLVertex2D));
        vbo->render(GL_TRIANGLES);
    }
}

} // namespace

LiquidGlassEffect::LiquidGlassEffect()
{
    reconfigure(ReconfigureAll);
    QDBusConnection::sessionBus().connect(
        QStringLiteral("org.conjunction.Settings"),
        QStringLiteral("/org/conjunction/Settings"),
        QStringLiteral("org.conjunction.Settings"),
        QStringLiteral("SettingChanged"),
        this,
        SLOT(onSettingChanged(QString, QVariant)));
}

LiquidGlassEffect::~LiquidGlassEffect() = default;

bool LiquidGlassEffect::supported()
{
    return KWin::effects->isOpenGLCompositing();
}

void LiquidGlassEffect::reconfigure(ReconfigureFlags flags)
{
    Q_UNUSED(flags)
    const QString iniPath = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation)
                            + QStringLiteral("/conjunction/settings.ini");
    QSettings qs(iniPath, QSettings::IniFormat);
    m_darkMode = (qs.value(QStringLiteral("Appearance/mode"), QStringLiteral("light")).toString() == QStringLiteral("dark"));
    m_reduceTransparency = qs.value(QStringLiteral("Accessibility/reduceTransparency"), false).toBool();
    m_increaseContrast = qs.value(QStringLiteral("Accessibility/increaseContrast"), false).toBool();

    QDBusInterface iface(QStringLiteral("org.conjunction.Settings"),
                         QStringLiteral("/org/conjunction/Settings"),
                         QStringLiteral("org.conjunction.Settings"),
                         QDBusConnection::sessionBus());
    if (iface.isValid()) {
        QDBusReply<QDBusVariant> mode = iface.call(QStringLiteral("GetSetting"), QStringLiteral("appearance.mode"));
        if (mode.isValid() && !mode.value().variant().toString().isEmpty()) {
            m_darkMode = (mode.value().variant().toString() == QStringLiteral("dark"));
        }
        QDBusReply<QDBusVariant> rt = iface.call(QStringLiteral("GetSetting"), QStringLiteral("accessibility.reduceTransparency"));
        if (rt.isValid()) m_reduceTransparency = rt.value().variant().toBool();
        QDBusReply<QDBusVariant> ic = iface.call(QStringLiteral("GetSetting"), QStringLiteral("accessibility.increaseContrast"));
        if (ic.isValid()) m_increaseContrast = ic.value().variant().toBool();
    }
}

void LiquidGlassEffect::onSettingChanged(const QString &key, const QVariant &value)
{
    if (key == QStringLiteral("appearance.mode") || key == QStringLiteral("Appearance/mode")) {
        m_darkMode = (value.toString() == QStringLiteral("dark"));
    } else if (key == QStringLiteral("accessibility.reduceTransparency") || key == QStringLiteral("Accessibility/reduceTransparency")) {
        m_reduceTransparency = value.toBool();
    } else if (key == QStringLiteral("accessibility.increaseContrast") || key == QStringLiteral("Accessibility/increaseContrast")) {
        m_increaseContrast = value.toBool();
    } else {
        return;
    }
    KWin::effects->addRepaintFull();
}

bool LiquidGlassEffect::ensureShaders()
{
    if (!m_blurShader) {
        m_blurShader = KWin::ShaderManager::instance()->loadShaderFromCode(kCommonVertexShader, kBlurFragmentShader);
    }
    if (!m_glassShader) {
        m_glassShader = KWin::ShaderManager::instance()->loadShaderFromCode(kCommonVertexShader, kLiquidGlassFragmentShader);
    }
    return bool(m_blurShader) && bool(m_glassShader);
}

bool LiquidGlassEffect::ensureBuffers(const QSize &texSize)
{
    if (m_bufSize == texSize && m_capFbo && m_blurHFbo && m_blurVFbo) {
        return true;
    }
    m_bufSize = texSize;

    auto mkPair = [&](std::unique_ptr<KWin::GLTexture> &tex, std::unique_ptr<KWin::GLFramebuffer> &fbo) -> bool {
        tex = KWin::GLTexture::allocate(GL_RGBA8, texSize);
        if (!tex) return false;
        tex->setFilter(GL_LINEAR);
        tex->setWrapMode(GL_CLAMP_TO_EDGE);
        fbo = std::make_unique<KWin::GLFramebuffer>(tex.get());
        return fbo && fbo->valid();
    };

    return mkPair(m_capTex, m_capFbo) && mkPair(m_blurHTex, m_blurHFbo) && mkPair(m_blurVTex, m_blurVFbo);
}

bool LiquidGlassEffect::shouldApplyGlass(KWin::EffectWindow *w, KWin::RectF &outRegion, qreal &outCornerRadius, bool &outIsClear) const
{
    if (!w || w->isDesktop() || w->isMinimized()) {
        return false;
    }
    const QString cls = w->windowClass().toLower();
    // Apply backdrop Liquid Glass behind shell HUD surfaces, menus, and decorated window titlebars
    if (w->isMenu() || w->isPopupMenu()) {
        outRegion = w->frameGeometry();
        outCornerRadius = 12.0;
        outIsClear = false;
        return true;
    }
    if (w->isDock() || cls.contains(QStringLiteral("conj-shelld"))) {
        // Skip transparent full-screen host overlay if height spans >95% height without dock/panel tag;
        // LayerShell panels have exact geometry matching menu bar / dock / popup
        if (w->frameGeometry().height() >= 380 && w->frameGeometry().width() >= 900) {
            return false; // Leave LayerShell full-screen wallpaper/backdrop pass unblurred
        }
        outRegion = w->frameGeometry();
        outCornerRadius = w->isDock() ? (outRegion.height() * 0.5) : 16.0;
        outIsClear = w->isDock();
        return true;
    }
    if (w->hasDecoration() && w->decorationHasAlpha()) {
        const KWin::RectF frame = w->frameGeometry();
        const KWin::RectF content = w->contentsRect();
        const qreal headerH = content.y() - frame.y();
        if (headerH >= 20.0) {
            outRegion = KWin::RectF(frame.x(), frame.y(), frame.width(), headerH);
            outCornerRadius = 16.0;
            outIsClear = false;
            return true;
        }
    }
    if (w->data(KWin::WindowForceBlurRole).toBool()) {
        outRegion = w->frameGeometry();
        outCornerRadius = 16.0;
        outIsClear = false;
        return true;
    }
    return false;
}

void LiquidGlassEffect::prePaintScreen(KWin::ScreenPrePaintData &data)
{
    KWin::effects->prePaintScreen(data);
}

void LiquidGlassEffect::prePaintWindow(KWin::RenderView *view, KWin::EffectWindow *w, KWin::WindowPrePaintData &data)
{
    KWin::RectF region;
    qreal cr = 0;
    bool clr = false;
    if (shouldApplyGlass(w, region, cr, clr)) {
        data.setTranslucent();
    }
    KWin::effects->prePaintWindow(view, w, data);
}

void LiquidGlassEffect::renderBackdropGlass(const KWin::RenderTarget &renderTarget,
                                            const KWin::RenderViewport &viewport,
                                            const KWin::RectF &glassRect,
                                            qreal cornerRadius,
                                            bool isClear,
                                            const QColor &tint,
                                            qreal opacity)
{
    if (!ensureShaders()) {
        return;
    }

    constexpr qreal marginPt = 48.0;
    const KWin::RectF vpBounds = viewport.renderRect();
    const KWin::RectF capRect(glassRect.x() - marginPt,
                              glassRect.y() - marginPt,
                              glassRect.width() + 2.0 * marginPt,
                              glassRect.height() + 2.0 * marginPt);
    const KWin::RectF intersected = capRect.intersected(vpBounds);
    if (!intersected.isValid() || intersected.width() < 2.0 || intersected.height() < 2.0) {
        return;
    }

    const int texW = std::max(8, int(std::round(capRect.width() * 0.5)));
    const int texH = std::max(8, int(std::round(capRect.height() * 0.5)));
    if (!ensureBuffers(QSize(texW, texH))) {
        return;
    }

    // 1. Blit region behind glass surface from active renderTarget into m_capFbo
    m_capFbo->blitFromRenderTarget(renderTarget, viewport, capRect.toRect(), KWin::Rect(0, 0, texW, texH));

    // Determine exact SPEC §1.2 blur sigma_pt
    const qreal m = std::min(glassRect.width(), glassRect.height());
    double sigmaPt = m_darkMode ? 10.5 : 14.0;
    if (isClear) {
        const double t = std::clamp((m - 48.0) / 72.0, 0.0, 1.0);
        sigmaPt = 2.0 * (5.0 + 5.0 * t); // 20.0 pt for m >= 120
    }

    QMatrix4x4 fboOrtho;
    fboOrtho.ortho(0.0f, float(texW), 0.0f, float(texH), -1.0f, 1.0f);
    KWin::GLVertexBuffer *vbo = KWin::GLVertexBuffer::streamingBuffer();

    const GLboolean wasBlend = glIsEnabled(GL_BLEND);
    glDisable(GL_BLEND);

    // 2. Separable Gaussian H Pass -> m_blurHFbo
    {
        KWin::GLFramebuffer::pushFramebuffer(m_blurHFbo.get());
        KWin::ShaderBinder binder(m_blurShader.get());
        m_blurShader->setUniform(KWin::GLShader::Mat4Uniform::ModelViewProjectionMatrix, fboOrtho);
        m_blurShader->setUniform("u_tex", 0);
        m_blurShader->setUniform("u_dirInvTex", QVector2D(1.0f / float(texW), 0.0f));
        m_blurShader->setUniform("u_sigmaPt", float(sigmaPt));
        m_blurShader->setUniform("u_stepPt", 2.0f);
        glActiveTexture(GL_TEXTURE0);
        m_capTex->bind();
        drawQuad(vbo, 0.0f, 0.0f, float(texW), float(texH), false);
        m_capTex->unbind();
        KWin::GLFramebuffer::popFramebuffer();
    }

    // 3. Separable Gaussian V Pass -> m_blurVFbo
    {
        KWin::GLFramebuffer::pushFramebuffer(m_blurVFbo.get());
        KWin::ShaderBinder binder(m_blurShader.get());
        m_blurShader->setUniform(KWin::GLShader::Mat4Uniform::ModelViewProjectionMatrix, fboOrtho);
        m_blurShader->setUniform("u_tex", 0);
        m_blurShader->setUniform("u_dirInvTex", QVector2D(0.0f, 1.0f / float(texH)));
        m_blurShader->setUniform("u_sigmaPt", float(sigmaPt));
        m_blurShader->setUniform("u_stepPt", 2.0f);
        glActiveTexture(GL_TEXTURE0);
        m_blurHTex->bind();
        drawQuad(vbo, 0.0f, 0.0f, float(texW), float(texH), false);
        m_blurHTex->unbind();
        KWin::GLFramebuffer::popFramebuffer();
    }

    // 4. Composite Liquid Glass optical lens onto renderTarget
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

    const KWin::RectF devRect = viewport.mapToDeviceCoordinates(glassRect);
    {
        KWin::ShaderBinder binder(m_glassShader.get());
        m_glassShader->setUniform(KWin::GLShader::Mat4Uniform::ModelViewProjectionMatrix, viewport.projectionMatrix());
        m_glassShader->setUniform("u_backdropBlur", 0);
        m_glassShader->setUniform("u_sizePt", QVector2D(float(glassRect.width()), float(glassRect.height())));
        m_glassShader->setUniform("u_backdropSizePt", QVector2D(float(capRect.width()), float(capRect.height())));
        m_glassShader->setUniform("u_marginPt", float(marginPt));
        m_glassShader->setUniform("u_cornerRadius", float(cornerRadius));
        m_glassShader->setUniform("u_variant", isClear ? 1 : 0);
        m_glassShader->setUniform("u_darkMode", m_darkMode ? 1 : 0);
        m_glassShader->setUniform("u_reduceTransparency", m_reduceTransparency ? 1 : 0);
        m_glassShader->setUniform("u_highContrast", m_increaseContrast ? 1 : 0);
        m_glassShader->setUniform("u_tintColor", QVector4D(tint.redF(), tint.greenF(), tint.blueF(), tint.alphaF()));
        m_glassShader->setUniform("u_opacity", float(opacity));

        glActiveTexture(GL_TEXTURE0);
        m_blurVTex->bind();
        drawQuad(vbo, float(devRect.x()), float(devRect.y()), float(devRect.width()), float(devRect.height()), false);
        m_blurVTex->unbind();
    }

    if (!wasBlend) {
        glDisable(GL_BLEND);
    }
}

bool LiquidGlassEffect::drawWindow(const KWin::RenderTarget &renderTarget,
                                   const KWin::RenderViewport &viewport,
                                   KWin::EffectWindow *w,
                                   int mask,
                                   const KWin::Region &deviceRegion,
                                   KWin::WindowPaintData &data)
{
    KWin::RectF region;
    qreal cr = 0;
    bool isClear = false;
    if (shouldApplyGlass(w, region, cr, isClear) && data.opacity() > 0.01) {
        renderBackdropGlass(renderTarget, viewport, region, cr, isClear, QColor(0, 0, 0, 0), data.opacity());
    }

    return KWin::effects->drawWindow(renderTarget, viewport, w, mask, deviceRegion, data);
}

bool LiquidGlassEffect::isActive() const
{
    return true;
}

} // namespace Conjunction

KWIN_EFFECT_FACTORY_SUPPORTED_ENABLED(Conjunction::LiquidGlassEffect,
                                      "metadata.json",
                                      return Conjunction::LiquidGlassEffect::supported();,
                                      return Conjunction::LiquidGlassEffect::enabledByDefault();)

#include "liquidglass_effect.moc"
