#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QTimer>
#include <QDateTime>
#include "window_manager.h"
#include "menu_registrar.h"

struct RegisteredAppInfo {
    QString id;
    QString name;
    QString icon;
    QString executablePath;
    QString packageName;
    QString flatpakId;
};

class ShellState : public QObject {
    Q_OBJECT

    Q_PROPERTY(QString activeAppName READ activeAppName NOTIFY activeAppChanged)
    Q_PROPERTY(QString activeAppId READ activeAppId NOTIFY activeAppChanged)
    Q_PROPERTY(QString activeWindowId READ activeWindowId NOTIFY activeAppChanged)
    Q_PROPERTY(bool isFullscreen READ isFullscreen NOTIFY fullscreenChanged)
    Q_PROPERTY(QVariantList globalMenus READ globalMenus NOTIFY globalMenusChanged)
    Q_PROPERTY(QVariantList dockItems READ dockItems NOTIFY dockItemsChanged)
    Q_PROPERTY(QString systemTime READ systemTime NOTIFY systemTimeChanged)
    Q_PROPERTY(bool isDark READ isDark WRITE setIsDark NOTIFY themeChanged)

public:
    explicit ShellState(WindowManager *winMgr, MenuRegistrar *menuReg, QObject *parent = nullptr);
    ~ShellState() override;

    QString activeAppName() const;
    QString activeAppId() const;
    QString activeWindowId() const;
    bool isFullscreen() const;
    QVariantList globalMenus() const;
    QVariantList dockItems() const;
    QString systemTime() const;
    bool isDark() const;
    void setIsDark(bool dark);

    void loadDockConfig();
    void saveDockConfig();
    void reloadKnownApps();

public Q_SLOTS:
    Q_INVOKABLE void launchApp(const QString &appId);
    Q_INVOKABLE void focusApp(const QString &appId);
    Q_INVOKABLE void activateWindow(const QString &windowId);
    Q_INVOKABLE void closeWindow(const QString &windowId);
    Q_INVOKABLE void triggerMenuAction(int actionId);
    Q_INVOKABLE void pinApp(const QString &appId);
    Q_INVOKABLE void unpinApp(const QString &appId);
    Q_INVOKABLE void quitApp(const QString &appId);
    Q_INVOKABLE void toggleTheme();
    Q_INVOKABLE void requestSystemAction(const QString &action);

    // Testing helper to inject/simulate apps and windows
    Q_INVOKABLE void simulateWindow(const QString &winId, const QString &title, const QString &appId, bool active);
    Q_INVOKABLE void simulateGlobalMenu(const QVariantList &menus);

Q_SIGNALS:
    void activeAppChanged();
    void fullscreenChanged();
    void globalMenusChanged();
    void dockItemsChanged();
    void systemTimeChanged();
    void themeChanged();
    void systemActionTriggered(const QString &action);

private Q_SLOTS:
    void onWindowListChanged();
    void onActiveWindowChanged(const QString &winId);
    void onMenuUpdated(uint windowId);
    void onTimeTick();

private:
    void updateDockItems();
    void updateActiveApp();
    RegisteredAppInfo resolveApp(const ShellWindowEntry &win);

    WindowManager *m_winMgr;
    MenuRegistrar *m_menuReg;
    QTimer *m_clockTimer;

    QStringList m_pinnedApps;
    QMap<QString, RegisteredAppInfo> m_knownApps;

    QString m_activeAppName = "Conjunction";
    QString m_activeAppId = "org.conjunction.shell";
    QString m_activeWindowId;
    bool m_isFullscreen = false;
    QVariantList m_globalMenus;
    QVariantList m_dockItems;
    QString m_systemTime;
    bool m_isDark = false;
};
