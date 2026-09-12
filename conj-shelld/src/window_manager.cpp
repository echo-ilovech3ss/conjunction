#include "window_manager.h"
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDebug>

WindowManager::WindowManager(QObject *parent)
    : QObject(parent)
{
}

WindowManager::~WindowManager() = default;

bool WindowManager::initDBus()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        qWarning() << "[WindowManager] Session D-Bus not connected";
        return false;
    }

    if (!bus.registerService("org.conjunction.Shell")) {
        qWarning() << "[WindowManager] Failed to register service org.conjunction.Shell:" << bus.lastError().message();
    }

    if (!bus.registerObject("/org/conjunction/Shell/WindowManager", this, QDBusConnection::ExportScriptableContents)) {
        qWarning() << "[WindowManager] Failed to register object /org/conjunction/Shell/WindowManager:" << bus.lastError().message();
        return false;
    }

    qInfo() << "[WindowManager] Successfully registered org.conjunction.Shell.WindowManager";
    return true;
}

QList<ShellWindowEntry> WindowManager::windows() const
{
    return m_windows.values();
}

ShellWindowEntry WindowManager::activeWindow() const
{
    return m_windows.value(m_activeWindowId);
}

ShellWindowEntry WindowManager::getWindow(const QString &internalId) const
{
    return m_windows.value(internalId);
}

void WindowManager::WindowAdded(const QString &internalId, const QString &title, const QString &appId, uint pid, bool isFullscreen)
{
    ShellWindowEntry entry;
    entry.internalId = internalId;
    entry.title = title;
    entry.appId = appId;
    entry.pid = pid;
    entry.isFullscreen = isFullscreen;
    entry.active = false;

    m_windows.insert(internalId, entry);
    qInfo() << "[WindowManager] Window added:" << internalId << title << appId << pid;
    Q_EMIT windowListChanged();
}

void WindowManager::WindowRemoved(const QString &internalId)
{
    if (m_windows.remove(internalId) > 0) {
        if (m_activeWindowId == internalId) {
            m_activeWindowId.clear();
            if (!m_windows.isEmpty()) {
                m_activeWindowId = m_windows.firstKey();
                m_windows[m_activeWindowId].active = true;
            }
            Q_EMIT activeWindowChanged(m_activeWindowId);
        }
        qInfo() << "[WindowManager] Window removed:" << internalId;
        Q_EMIT windowListChanged();
    }
}

void WindowManager::WindowActivated(const QString &internalId, const QString &title, const QString &appId, uint pid, bool isFullscreen)
{
    for (auto &win : m_windows) {
        win.active = false;
    }

    if (!m_windows.contains(internalId)) {
        ShellWindowEntry entry;
        entry.internalId = internalId;
        entry.title = title;
        entry.appId = appId;
        entry.pid = pid;
        entry.isFullscreen = isFullscreen;
        entry.active = true;
        m_windows.insert(internalId, entry);
    } else {
        m_windows[internalId].title = title;
        m_windows[internalId].appId = appId;
        m_windows[internalId].pid = pid;
        m_windows[internalId].isFullscreen = isFullscreen;
        m_windows[internalId].active = true;
    }

    m_activeWindowId = internalId;
    qInfo() << "[WindowManager] Window activated:" << internalId << title << appId;
    Q_EMIT activeWindowChanged(internalId);
    Q_EMIT windowListChanged();
}

void WindowManager::WindowChanged(const QString &internalId, const QString &title, bool isFullscreen)
{
    if (m_windows.contains(internalId)) {
        m_windows[internalId].title = title;
        m_windows[internalId].isFullscreen = isFullscreen;
        Q_EMIT windowListChanged();
        if (m_activeWindowId == internalId) {
            Q_EMIT activeWindowChanged(internalId);
        }
    }
}

void WindowManager::activateWindow(const QString &internalId)
{
    // Send D-Bus call to KWin bridge script
    QDBusMessage msg = QDBusMessage::createMethodCall(
        "org.conjunction.KWinBridge",
        "/org/conjunction/KWinBridge",
        "org.conjunction.KWinBridge",
        "ActivateWindow"
    );
    msg << internalId;
    QDBusConnection::sessionBus().send(msg);

    // Also update local state optimistically
    if (m_windows.contains(internalId)) {
        for (auto &win : m_windows) {
            win.active = false;
        }
        m_windows[internalId].active = true;
        m_activeWindowId = internalId;
        Q_EMIT activeWindowChanged(internalId);
        Q_EMIT windowListChanged();
    }
}

void WindowManager::closeWindow(const QString &internalId)
{
    QDBusMessage msg = QDBusMessage::createMethodCall(
        "org.conjunction.KWinBridge",
        "/org/conjunction/KWinBridge",
        "org.conjunction.KWinBridge",
        "CloseWindow"
    );
    msg << internalId;
    QDBusConnection::sessionBus().send(msg);

    // If local window
    WindowRemoved(internalId);
}
