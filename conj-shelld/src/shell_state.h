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

    // Phase 5B Additions:
    Q_PROPERTY(bool spotlightVisible READ spotlightVisible WRITE setSpotlightVisible NOTIFY spotlightVisibleChanged)
    Q_PROPERTY(QString searchQuery READ searchQuery WRITE setSearchQuery NOTIFY searchQueryChanged)
    Q_PROPERTY(QVariantList searchResults READ searchResults NOTIFY searchResultsChanged)

    Q_PROPERTY(bool controlCenterVisible READ controlCenterVisible WRITE setControlCenterVisible NOTIFY controlCenterVisibleChanged)
    Q_PROPERTY(int volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(int brightness READ brightness WRITE setBrightness NOTIFY brightnessChanged)
    Q_PROPERTY(bool wifiEnabled READ wifiEnabled WRITE setWifiEnabled NOTIFY wifiChanged)
    Q_PROPERTY(QString wifiSsid READ wifiSsid NOTIFY wifiChanged)
    Q_PROPERTY(bool bluetoothEnabled READ bluetoothEnabled WRITE setBluetoothEnabled NOTIFY bluetoothChanged)
    Q_PROPERTY(bool doNotDisturb READ doNotDisturb WRITE setDoNotDisturb NOTIFY doNotDisturbChanged)

    Q_PROPERTY(bool dockMagnification READ dockMagnification WRITE setDockMagnification NOTIFY dockMagnificationChanged)
    Q_PROPERTY(qreal dockScaleMax READ dockScaleMax WRITE setDockScaleMax NOTIFY dockScaleMaxChanged)

    Q_PROPERTY(bool overviewActive READ overviewActive WRITE setOverviewActive NOTIFY overviewActiveChanged)

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

    bool spotlightVisible() const;
    void setSpotlightVisible(bool visible);
    QString searchQuery() const;
    void setSearchQuery(const QString &query);
    QVariantList searchResults() const;

    bool controlCenterVisible() const;
    void setControlCenterVisible(bool visible);
    int volume() const;
    void setVolume(int vol);
    int brightness() const;
    void setBrightness(int bri);
    bool wifiEnabled() const;
    void setWifiEnabled(bool enabled);
    QString wifiSsid() const;
    bool bluetoothEnabled() const;
    void setBluetoothEnabled(bool enabled);
    bool doNotDisturb() const;
    void setDoNotDisturb(bool dnd);

    bool dockMagnification() const;
    void setDockMagnification(bool enabled);
    qreal dockScaleMax() const;
    void setDockScaleMax(qreal maxScale);

    bool overviewActive() const;
    void setOverviewActive(bool active);

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

    // Spotlight / Search
    Q_INVOKABLE void toggleSpotlight();
    Q_INVOKABLE void activateSearchResult(int index);

    // Control Center
    Q_INVOKABLE void toggleControlCenter();
    Q_INVOKABLE void toggleWifi();
    Q_INVOKABLE void toggleBluetooth();
    Q_INVOKABLE void toggleDoNotDisturb();

    // App Menu standard actions
    Q_INVOKABLE void aboutCurrentApp();
    Q_INVOKABLE void hideCurrentApp();
    Q_INVOKABLE void hideOthers();
    Q_INVOKABLE void showAll();
    Q_INVOKABLE void quitCurrentApp();

    // Mission Control / Overview
    Q_INVOKABLE void toggleOverview();

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

    void spotlightVisibleChanged();
    void searchQueryChanged();
    void searchResultsChanged();

    void controlCenterVisibleChanged();
    void volumeChanged();
    void brightnessChanged();
    void wifiChanged();
    void bluetoothChanged();
    void doNotDisturbChanged();

    void dockMagnificationChanged();
    void dockScaleMaxChanged();
    void overviewActiveChanged();

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

    bool m_spotlightVisible = false;
    QString m_searchQuery;
    QVariantList m_searchResults;

    bool m_controlCenterVisible = false;
    int m_volume = 75;
    int m_brightness = 85;
    bool m_wifiEnabled = true;
    QString m_wifiSsid = "Conjunction-5G";
    bool m_bluetoothEnabled = true;
    bool m_doNotDisturb = false;

    bool m_dockMagnification = true;
    qreal m_dockScaleMax = 1.35;

    bool m_overviewActive = false;

    void performSearch(const QString &query);
};
