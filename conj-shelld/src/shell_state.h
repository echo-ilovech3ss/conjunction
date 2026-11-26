#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QTimer>
#include <QDateTime>
#include <QDBusVariant>
#include "window_manager.h"
#include "menu_registrar.h"

class QWindow;

struct RegisteredAppInfo {
    QString id;
    QString name;
    QString icon;
    QString executablePath;
    QString packageName;
    QString flatpakId;
    QString category = "Utilities";
    QString bundlePath;
    bool isBundle = false;
};

class ShellState : public QObject {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.conjunction.Settings")

    Q_PROPERTY(QString activeAppName READ activeAppName NOTIFY activeAppChanged)
    Q_PROPERTY(QString activeAppId READ activeAppId NOTIFY activeAppChanged)
    Q_PROPERTY(QString activeWindowId READ activeWindowId NOTIFY activeAppChanged)
    Q_PROPERTY(bool isFullscreen READ isFullscreen NOTIFY fullscreenChanged)
    Q_PROPERTY(QVariantList globalMenus READ globalMenus NOTIFY globalMenusChanged)
    Q_PROPERTY(QVariantList dockItems READ dockItems NOTIFY dockItemsChanged)
    Q_PROPERTY(QVariantList minimizedWindows READ minimizedWindows NOTIFY dockItemsChanged)
    Q_PROPERTY(QVariantList mountedVolumes READ mountedVolumes NOTIFY mountedVolumesChanged)
    Q_PROPERTY(QVariantList appCatalog READ appCatalog NOTIFY appCatalogChanged)
    Q_PROPERTY(QString systemTime READ systemTime NOTIFY systemTimeChanged)
    Q_PROPERTY(bool isDark READ isDark WRITE setIsDark NOTIFY themeChanged)
    Q_PROPERTY(QString accentColor READ accentColor WRITE setAccentColor NOTIFY accentColorChanged)
    Q_PROPERTY(bool notchBar READ notchBar WRITE setNotchBar NOTIFY notchBarChanged)

    // Search / Quick Search + Quick Look
    Q_PROPERTY(bool spotlightVisible READ spotlightVisible WRITE setSpotlightVisible NOTIFY spotlightVisibleChanged)
    Q_PROPERTY(QString searchQuery READ searchQuery WRITE setSearchQuery NOTIFY searchQueryChanged)
    Q_PROPERTY(QVariantList searchResults READ searchResults NOTIFY searchResultsChanged)
    Q_PROPERTY(bool quickLookVisible READ quickLookVisible WRITE setQuickLookVisible NOTIFY quickLookChanged)
    Q_PROPERTY(QString quickLookTitle READ quickLookTitle NOTIFY quickLookChanged)
    Q_PROPERTY(QString quickLookSubtitle READ quickLookSubtitle NOTIFY quickLookChanged)
    Q_PROPERTY(QString quickLookBody READ quickLookBody NOTIFY quickLookChanged)
    Q_PROPERTY(QString quickLookIcon READ quickLookIcon NOTIFY quickLookChanged)

    // Overlays (App Launcher, App Switcher HUD, Quick Note)
    Q_PROPERTY(bool appLauncherVisible READ appLauncherVisible WRITE setAppLauncherVisible NOTIFY appLauncherVisibleChanged)
    Q_PROPERTY(bool quickNoteVisible READ quickNoteVisible WRITE setQuickNoteVisible NOTIFY quickNoteVisibleChanged)
    Q_PROPERTY(QString quickNoteText READ quickNoteText WRITE setQuickNoteText NOTIFY quickNoteTextChanged)
    Q_PROPERTY(bool appSwitcherVisible READ appSwitcherVisible WRITE setAppSwitcherVisible NOTIFY appSwitcherChanged)
    Q_PROPERTY(int appSwitcherIndex READ appSwitcherIndex WRITE setAppSwitcherIndex NOTIFY appSwitcherChanged)

    // Control Center
    Q_PROPERTY(bool controlCenterVisible READ controlCenterVisible WRITE setControlCenterVisible NOTIFY controlCenterVisibleChanged)
    Q_PROPERTY(int volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(int brightness READ brightness WRITE setBrightness NOTIFY brightnessChanged)
    Q_PROPERTY(bool wifiEnabled READ wifiEnabled WRITE setWifiEnabled NOTIFY wifiChanged)
    Q_PROPERTY(QString wifiSsid READ wifiSsid NOTIFY wifiChanged)
    Q_PROPERTY(bool bluetoothEnabled READ bluetoothEnabled WRITE setBluetoothEnabled NOTIFY bluetoothChanged)
    Q_PROPERTY(bool doNotDisturb READ doNotDisturb WRITE setDoNotDisturb NOTIFY doNotDisturbChanged)
    Q_PROPERTY(bool nearbyShareEnabled READ nearbyShareEnabled WRITE setNearbyShareEnabled NOTIFY nearbyShareChanged)
    Q_PROPERTY(bool stageManagerEnabled READ stageManagerEnabled WRITE setStageManagerEnabled NOTIFY stageManagerChanged)
    Q_PROPERTY(bool nightShiftEnabled READ nightShiftEnabled WRITE setNightShiftEnabled NOTIFY nightShiftChanged)

    // Dock & Window Behavior
    Q_PROPERTY(bool dockMagnification READ dockMagnification WRITE setDockMagnification NOTIFY dockMagnificationChanged)
    Q_PROPERTY(qreal dockScaleMax READ dockScaleMax WRITE setDockScaleMax NOTIFY dockScaleMaxChanged)
    Q_PROPERTY(int dockTileSize READ dockTileSize WRITE setDockTileSize NOTIFY dockTileSizeChanged)
    Q_PROPERTY(bool dockAutoHide READ dockAutoHide WRITE setDockAutoHide NOTIFY dockAutoHideChanged)
    Q_PROPERTY(QString minimizeEffect READ minimizeEffect WRITE setMinimizeEffect NOTIFY minimizeEffectChanged)
    Q_PROPERTY(bool isDraggingDockItem READ isDraggingDockItem NOTIFY draggingDockItemChanged)
    Q_PROPERTY(QString draggingItemType READ draggingItemType NOTIFY draggingDockItemChanged)
    Q_PROPERTY(QString draggingItemId READ draggingItemId NOTIFY draggingDockItemChanged)

    Q_PROPERTY(bool overviewActive READ overviewActive WRITE setOverviewActive NOTIFY overviewActiveChanged)

    // Notifications & Accessibility
    Q_PROPERTY(bool notificationCenterVisible READ notificationCenterVisible WRITE setNotificationCenterVisible NOTIFY notificationCenterVisibleChanged)
    Q_PROPERTY(QVariantList activeBanners READ activeBanners NOTIFY activeBannersChanged)
    Q_PROPERTY(QVariantList notificationHistory READ notificationHistory NOTIFY notificationHistoryChanged)
    Q_PROPERTY(bool reducedMotion READ reducedMotion WRITE setReducedMotion NOTIFY reducedMotionChanged)
    Q_PROPERTY(bool reduceTransparency READ reduceTransparency WRITE setReduceTransparency NOTIFY reduceTransparencyChanged)
    Q_PROPERTY(bool increaseContrast READ increaseContrast WRITE setIncreaseContrast NOTIFY increaseContrastChanged)
    Q_PROPERTY(bool layerShellMode READ layerShellMode WRITE setLayerShellMode NOTIFY layerShellModeChanged)

public:
    explicit ShellState(WindowManager *winMgr, MenuRegistrar *menuReg, QObject *parent = nullptr);
    ~ShellState() override;

    QString activeAppName() const;
    QString activeAppId() const;
    QString activeWindowId() const;
    bool isFullscreen() const;
    QVariantList globalMenus() const;
    QVariantList dockItems() const;
    QVariantList minimizedWindows() const;
    QVariantList mountedVolumes() const;
    QVariantList appCatalog() const;
    QString systemTime() const;
    bool isDark() const;
    void setIsDark(bool dark);
    QString accentColor() const;
    void setAccentColor(const QString &accent);
    bool notchBar() const;
    void setNotchBar(bool notch);

    bool spotlightVisible() const;
    void setSpotlightVisible(bool visible);
    QString searchQuery() const;
    void setSearchQuery(const QString &query);
    QVariantList searchResults() const;

    bool quickLookVisible() const;
    void setQuickLookVisible(bool visible);
    QString quickLookTitle() const;
    QString quickLookSubtitle() const;
    QString quickLookBody() const;
    QString quickLookIcon() const;

    bool appLauncherVisible() const;
    void setAppLauncherVisible(bool visible);
    bool quickNoteVisible() const;
    void setQuickNoteVisible(bool visible);
    QString quickNoteText() const;
    void setQuickNoteText(const QString &text);
    bool appSwitcherVisible() const;
    void setAppSwitcherVisible(bool visible);
    int appSwitcherIndex() const;
    void setAppSwitcherIndex(int idx);

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
    bool nearbyShareEnabled() const;
    void setNearbyShareEnabled(bool enabled);
    bool stageManagerEnabled() const;
    void setStageManagerEnabled(bool enabled);
    bool nightShiftEnabled() const;
    void setNightShiftEnabled(bool enabled);

    bool dockMagnification() const;
    void setDockMagnification(bool enabled);
    qreal dockScaleMax() const;
    void setDockScaleMax(qreal maxScale);
    int dockTileSize() const;
    void setDockTileSize(int size);
    bool dockAutoHide() const;
    void setDockAutoHide(bool autoHide);
    QString minimizeEffect() const;
    void setMinimizeEffect(const QString &effect);
    bool isDraggingDockItem() const;
    QString draggingItemType() const;
    QString draggingItemId() const;

    bool overviewActive() const;
    void setOverviewActive(bool active);

    bool notificationCenterVisible() const;
    void setNotificationCenterVisible(bool visible);
    QVariantList activeBanners() const;
    QVariantList notificationHistory() const;
    bool reducedMotion() const;
    void setReducedMotion(bool rm);
    bool reduceTransparency() const;
    void setReduceTransparency(bool rt);
    bool increaseContrast() const;
    void setIncreaseContrast(bool ic);
    bool layerShellMode() const;
    void setLayerShellMode(bool enabled);

    bool initDBus();
    void loadSettings();
    void saveSetting(const QString &key, const QVariant &val);
    void loadDockConfig();
    void saveDockConfig();
    void reloadKnownApps();
    void refreshMountedVolumes();

public Q_SLOTS:
    // D-Bus Scriptable Settings & Shell Methods
    Q_SCRIPTABLE QDBusVariant GetSetting(const QString &key) const;
    Q_SCRIPTABLE bool SetSetting(const QString &key, const QDBusVariant &value);
    Q_SCRIPTABLE QVariantMap GetAllSettings() const;
    Q_SCRIPTABLE void OpenSetting(const QString &target);

    Q_INVOKABLE void launchApp(const QString &appId);
    Q_INVOKABLE void launchBundle(const QString &bundlePath);
    Q_INVOKABLE void focusApp(const QString &appId);
    Q_INVOKABLE void activateWindow(const QString &windowId);
    Q_INVOKABLE void minimizeWindow(const QString &windowId);
    Q_INVOKABLE void unminimizeWindow(const QString &windowId);
    Q_INVOKABLE void closeWindow(const QString &windowId);
    Q_INVOKABLE void triggerMenuAction(int actionId);
    Q_INVOKABLE void pinApp(const QString &appId);
    Q_INVOKABLE void unpinApp(const QString &appId);
    Q_INVOKABLE void quitApp(const QString &appId);
    Q_INVOKABLE void ejectVolume(const QString &mountPoint);
    Q_INVOKABLE void openPath(const QString &path);
    Q_INVOKABLE void toggleTheme();
    Q_INVOKABLE void requestSystemAction(const QString &action);
    Q_INVOKABLE void setDraggingDockItem(bool dragging, const QString &type = QString(), const QString &id = QString());
    Q_INVOKABLE void bindLayerShell(QObject *windowObj, const QString &role, int exclusiveZone = 0);

    // Search & Quick Look
    Q_INVOKABLE void toggleSpotlight();
    Q_INVOKABLE void activateSearchResult(int index);
    Q_INVOKABLE void openQuickLook(int index);
    Q_INVOKABLE void closeQuickLook();

    // App Launcher, Quick Note, App Switcher
    Q_INVOKABLE void toggleAppLauncher();
    Q_INVOKABLE void toggleQuickNote();
    Q_SCRIPTABLE Q_INVOKABLE void triggerQuickNote();
    Q_INVOKABLE void showAppSwitcher(bool reverse = false);
    Q_INVOKABLE void commitAppSwitcher();
    Q_INVOKABLE void dismissAppSwitcher();

    // Control Center
    Q_INVOKABLE void toggleControlCenter();
    Q_INVOKABLE void toggleWifi();
    Q_INVOKABLE void toggleBluetooth();
    Q_INVOKABLE void toggleDoNotDisturb();
    Q_INVOKABLE void toggleNearbyShare();
    Q_INVOKABLE void toggleStageManager();
    Q_INVOKABLE void toggleNightShift();

    // App Menu standard actions
    Q_INVOKABLE void aboutCurrentApp();
    Q_INVOKABLE void hideCurrentApp();
    Q_INVOKABLE void hideOthers();
    Q_INVOKABLE void showAll();
    Q_INVOKABLE void quitCurrentApp();

    // Mission Control / Overview
    Q_INVOKABLE void toggleOverview();

    // Notifications
    Q_INVOKABLE void toggleNotificationCenter();
    Q_INVOKABLE void dismissNotification(uint id);
    Q_INVOKABLE void invokeNotificationAction(uint id, const QString &actionKey);
    Q_INVOKABLE void clearNotificationHistory();

    // Power & Session Management
    Q_INVOKABLE void lockScreen();
    Q_INVOKABLE void suspendSession();
    Q_INVOKABLE void restartSystem();
    Q_INVOKABLE void shutdownSystem();
    Q_INVOKABLE void logoutSession();
    Q_INVOKABLE QVariantList checkInhibitors() const;
    Q_INVOKABLE bool canSuspend() const;
    Q_INVOKABLE bool canReboot() const;
    Q_INVOKABLE bool canPowerOff() const;

    // Testing helpers
    Q_INVOKABLE void simulateWindow(const QString &winId, const QString &title, const QString &appId, bool active);
    Q_INVOKABLE void simulateMinimizedWindow(const QString &winId, const QString &title, const QString &appId);
    Q_INVOKABLE void simulateMountedVolume(const QString &name, const QString &mountPoint);
    Q_INVOKABLE void simulateGlobalMenu(const QVariantList &menus);
    Q_INVOKABLE void simulateNotification(uint id, const QString &appName, const QString &summary, const QString &body);

Q_SIGNALS:
    void SettingChanged(const QString &key, const QVariant &value);

    void activeAppChanged();
    void fullscreenChanged();
    void globalMenusChanged();
    void dockItemsChanged();
    void mountedVolumesChanged();
    void appCatalogChanged();
    void systemTimeChanged();
    void themeChanged();
    void accentColorChanged();
    void notchBarChanged();
    void systemActionTriggered(const QString &action);

    void spotlightVisibleChanged();
    void searchQueryChanged();
    void searchResultsChanged();
    void quickLookChanged();

    void appLauncherVisibleChanged();
    void quickNoteVisibleChanged();
    void quickNoteTextChanged();
    void appSwitcherChanged();

    void controlCenterVisibleChanged();
    void volumeChanged();
    void brightnessChanged();
    void wifiChanged();
    void bluetoothChanged();
    void doNotDisturbChanged();
    void nearbyShareChanged();
    void stageManagerChanged();
    void nightShiftChanged();

    void dockMagnificationChanged();
    void dockScaleMaxChanged();
    void dockTileSizeChanged();
    void dockAutoHideChanged();
    void minimizeEffectChanged();
    void draggingDockItemChanged();
    void overviewActiveChanged();

    void notificationCenterVisibleChanged();
    void activeBannersChanged();
    void notificationHistoryChanged();
    void reducedMotionChanged();
    void reduceTransparencyChanged();
    void increaseContrastChanged();
    void layerShellModeChanged();

private Q_SLOTS:
    void onWindowListChanged();
    void onActiveWindowChanged(const QString &winId);
    void onMenuUpdated(uint windowId);
    void onTimeTick();

    void onNotificationAdded(uint id, const QString &json);
    void onNotificationUpdated(uint id, const QString &json);
    void onNotificationRemoved(uint id);
    void onNotificationHistoryChanged();

private:
    void updateDockItems();
    void updateActiveApp();
    RegisteredAppInfo resolveApp(const ShellWindowEntry &win);
    void initNotificationService();
    void fetchNotifications();
    void syncPortalAppearance();
    void loadQuickNote();
    void saveQuickNote();

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
    QVariantList m_minimizedWindows;
    QVariantList m_mountedVolumes;
    QVariantList m_appCatalog;
    QString m_systemTime;
    bool m_isDark = false;
    QString m_accentColor = "blue";
    bool m_notchBar = false;

    bool m_spotlightVisible = false;
    QString m_searchQuery;
    QVariantList m_searchResults;
    bool m_quickLookVisible = false;
    QString m_quickLookTitle;
    QString m_quickLookSubtitle;
    QString m_quickLookBody;
    QString m_quickLookIcon;

    bool m_appLauncherVisible = false;
    bool m_quickNoteVisible = false;
    QString m_quickNoteText;
    bool m_appSwitcherVisible = false;
    int m_appSwitcherIndex = 0;

    bool m_controlCenterVisible = false;
    int m_volume = 75;
    int m_brightness = 85;
    bool m_wifiEnabled = true;
    QString m_wifiSsid = "Conjunction-5G";
    bool m_bluetoothEnabled = true;
    bool m_doNotDisturb = false;
    bool m_nearbyShareEnabled = true;
    bool m_stageManagerEnabled = false;
    bool m_nightShiftEnabled = false;

    bool m_dockMagnification = true;
    qreal m_dockScaleMax = 1.45;
    int m_dockTileSize = 54;
    bool m_dockAutoHide = false;
    QString m_minimizeEffect = "genie";
    bool m_isDraggingDockItem = false;
    QString m_draggingItemType;
    QString m_draggingItemId;

    bool m_overviewActive = false;

    bool m_notificationCenterVisible = false;
    QVariantList m_activeBanners;
    QVariantList m_notificationHistory;
    bool m_reducedMotion = false;
    bool m_reduceTransparency = false;
    bool m_increaseContrast = false;
    bool m_layerShellMode = false;

    void performSearch(const QString &query);
};
