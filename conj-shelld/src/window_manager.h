#pragma once

#include <QObject>
#include <QString>
#include <QMap>
#include <QList>
#include <QDBusContext>

struct ShellWindowEntry {
    QString internalId;
    QString title;
    QString appId;
    uint pid = 0;
    bool isFullscreen = false;
    bool active = false;
};

class WindowManager : public QObject, protected QDBusContext {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.conjunction.Shell.WindowManager")

public:
    explicit WindowManager(QObject *parent = nullptr);
    ~WindowManager() override;

    bool initDBus();

    QList<ShellWindowEntry> windows() const;
    ShellWindowEntry activeWindow() const;
    ShellWindowEntry getWindow(const QString &internalId) const;

    void activateWindow(const QString &internalId);
    void closeWindow(const QString &internalId);
    void minimizeWindow(const QString &internalId);
    void unminimizeWindow(const QString &internalId);

public Q_SLOTS:
    Q_SCRIPTABLE void WindowAdded(const QString &internalId, const QString &title, const QString &appId, uint pid, bool isFullscreen);
    Q_SCRIPTABLE void WindowRemoved(const QString &internalId);
    Q_SCRIPTABLE void WindowActivated(const QString &internalId, const QString &title, const QString &appId, uint pid, bool isFullscreen);
    Q_SCRIPTABLE void WindowChanged(const QString &internalId, const QString &title, bool isFullscreen);

Q_SIGNALS:
    void windowListChanged();
    void activeWindowChanged(const QString &internalId);

private:
    QMap<QString, ShellWindowEntry> m_windows;
    QString m_activeWindowId;
};
