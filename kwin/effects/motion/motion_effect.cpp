#include "motion_effect.h"

#include <KConfigGroup>
#include <KSharedConfig>
#include <core/renderviewport.h>
#include <effect/effecthandler.h>
#include <effect/effectwindow.h>

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDBusVariant>
#include <QSettings>
#include <QStandardPaths>
#include <QtMath>
#include <algorithm>
#include <cmath>

namespace Conjunction
{

namespace
{

// Solve cubic-bezier(x1, y1, x2, y2) for y at parametric input x in [0, 1]
double evalCubicBezier(double x, double x1, double y1, double x2, double y2)
{
    x = std::clamp(x, 0.0, 1.0);
    auto sampleX = [&](double t) {
        const double u = 1.0 - t;
        return 3.0 * u * u * t * x1 + 3.0 * u * t * t * x2 + t * t * t;
    };
    auto sampleY = [&](double t) {
        const double u = 1.0 - t;
        return 3.0 * u * u * t * y1 + 3.0 * u * t * t * y2 + t * t * t;
    };
    double lo = 0.0;
    double hi = 1.0;
    double t = x;
    for (int i = 0; i < 12; ++i) {
        const double xEst = sampleX(t);
        if (std::abs(xEst - x) < 1e-4) {
            break;
        }
        if (xEst < x) {
            lo = t;
        } else {
            hi = t;
        }
        t = 0.5 * (lo + hi);
    }
    return sampleY(t);
}

// SPEC §3.1 Underdamped spring response (mass=1, stiffness=380, damping=32) for Window Open
double evalUnderdampedSpring(double elapsedSec, double stiffness, double damping)
{
    if (elapsedSec <= 0.0) {
        return 0.0;
    }
    const double wn = std::sqrt(stiffness);
    const double zeta = damping / (2.0 * wn);
    if (zeta < 1.0) {
        const double wd = wn * std::sqrt(1.0 - zeta * zeta);
        const double decay = std::exp(-zeta * wn * elapsedSec);
        return 1.0 - decay * (std::cos(wd * elapsedSec) + (zeta * wn / wd) * std::sin(wd * elapsedSec));
    }
    return 1.0 - std::exp(-wn * elapsedSec) * (1.0 + wn * elapsedSec);
}

} // namespace

MotionEffect::MotionEffect()
{
    m_frameTimer.start();
    m_lastNs = m_frameTimer.nsecsElapsed();

    // SPEC §5.3 Default hot corner assignment: Bottom-Right = 14 (Quick Note)
    m_cornerActions[KWin::ElectricBottomRight] = 14;

    reconfigure(ReconfigureAll);

    connect(KWin::effects, &KWin::EffectsHandler::windowAdded, this, &MotionEffect::slotWindowAdded);
    connect(KWin::effects, &KWin::EffectsHandler::windowClosed, this, &MotionEffect::slotWindowClosed);
    connect(KWin::effects, &KWin::EffectsHandler::windowDeleted, this, &MotionEffect::slotWindowDeleted);

    for (KWin::EffectWindow *w : KWin::effects->stackingOrder()) {
        connect(w, &KWin::EffectWindow::minimizedChanged, this, &MotionEffect::slotWindowMinimizedChanged);
    }

    QDBusConnection::sessionBus().connect(
        QStringLiteral("org.conjunction.Settings"),
        QStringLiteral("/org/conjunction/Settings"),
        QStringLiteral("org.conjunction.Settings"),
        QStringLiteral("SettingChanged"),
        this,
        SLOT(onSettingChanged(QString, QVariant)));
}

MotionEffect::~MotionEffect()
{
    for (int i = 0; i < KWin::ELECTRIC_COUNT; ++i) {
        if (m_cornerActions[i] > 1) {
            KWin::effects->unreserveElectricBorder(static_cast<KWin::ElectricBorder>(i), this);
        }
    }
}

bool MotionEffect::supported()
{
    return KWin::OffscreenEffect::supported();
}

void MotionEffect::reconfigure(ReconfigureFlags flags)
{
    Q_UNUSED(flags)
    const QString iniPath = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation)
                            + QStringLiteral("/conjunction/settings.ini");
    QSettings qs(iniPath, QSettings::IniFormat);
    m_reducedMotion = qs.value(QStringLiteral("Accessibility/reducedMotion"), false).toBool();
    const QString minEffect = qs.value(QStringLiteral("Dock/minimizeEffect"), QStringLiteral("genie")).toString();
    m_useGenie = (minEffect.toLower() != QStringLiteral("scale"));

    m_cornerActions[KWin::ElectricTopLeft] = qs.value(QStringLiteral("HotCorners/topLeft"), 0).toInt();
    m_cornerActions[KWin::ElectricTopRight] = qs.value(QStringLiteral("HotCorners/topRight"), 0).toInt();
    m_cornerActions[KWin::ElectricBottomLeft] = qs.value(QStringLiteral("HotCorners/bottomLeft"), 0).toInt();
    m_cornerActions[KWin::ElectricBottomRight] = qs.value(QStringLiteral("HotCorners/bottomRight"), 14).toInt();

    QDBusInterface iface(QStringLiteral("org.conjunction.Settings"),
                         QStringLiteral("/org/conjunction/Settings"),
                         QStringLiteral("org.conjunction.Settings"),
                         QDBusConnection::sessionBus());
    if (iface.isValid()) {
        QDBusReply<QDBusVariant> rm = iface.call(QStringLiteral("GetSetting"), QStringLiteral("accessibility.reducedMotion"));
        if (rm.isValid()) {
            m_reducedMotion = rm.value().variant().toBool();
        }
        QDBusReply<QDBusVariant> me = iface.call(QStringLiteral("GetSetting"), QStringLiteral("dock.minimizeEffect"));
        if (me.isValid() && !me.value().variant().toString().isEmpty()) {
            m_useGenie = (me.value().variant().toString().toLower() != QStringLiteral("scale"));
        }
    }

    updateHotCorners();
}

void MotionEffect::updateHotCorners()
{
    for (int i = 0; i < KWin::ELECTRIC_COUNT; ++i) {
        const auto border = static_cast<KWin::ElectricBorder>(i);
        KWin::effects->unreserveElectricBorder(border, this);
        if (m_cornerActions[i] > 1) {
            KWin::effects->reserveElectricBorder(border, this);
        }
    }
}

void MotionEffect::onSettingChanged(const QString &key, const QVariant &value)
{
    if (key == QStringLiteral("accessibility.reducedMotion") || key == QStringLiteral("Accessibility/reducedMotion")) {
        m_reducedMotion = value.toBool();
    } else if (key == QStringLiteral("dock.minimizeEffect") || key == QStringLiteral("Dock/minimizeEffect")) {
        m_useGenie = (value.toString().toLower() != QStringLiteral("scale"));
    } else if (key.startsWith(QStringLiteral("hotCorners.")) || key.startsWith(QStringLiteral("HotCorners/"))) {
        reconfigure(ReconfigureAll);
    }
}

bool MotionEffect::borderActivated(KWin::ElectricBorder border)
{
    if (border >= KWin::ELECTRIC_COUNT) {
        return false;
    }
    const int actionCode = m_cornerActions[border];
    if (actionCode <= 1) {
        return false;
    }

    // Map SPEC §5.3 Corner Action codes to Conjunction Shell D-Bus actions
    QString method;
    switch (actionCode) {
    case 2: method = QStringLiteral("toggleOverview"); break;
    case 4: method = QStringLiteral("requestSystemAction"); break;
    case 11: method = QStringLiteral("toggleAppLauncher"); break;
    case 12: method = QStringLiteral("toggleNotificationCenter"); break;
    case 13: method = QStringLiteral("lockScreen"); break;
    case 14: method = QStringLiteral("triggerQuickNote"); break;
    default: method = QStringLiteral("triggerQuickNote"); break;
    }

    QDBusMessage msg = QDBusMessage::createMethodCall(
        QStringLiteral("org.conjunction.Shell"),
        QStringLiteral("/org/conjunction/Settings"),
        QStringLiteral("org.conjunction.Settings"),
        method);
    if (method == QStringLiteral("requestSystemAction")) {
        msg << QStringLiteral("show_desktop");
    }
    QDBusConnection::sessionBus().send(msg);
    return true;
}

bool MotionEffect::shouldAnimateWindow(KWin::EffectWindow *w) const
{
    if (!w) {
        return false;
    }
    if (w->isDesktop() || w->isDock() || w->isMenu() || w->isPopupMenu() || w->isSpecialWindow()) {
        return false;
    }
    const QString cls = w->windowClass().toLower();
    if (cls.contains(QStringLiteral("conj-shelld"))) {
        return false;
    }
    return w->isNormalWindow() || w->isDialog();
}

QRectF MotionEffect::resolveTargetIconRect(KWin::EffectWindow *w) const
{
    const KWin::RectF iconG = w->iconGeometry();
    if (iconG.isValid() && iconG.width() > 2.0 && iconG.height() > 2.0) {
        return QRectF(iconG.x(), iconG.y(), iconG.width(), iconG.height());
    }
    // Fallback target: bottom-center Dock slot on virtual/active output
    const KWin::RectF area = KWin::effects->clientArea(KWin::ScreenArea, KWin::effects->activeScreen());
    return QRectF(area.x() + area.width() * 0.5 - 32.0, area.y() + area.height() - 72.0, 64.0, 64.0);
}

void MotionEffect::startAnim(KWin::EffectWindow *w, AnimKind kind, bool keepDeleted, bool keepVisible)
{
    if (m_anims.contains(w)) {
        const auto prev = m_anims.value(w);
        if (prev.kind == AnimKind::MinimizeGenie || prev.kind == AnimKind::UnminimizeGenie) {
            unredirect(w);
        }
    }

    WindowAnim a;
    a.kind = kind;
    a.elapsedMs = 0.0;
    a.iconRect = resolveTargetIconRect(w);

    switch (kind) {
    case AnimKind::Open:           a.durationMs = 240.0; break;
    case AnimKind::Close:          a.durationMs = 167.0; break;
    case AnimKind::MinimizeGenie:  a.durationMs = 425.0; redirect(w); break;
    case AnimKind::UnminimizeGenie:a.durationMs = 310.0; redirect(w); break;
    case AnimKind::MinimizeScale:  a.durationMs = 203.0; break;
    case AnimKind::UnminimizeScale:a.durationMs = 200.0; break;
    case AnimKind::ReducedFadeIn:
    case AnimKind::ReducedFadeOut: a.durationMs = 180.0; break;
    }

    if (keepDeleted) {
        a.deletedRef = KWin::EffectWindowDeletedRef(w);
    }
    if (keepVisible) {
        a.visibleRef = KWin::EffectWindowVisibleRef(w, KWin::WindowMinimizedGrabRole);
    }

    m_anims.insert(w, a);
    KWin::effects->addRepaintFull();
}

void MotionEffect::slotWindowAdded(KWin::EffectWindow *w)
{
    if (!w) {
        return;
    }
    connect(w, &KWin::EffectWindow::minimizedChanged, this, &MotionEffect::slotWindowMinimizedChanged);

    if (!shouldAnimateWindow(w) || w->isMinimized()) {
        return;
    }
    if (w->data(KWin::WindowAddedGrabRole).isValid()) {
        return;
    }
    w->setData(KWin::WindowAddedGrabRole, QVariant::fromValue(static_cast<void *>(this)));
    startAnim(w, m_reducedMotion ? AnimKind::ReducedFadeIn : AnimKind::Open);
}

void MotionEffect::slotWindowClosed(KWin::EffectWindow *w)
{
    if (!shouldAnimateWindow(w)) {
        return;
    }
    if (w->data(KWin::WindowClosedGrabRole).isValid()) {
        return;
    }
    w->setData(KWin::WindowClosedGrabRole, QVariant::fromValue(static_cast<void *>(this)));
    startAnim(w, m_reducedMotion ? AnimKind::ReducedFadeOut : AnimKind::Close, true, true);
}

void MotionEffect::slotWindowDeleted(KWin::EffectWindow *w)
{
    if (m_anims.contains(w)) {
        unredirect(w);
        m_anims.remove(w);
    }
}

void MotionEffect::slotWindowMinimizedChanged(KWin::EffectWindow *w)
{
    if (!shouldAnimateWindow(w)) {
        return;
    }
    if (m_reducedMotion) {
        startAnim(w, w->isMinimized() ? AnimKind::ReducedFadeOut : AnimKind::ReducedFadeIn, false, w->isMinimized());
        return;
    }
    if (w->isMinimized()) {
        startAnim(w, m_useGenie ? AnimKind::MinimizeGenie : AnimKind::MinimizeScale, false, true);
    } else {
        startAnim(w, m_useGenie ? AnimKind::UnminimizeGenie : AnimKind::UnminimizeScale, false, false);
    }
}

void MotionEffect::prePaintScreen(KWin::ScreenPrePaintData &data)
{
    const qint64 nowNs = m_frameTimer.nsecsElapsed();
    const double dtMs = std::max(0.1, std::min(50.0, (nowNs - m_lastNs) / 1e6));
    m_lastNs = nowNs;

    if (!m_anims.isEmpty()) {
        data.mask |= PAINT_SCREEN_WITH_TRANSFORMED_WINDOWS;
        QList<KWin::EffectWindow *> finished;
        for (auto it = m_anims.begin(); it != m_anims.end(); ++it) {
            it->elapsedMs += dtMs;
            if (it->elapsedMs >= it->durationMs) {
                finished.append(it.key());
            }
        }
        for (KWin::EffectWindow *w : finished) {
            const auto anim = m_anims.take(w);
            if (anim.kind == AnimKind::MinimizeGenie || anim.kind == AnimKind::UnminimizeGenie) {
                unredirect(w);
            }
        }
    }

    KWin::effects->prePaintScreen(data);
}

void MotionEffect::postPaintScreen()
{
    if (!m_anims.isEmpty()) {
        KWin::effects->addRepaintFull();
    }
    KWin::effects->postPaintScreen();
}

void MotionEffect::prePaintWindow(KWin::RenderView *view, KWin::EffectWindow *w, KWin::WindowPrePaintData &data)
{
    if (m_anims.contains(w)) {
        data.setTransformed();
        data.setTranslucent();
    }
    KWin::OffscreenEffect::prePaintWindow(view, w, data);
}

void MotionEffect::apply(KWin::EffectWindow *window, int mask, KWin::WindowPaintData &data, KWin::WindowQuadList &quads)
{
    Q_UNUSED(mask)
    if (!m_anims.contains(window)) {
        return;
    }
    const WindowAnim &anim = m_anims.value(window);
    if (anim.kind != AnimKind::MinimizeGenie && anim.kind != AnimKind::UnminimizeGenie) {
        return;
    }

    const bool unmin = (anim.kind == AnimKind::UnminimizeGenie);
    const double rawT = std::clamp(anim.elapsedMs / anim.durationMs, 0.0, 1.0);
    // SPEC §3.1 Genie curve cubic-bezier(0.42, 0.0, 0.58, 1.0)
    const double e = evalCubicBezier(rawT, 0.42, 0.0, 0.58, 1.0);
    const double u = unmin ? (1.0 - e) : e; // 0 = full window, 1 = Dock tile

    const KWin::RectF wf = window->frameGeometry();
    const double winX = wf.x();
    const double winY = wf.y();
    const double winW = std::max(1.0, wf.width());
    const double winH = std::max(1.0, wf.height());

    const QRectF tile = anim.iconRect;
    const double iconLeft = tile.left();
    const double iconRight = tile.right();
    const double iconBottom = tile.bottom();

    // Subdivide window quad cleanly into 24 x 36 Genie warp grid
    quads = quads.makeRegularGrid(24, 36);

    // 2-phase Genie funnel (SPEC §3.1):
    // Phase 1 (0..0.35): sides pinch into sinusoidal funnel toward Dock icon X bounds
    // Phase 2 (0.35..1.0): slide down into Dock tile, bottom leading top edge
    const double pinchT = std::clamp(u / 0.42, 0.0, 1.0);
    const double slideT = std::clamp((u - 0.18) / 0.82, 0.0, 1.0);

    for (KWin::WindowQuad &q : quads) {
        for (int i = 0; i < 4; ++i) {
            KWin::WindowVertex &v = q[i];
            const double nx = std::clamp((v.x() - winX) / winW, 0.0, 1.0);
            const double ny = std::clamp((v.y() - winY) / winH, 0.0, 1.0);

            // Vertical progress: bottom pulls into dock faster than top
            const double yTravel = std::clamp(slideT * (1.28 - 0.28 * ny) + 0.15 * u * ny, 0.0, 1.0);
            const double targetY = tile.top() + ny * tile.height();
            const double newY = winY + ny * winH + (targetY - (winY + ny * winH)) * evalCubicBezier(yTravel, 0.42, 0.0, 0.58, 1.0);

            // Sinusoidal funnel horizontal bounds as function of vertical position relative to Dock
            const double funnelFrac = std::clamp((newY - winY) / std::max(1.0, iconBottom - winY), 0.0, 1.0);
            const double sCurve = 0.5 - 0.5 * std::cos(M_PI * funnelFrac);
            const double edgeBlend = std::clamp(pinchT * sCurve + slideT * 0.85, 0.0, 1.0);

            const double leftEdge = winX + (iconLeft - winX) * edgeBlend;
            const double rightEdge = (winX + winW) + (iconRight - (winX + winW)) * edgeBlend;
            const double newX = leftEdge + nx * (rightEdge - leftEdge);

            v.setX(newX);
            v.setY(newY);
        }
    }

    if (u > 0.88) {
        data.multiplyOpacity(std::clamp((1.0 - u) / 0.12, 0.0, 1.0));
    }
}

bool MotionEffect::paintWindow(const KWin::RenderTarget &renderTarget, const KWin::RenderViewport &viewport, KWin::EffectWindow *w, int mask, const KWin::Region &deviceRegion, KWin::WindowPaintData &data)
{
    if (!m_anims.contains(w)) {
        return KWin::OffscreenEffect::paintWindow(renderTarget, viewport, w, mask, deviceRegion, data);
    }

    const WindowAnim &anim = m_anims.value(w);
    const double t = std::clamp(anim.elapsedMs / anim.durationMs, 0.0, 1.0);
    const KWin::RectF geom = w->frameGeometry();
    const double cx = geom.x() + geom.width() * 0.5;
    const double cy = geom.y() + geom.height() * 0.5;

    switch (anim.kind) {
    case AnimKind::Open: {
        // SPEC §3.1: 240 ms spring (mass=1, stiffness=380, damping=32), scale 0.88 -> 1.00, opacity 0->1 in first 120ms
        const double sp = evalUnderdampedSpring(anim.elapsedMs / 1000.0, 380.0, 32.0);
        const double sc = 0.88 + 0.12 * sp;
        const double op = std::clamp(anim.elapsedMs / 120.0, 0.0, 1.0);
        data *= QVector2D(sc, sc);
        data += QPointF(cx * (1.0 - sc), cy * (1.0 - sc));
        data.multiplyOpacity(op);
        break;
    }
    case AnimKind::Close: {
        // SPEC §3.1: 167 ms cubic-bezier(0.22, 0.61, 0.36, 1), scale 1.00 -> 0.90, opacity 1 -> 0
        const double e = evalCubicBezier(t, 0.22, 0.61, 0.36, 1.0);
        const double sc = 1.0 - 0.10 * e;
        data *= QVector2D(sc, sc);
        data += QPointF(cx * (1.0 - sc), cy * (1.0 - sc));
        data.multiplyOpacity(std::clamp(1.0 - e, 0.0, 1.0));
        break;
    }
    case AnimKind::MinimizeScale: {
        // SPEC §3.1: 203 ms cubic-bezier(0.25, 0.1, 0.25, 1), opacity 1 -> 0.6 -> 0 in final 30 ms
        const double e = evalCubicBezier(t, 0.25, 0.1, 0.25, 1.0);
        const double sx = 1.0 + (anim.iconRect.width() / std::max(1.0, geom.width()) - 1.0) * e;
        const double sy = 1.0 + (anim.iconRect.height() / std::max(1.0, geom.height()) - 1.0) * e;
        const double tx = anim.iconRect.center().x() - cx;
        const double ty = anim.iconRect.center().y() - cy;
        data *= QVector2D(sx, sy);
        data += QPointF(cx * (1.0 - sx) + tx * e, cy * (1.0 - sy) + ty * e);
        const double remMs = anim.durationMs - anim.elapsedMs;
        if (remMs <= 30.0) {
            data.multiplyOpacity(std::clamp(remMs / 30.0 * 0.6, 0.0, 1.0));
        } else {
            data.multiplyOpacity(1.0 - 0.4 * e);
        }
        break;
    }
    case AnimKind::UnminimizeScale: {
        // SPEC §3.1: 200 ms cubic-bezier(0.16, 1, 0.3, 1)
        const double e = evalCubicBezier(t, 0.16, 1.0, 0.3, 1.0);
        const double minSx = anim.iconRect.width() / std::max(1.0, geom.width());
        const double minSy = anim.iconRect.height() / std::max(1.0, geom.height());
        const double sx = minSx + (1.0 - minSx) * e;
        const double sy = minSy + (1.0 - minSy) * e;
        const double tx = (anim.iconRect.center().x() - cx) * (1.0 - e);
        const double ty = (anim.iconRect.center().y() - cy) * (1.0 - e);
        data *= QVector2D(sx, sy);
        data += QPointF(cx * (1.0 - sx) + tx, cy * (1.0 - sy) + ty);
        data.multiplyOpacity(std::clamp(0.4 + 0.6 * e, 0.0, 1.0));
        break;
    }
    case AnimKind::MinimizeGenie:
    case AnimKind::UnminimizeGenie:
        // Deformed in OffscreenEffect::apply()
        break;
    case AnimKind::ReducedFadeIn: {
        const double e = evalCubicBezier(t, 0.25, 0.1, 0.25, 1.0);
        data.multiplyOpacity(e);
        break;
    }
    case AnimKind::ReducedFadeOut: {
        const double e = evalCubicBezier(t, 0.25, 0.1, 0.25, 1.0);
        data.multiplyOpacity(1.0 - e);
        break;
    }
    }

    return KWin::OffscreenEffect::paintWindow(renderTarget, viewport, w, mask, deviceRegion, data);
}

bool MotionEffect::isActive() const
{
    return !m_anims.isEmpty();
}

} // namespace Conjunction

KWIN_EFFECT_FACTORY_SUPPORTED_ENABLED(Conjunction::MotionEffect,
                                      "metadata.json",
                                      return Conjunction::MotionEffect::supported();,
                                      return Conjunction::MotionEffect::enabledByDefault();)

#include "motion_effect.moc"
