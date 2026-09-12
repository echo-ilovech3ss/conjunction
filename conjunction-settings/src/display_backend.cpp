#include "display_backend.h"
#include <QGuiApplication>
#include <QScreen>
#include <QDebug>

DisplayBackend::DisplayBackend(QObject *parent)
    : QObject(parent)
{
    m_revertTimer = new QTimer(this);
    connect(m_revertTimer, &QTimer::timeout, this, &DisplayBackend::onRevertTick);

    connect(qGuiApp, &QGuiApplication::screenAdded, this, &DisplayBackend::refreshScreens);
    connect(qGuiApp, &QGuiApplication::screenRemoved, this, &DisplayBackend::refreshScreens);

    refreshScreens();
}

DisplayBackend::~DisplayBackend() = default;

void DisplayBackend::refreshScreens()
{
    const auto screens = QGuiApplication::screens();
    m_screenCount = screens.size();
    m_displays.clear();

    if (!screens.isEmpty()) {
        QScreen *primary = QGuiApplication::primaryScreen();
        if (primary) {
            m_primaryResolution = QString("%1 x %2").arg(primary->geometry().width()).arg(primary->geometry().height());
            m_primaryRefreshRate = QString("%1 Hz").arg(qRound(primary->refreshRate()));
            m_currentScale = primary->devicePixelRatio();
        }

        for (int i = 0; i < screens.size(); ++i) {
            QScreen *scr = screens[i];
            QVariantMap d;
            d["index"] = i;
            d["name"] = scr->name().isEmpty() ? QString("Display %1").arg(i + 1) : scr->name();
            d["width"] = scr->geometry().width();
            d["height"] = scr->geometry().height();
            d["x"] = scr->geometry().x();
            d["y"] = scr->geometry().y();
            d["scale"] = scr->devicePixelRatio();
            d["primary"] = (scr == primary);
            m_displays.append(d);
        }
    }

    Q_EMIT screensChanged();
    Q_EMIT currentScaleChanged();
}

QString DisplayBackend::primaryResolution() const { return m_primaryResolution; }
QString DisplayBackend::primaryRefreshRate() const { return m_primaryRefreshRate; }
int DisplayBackend::screenCount() const { return m_screenCount; }
qreal DisplayBackend::currentScale() const { return m_currentScale; }

void DisplayBackend::setCurrentScale(qreal scale)
{
    if (!qFuzzyCompare(m_currentScale, scale)) {
        m_currentScale = scale;
        Q_EMIT currentScaleChanged();
    }
}

QVariantList DisplayBackend::availableScales() const
{
    return QVariantList() << 1.0 << 1.25 << 1.5 << 2.0;
}

QVariantList DisplayBackend::displays() const { return m_displays; }
bool DisplayBackend::revertDialogVisible() const { return m_revertDialogVisible; }
int DisplayBackend::revertCountdown() const { return m_revertCountdown; }

void DisplayBackend::applyScaleWithTimeout(qreal newScale, int timeoutSeconds)
{
    m_previousScale = m_currentScale;
    setCurrentScale(newScale);

    m_revertCountdown = timeoutSeconds;
    m_revertDialogVisible = true;
    Q_EMIT revertCountdownChanged();
    Q_EMIT revertDialogVisibleChanged();

    m_revertTimer->start(1000);
}

void DisplayBackend::confirmScaleChange()
{
    m_revertTimer->stop();
    m_revertDialogVisible = false;
    Q_EMIT revertDialogVisibleChanged();
}

void DisplayBackend::revertScaleChange()
{
    m_revertTimer->stop();
    setCurrentScale(m_previousScale);
    m_revertDialogVisible = false;
    Q_EMIT revertDialogVisibleChanged();
}

void DisplayBackend::onRevertTick()
{
    m_revertCountdown--;
    Q_EMIT revertCountdownChanged();

    if (m_revertCountdown <= 0) {
        revertScaleChange();
    }
}
