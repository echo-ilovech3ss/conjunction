#pragma once

#include <effect/effectwindow.h>
#include <effect/globals.h>
#include <effect/offscreeneffect.h>

#include <QElapsedTimer>
#include <QHash>
#include <QRectF>

namespace Conjunction
{

class MotionEffect : public KWin::OffscreenEffect
{
    Q_OBJECT
public:
    explicit MotionEffect();
    ~MotionEffect() override;

    static bool supported();
    static bool enabledByDefault() { return true; }

    void reconfigure(ReconfigureFlags flags) override;
    void prePaintScreen(KWin::ScreenPrePaintData &data) override;
    void postPaintScreen() override;
    void prePaintWindow(KWin::RenderView *view, KWin::EffectWindow *w, KWin::WindowPrePaintData &data) override;
    bool paintWindow(const KWin::RenderTarget &renderTarget, const KWin::RenderViewport &viewport, KWin::EffectWindow *w, int mask, const KWin::Region &deviceRegion, KWin::WindowPaintData &data) override;
    bool isActive() const override;
    int requestedEffectChainPosition() const override { return 40; }

public Q_SLOTS:
    bool borderActivated(KWin::ElectricBorder border) override;

private Q_SLOTS:
    void slotWindowAdded(KWin::EffectWindow *w);
    void slotWindowClosed(KWin::EffectWindow *w);
    void slotWindowDeleted(KWin::EffectWindow *w);
    void slotWindowMinimizedChanged(KWin::EffectWindow *w);
    void onSettingChanged(const QString &key, const QVariant &value);

private:
    enum class AnimKind {
        Open,
        Close,
        MinimizeGenie,
        UnminimizeGenie,
        MinimizeScale,
        UnminimizeScale,
        ReducedFadeIn,
        ReducedFadeOut
    };

    struct WindowAnim {
        AnimKind kind;
        double elapsedMs = 0.0;
        double durationMs = 240.0;
        QRectF iconRect;
        KWin::EffectWindowDeletedRef deletedRef;
        KWin::EffectWindowVisibleRef visibleRef;
    };

    bool shouldAnimateWindow(KWin::EffectWindow *w) const;
    QRectF resolveTargetIconRect(KWin::EffectWindow *w) const;
    void startAnim(KWin::EffectWindow *w, AnimKind kind, bool keepDeleted = false, bool keepVisible = false);
    void updateHotCorners();

    void apply(KWin::EffectWindow *window, int mask, KWin::WindowPaintData &data, KWin::WindowQuadList &quads) override;

    QHash<KWin::EffectWindow *, WindowAnim> m_anims;
    QElapsedTimer m_frameTimer;
    qint64 m_lastNs = 0;

    bool m_reducedMotion = false;
    bool m_useGenie = true;
    int m_cornerActions[KWin::ELECTRIC_COUNT] = {0};
};

} // namespace Conjunction
