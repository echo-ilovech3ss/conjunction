#pragma once

#include <effect/effect.h>
#include <opengl/glframebuffer.h>
#include <opengl/glshader.h>
#include <opengl/gltexture.h>

#include <QColor>
#include <memory>

namespace Conjunction
{

class LiquidGlassEffect : public KWin::Effect
{
    Q_OBJECT
public:
    explicit LiquidGlassEffect();
    ~LiquidGlassEffect() override;

    static bool supported();
    static bool enabledByDefault() { return true; }

    void reconfigure(ReconfigureFlags flags) override;
    void prePaintScreen(KWin::ScreenPrePaintData &data) override;
    void prePaintWindow(KWin::RenderView *view, KWin::EffectWindow *w, KWin::WindowPrePaintData &data) override;
    bool drawWindow(const KWin::RenderTarget &renderTarget, const KWin::RenderViewport &viewport, KWin::EffectWindow *w, int mask, const KWin::Region &deviceRegion, KWin::WindowPaintData &data) override;
    bool isActive() const override;
    bool blocksDirectScanout() const override { return false; }
    int requestedEffectChainPosition() const override { return 20; }

private Q_SLOTS:
    void onSettingChanged(const QString &key, const QVariant &value);

private:
    bool ensureShaders();
    bool ensureBuffers(const QSize &texSize);
    bool shouldApplyGlass(KWin::EffectWindow *w, KWin::RectF &outRegion, qreal &outCornerRadius, bool &outIsClear) const;
    void renderBackdropGlass(const KWin::RenderTarget &renderTarget,
                             const KWin::RenderViewport &viewport,
                             const KWin::RectF &glassRect,
                             qreal cornerRadius,
                             bool isClear,
                             const QColor &tint,
                             qreal opacity);

    std::unique_ptr<KWin::GLShader> m_blurShader;
    std::unique_ptr<KWin::GLShader> m_glassShader;

    std::unique_ptr<KWin::GLTexture> m_capTex;
    std::unique_ptr<KWin::GLFramebuffer> m_capFbo;
    std::unique_ptr<KWin::GLTexture> m_blurHTex;
    std::unique_ptr<KWin::GLFramebuffer> m_blurHFbo;
    std::unique_ptr<KWin::GLTexture> m_blurVTex;
    std::unique_ptr<KWin::GLFramebuffer> m_blurVFbo;
    QSize m_bufSize;

    bool m_darkMode = false;
    bool m_reduceTransparency = false;
    bool m_increaseContrast = false;
};

} // namespace Conjunction
