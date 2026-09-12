#include "shell_state.h"
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QProcess>
#include <QDebug>
#ifdef Q_OS_UNIX
#include <unistd.h>
#endif

#include <QSettings>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusVariant>
#include <QDBusArgument>

ShellState::ShellState(WindowManager *winMgr, MenuRegistrar *menuReg, QObject *parent)
    : QObject(parent)
    , m_winMgr(winMgr)
    , m_menuReg(menuReg)
{
    m_clockTimer = new QTimer(this);
    connect(m_clockTimer, &QTimer::timeout, this, &ShellState::onTimeTick);
    m_clockTimer->start(1000);
    onTimeTick();

    connect(m_winMgr, &WindowManager::windowListChanged, this, &ShellState::onWindowListChanged);
    connect(m_winMgr, &WindowManager::activeWindowChanged, this, &ShellState::onActiveWindowChanged);
    connect(m_menuReg, &MenuRegistrar::menuUpdated, this, &ShellState::onMenuUpdated);

    loadSettings();
    reloadKnownApps();
    loadDockConfig();
    updateDockItems();
}

ShellState::~ShellState() = default;

QString ShellState::activeAppName() const { return m_activeAppName; }
QString ShellState::activeAppId() const { return m_activeAppId; }
QString ShellState::activeWindowId() const { return m_activeWindowId; }
bool ShellState::isFullscreen() const { return m_isFullscreen; }
QVariantList ShellState::globalMenus() const { return m_globalMenus; }
QVariantList ShellState::dockItems() const { return m_dockItems; }
QString ShellState::systemTime() const { return m_systemTime; }
bool ShellState::isDark() const { return m_isDark; }

void ShellState::setIsDark(bool dark)
{
    if (m_isDark != dark) {
        m_isDark = dark;
        saveSetting("appearance.mode", dark ? "dark" : "light");
        syncPortalAppearance();
        Q_EMIT themeChanged();
    }
}

void ShellState::toggleTheme()
{
    setIsDark(!m_isDark);
}

bool ShellState::spotlightVisible() const { return m_spotlightVisible; }
void ShellState::setSpotlightVisible(bool visible)
{
    if (m_spotlightVisible != visible) {
        m_spotlightVisible = visible;
        if (visible) {
            setControlCenterVisible(false);
            setNotificationCenterVisible(false);
            performSearch(m_searchQuery);
        }
        Q_EMIT spotlightVisibleChanged();
    }
}
QString ShellState::searchQuery() const { return m_searchQuery; }
void ShellState::setSearchQuery(const QString &query)
{
    if (m_searchQuery != query) {
        m_searchQuery = query;
        performSearch(query);
        Q_EMIT searchQueryChanged();
    }
}
QVariantList ShellState::searchResults() const { return m_searchResults; }

bool ShellState::controlCenterVisible() const { return m_controlCenterVisible; }
void ShellState::setControlCenterVisible(bool visible)
{
    if (m_controlCenterVisible != visible) {
        m_controlCenterVisible = visible;
        if (visible) {
            setSpotlightVisible(false);
            setNotificationCenterVisible(false);
        }
        Q_EMIT controlCenterVisibleChanged();
    }
}
int ShellState::volume() const { return m_volume; }
void ShellState::setVolume(int vol)
{
    vol = qBound(0, vol, 100);
    if (m_volume != vol) {
        m_volume = vol;
        saveSetting("sound.volume", vol);
        Q_EMIT volumeChanged();
    }
}
int ShellState::brightness() const { return m_brightness; }
void ShellState::setBrightness(int bri)
{
    bri = qBound(0, bri, 100);
    if (m_brightness != bri) {
        m_brightness = bri;
        Q_EMIT brightnessChanged();
    }
}
bool ShellState::wifiEnabled() const { return m_wifiEnabled; }
void ShellState::setWifiEnabled(bool enabled)
{
    if (m_wifiEnabled != enabled) {
        m_wifiEnabled = enabled;
        saveSetting("network.wifi.enabled", enabled);
        Q_EMIT wifiChanged();
    }
}
QString ShellState::wifiSsid() const { return m_wifiEnabled ? m_wifiSsid : "Not Connected"; }
bool ShellState::bluetoothEnabled() const { return m_bluetoothEnabled; }
void ShellState::setBluetoothEnabled(bool enabled)
{
    if (m_bluetoothEnabled != enabled) {
        m_bluetoothEnabled = enabled;
        saveSetting("bluetooth.enabled", enabled);
        Q_EMIT bluetoothChanged();
    }
}
bool ShellState::doNotDisturb() const { return m_doNotDisturb; }
void ShellState::setDoNotDisturb(bool dnd)
{
    if (m_doNotDisturb != dnd) {
        m_doNotDisturb = dnd;
        Q_EMIT doNotDisturbChanged();
    }
}

bool ShellState::dockMagnification() const { return m_dockMagnification; }
void ShellState::setDockMagnification(bool enabled)
{
    if (m_dockMagnification != enabled) {
        m_dockMagnification = enabled;
        saveSetting("dock.magnification", enabled);
        Q_EMIT dockMagnificationChanged();
    }
}
qreal ShellState::dockScaleMax() const { return m_dockScaleMax; }
void ShellState::setDockScaleMax(qreal maxScale)
{
    if (!qFuzzyCompare(m_dockScaleMax, maxScale)) {
        m_dockScaleMax = maxScale;
        saveSetting("dock.magnificationScale", maxScale);
        Q_EMIT dockScaleMaxChanged();
    }
}

bool ShellState::overviewActive() const { return m_overviewActive; }
void ShellState::setOverviewActive(bool active)
{
    if (m_overviewActive != active) {
        m_overviewActive = active;
        Q_EMIT overviewActiveChanged();
    }
}

void ShellState::toggleSpotlight()
{
    setSpotlightVisible(!m_spotlightVisible);
}

void ShellState::toggleControlCenter()
{
    setControlCenterVisible(!m_controlCenterVisible);
}

void ShellState::toggleWifi()
{
    setWifiEnabled(!m_wifiEnabled);
}

void ShellState::toggleBluetooth()
{
    setBluetoothEnabled(!m_bluetoothEnabled);
}

void ShellState::toggleDoNotDisturb()
{
    setDoNotDisturb(!m_doNotDisturb);
}

void ShellState::toggleOverview()
{
    setOverviewActive(!m_overviewActive);
    QDBusMessage msg = QDBusMessage::createMethodCall(
        "org.kde.KWin",
        "/Effects",
        "org.kde.kwin.Effects",
        "toggleEffect"
    );
    msg << QString("conjunction-overview");
    QDBusConnection::sessionBus().send(msg);
}

void ShellState::aboutCurrentApp()
{
    qInfo() << "[ShellState] About requested for:" << m_activeAppName;
}

void ShellState::hideCurrentApp()
{
    if (!m_activeWindowId.isEmpty()) {
        m_winMgr->minimizeWindow(m_activeWindowId);
    }
}

void ShellState::hideOthers()
{
    for (const auto &win : m_winMgr->windows()) {
        if (win.internalId != m_activeWindowId) {
            m_winMgr->minimizeWindow(win.internalId);
        }
    }
}

void ShellState::showAll()
{
    for (const auto &win : m_winMgr->windows()) {
        m_winMgr->unminimizeWindow(win.internalId);
    }
}

void ShellState::quitCurrentApp()
{
    if (!m_activeWindowId.isEmpty()) {
        closeWindow(m_activeWindowId);
    }
}

void ShellState::onTimeTick()
{
    QString newTime = QDateTime::currentDateTime().toString("HH:mm");
    if (m_systemTime != newTime) {
        m_systemTime = newTime;
        Q_EMIT systemTimeChanged();
    }
}

static QString settingsFilePath()
{
    QString configDir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
    return configDir + "/conjunction/settings.ini";
}

bool ShellState::initDBus()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        qWarning() << "[ShellState] Session D-Bus not connected";
        return false;
    }

    if (!bus.registerService("org.conjunction.Settings")) {
        qWarning() << "[ShellState] Failed to register service org.conjunction.Settings:" << bus.lastError().message();
    }

    if (!bus.registerObject("/org/conjunction/Settings", this, QDBusConnection::ExportAllContents)) {
        qWarning() << "[ShellState] Failed to register object /org/conjunction/Settings:" << bus.lastError().message();
        return false;
    }

    qInfo() << "[ShellState] Successfully registered org.conjunction.Settings on session bus";
    initNotificationService();
    syncPortalAppearance();
    return true;
}

void ShellState::loadSettings()
{
    QString path = settingsFilePath();
    QSettings s(path, QSettings::IniFormat);

    QString mode = s.value("Appearance/mode", "dark").toString();
    m_isDark = (mode != "light");

    if (s.contains("Dock/magnification")) {
        m_dockMagnification = s.value("Dock/magnification", true).toBool();
    }
    if (s.contains("Dock/magnification_scale")) {
        m_dockScaleMax = s.value("Dock/magnification_scale", 1.35).toReal();
    }
    if (s.contains("Sound/volume")) {
        m_volume = s.value("Sound/volume", 75).toInt();
    }
    if (s.contains("Network/wifi_enabled")) {
        m_wifiEnabled = s.value("Network/wifi_enabled", true).toBool();
    }
    if (s.contains("Bluetooth/enabled")) {
        m_bluetoothEnabled = s.value("Bluetooth/enabled", true).toBool();
    }
    if (s.contains("Sound/doNotDisturb")) {
        m_doNotDisturb = s.value("Sound/doNotDisturb", false).toBool();
    }
    if (s.contains("Accessibility/reducedMotion")) {
        m_reducedMotion = s.value("Accessibility/reducedMotion", false).toBool();
    }
}

void ShellState::saveSetting(const QString &key, const QVariant &val)
{
    QString path = settingsFilePath();
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSettings s(path, QSettings::IniFormat);

    if (key == "appearance.mode") {
        s.setValue("Appearance/mode", val.toString());
    } else if (key == "dock.size") {
        s.setValue("Dock/size", val.toInt());
    } else if (key == "dock.magnification") {
        s.setValue("Dock/magnification", val.toBool());
    } else if (key == "dock.magnificationScale") {
        s.setValue("Dock/magnification_scale", val.toReal());
    } else if (key == "sound.doNotDisturb") {
        s.setValue("Sound/doNotDisturb", val.toBool());
    } else if (key == "accessibility.reducedMotion") {
        s.setValue("Accessibility/reducedMotion", val.toBool());
    } else if (key == "sound.volume") {
        s.setValue("Sound/volume", val.toInt());
    } else if (key == "network.wifi.enabled") {
        s.setValue("Network/wifi_enabled", val.toBool());
    } else if (key == "bluetooth.enabled") {
        s.setValue("Bluetooth/enabled", val.toBool());
    }
    s.sync();
    Q_EMIT SettingChanged(key, val);
}

QDBusVariant ShellState::GetSetting(const QString &key) const
{
    if (key == "appearance.mode") return QDBusVariant(m_isDark ? "dark" : "light");
    if (key == "dock.size") {
        QString path = settingsFilePath();
        QSettings s(path, QSettings::IniFormat);
        return QDBusVariant(s.value("Dock/size", 68).toInt());
    }
    if (key == "dock.magnification") return QDBusVariant(m_dockMagnification);
    if (key == "dock.magnificationScale") return QDBusVariant(m_dockScaleMax);
    if (key == "sound.volume") return QDBusVariant(m_volume);
    if (key == "network.wifi.enabled") return QDBusVariant(m_wifiEnabled);
    if (key == "bluetooth.enabled") return QDBusVariant(m_bluetoothEnabled);
    if (key == "displays.scale") return QDBusVariant(1.0);
    if (key == "sound.doNotDisturb") return QDBusVariant(m_doNotDisturb);
    if (key == "accessibility.reducedMotion") return QDBusVariant(m_reducedMotion);

    QString path = settingsFilePath();
    QSettings s(path, QSettings::IniFormat);
    return QDBusVariant(s.value(key));
}

bool ShellState::SetSetting(const QString &key, const QDBusVariant &dbusValue)
{
    QVariant value = dbusValue.variant();
    // Authoritative boundary validation
    if (key == "appearance.mode") {
        QString mode = value.toString().toLower();
        if (mode != "dark" && mode != "light") return false;
        setIsDark(mode == "dark");
        return true;
    }
    if (key == "dock.size") {
        bool ok = false;
        int sz = value.toInt(&ok);
        if (!ok || sz < 32 || sz > 128) return false;
        saveSetting("dock.size", sz);
        return true;
    }
    if (key == "dock.magnification") {
        if (!value.canConvert<bool>()) return false;
        setDockMagnification(value.toBool());
        return true;
    }
    if (key == "dock.magnificationScale") {
        bool ok = false;
        qreal scale = value.toReal(&ok);
        if (!ok || scale < 1.1 || scale > 2.0) return false;
        setDockScaleMax(scale);
        return true;
    }
    if (key == "sound.volume") {
        bool ok = false;
        int vol = value.toInt(&ok);
        if (!ok || vol < 0 || vol > 100) return false;
        setVolume(vol);
        return true;
    }
    if (key == "network.wifi.enabled") {
        if (!value.canConvert<bool>()) return false;
        setWifiEnabled(value.toBool());
        return true;
    }
    if (key == "bluetooth.enabled") {
        if (!value.canConvert<bool>()) return false;
        setBluetoothEnabled(value.toBool());
        return true;
    }
    if (key == "sound.doNotDisturb") {
        if (!value.canConvert<bool>()) return false;
        setDoNotDisturb(value.toBool());
        return true;
    }
    if (key == "accessibility.reducedMotion") {
        if (!value.canConvert<bool>()) return false;
        setReducedMotion(value.toBool());
        return true;
    }

    saveSetting(key, value);
    return true;
}

QVariantMap ShellState::GetAllSettings() const
{
    QVariantMap map;
    map["appearance.mode"] = m_isDark ? "dark" : "light";
    map["dock.magnification"] = m_dockMagnification;
    map["dock.magnificationScale"] = m_dockScaleMax;
    map["sound.volume"] = m_volume;
    map["network.wifi.enabled"] = m_wifiEnabled;
    map["bluetooth.enabled"] = m_bluetoothEnabled;
    map["displays.scale"] = 1.0;
    map["sound.doNotDisturb"] = m_doNotDisturb;
    map["accessibility.reducedMotion"] = m_reducedMotion;
    return map;
}

void ShellState::OpenSetting(const QString &target)
{
    QString url = target;
    if (!url.startsWith("settings://")) {
        url = "settings://" + target;
    }
    QProcess::startDetached("conjunction-settings", QStringList() << "--url" << url);
}

static QString dockConfigPath()
{
    QString configDir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
    return configDir + "/conjunction/dock.json";
}

void ShellState::loadDockConfig()
{
    QString path = dockConfigPath();
    QFile file(path);
    if (file.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        if (doc.isObject()) {
            QJsonArray arr = doc.object().value("pinned_apps").toArray();
            m_pinnedApps.clear();
            for (const auto &val : arr) {
                m_pinnedApps.append(val.toString());
            }
        }
    }

    if (m_pinnedApps.isEmpty()) {
        m_pinnedApps = {
            "dev.conjunction.gallery",
            "dev.conjunction.reference",
            "org.conjunction.files",
            "org.conjunction.terminal"
        };
    }
}

void ShellState::saveDockConfig()
{
    QString path = dockConfigPath();
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        QJsonObject root;
        QJsonArray arr;
        for (const auto &id : m_pinnedApps) {
            arr.append(id);
        }
        root["pinned_apps"] = arr;
        file.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    }
}

void ShellState::reloadKnownApps()
{
    // Default system apps
    RegisteredAppInfo gallery;
    gallery.id = "dev.conjunction.gallery";
    gallery.name = "Conjunction Gallery";
    gallery.icon = "gallery";
    gallery.executablePath = "/usr/bin/conjunction-design-gallery";
    m_knownApps.insert(gallery.id, gallery);

    RegisteredAppInfo reference;
    reference.id = "dev.conjunction.reference";
    reference.name = "Desktop Reference";
    reference.icon = "desktop";
    reference.executablePath = "/usr/bin/conjunction-reference-app";
    m_knownApps.insert(reference.id, reference);

    RegisteredAppInfo files;
    files.id = "org.conjunction.files";
    files.name = "Files";
    files.icon = "folder";
    m_knownApps.insert(files.id, files);

    RegisteredAppInfo terminal;
    terminal.id = "org.conjunction.terminal";
    terminal.name = "Terminal";
    terminal.icon = "terminal";
    m_knownApps.insert(terminal.id, terminal);

    RegisteredAppInfo browser;
    browser.id = "org.conjunction.browser";
    browser.name = "Browser";
    browser.icon = "globe";
    m_knownApps.insert(browser.id, browser);

    // Try reading registered apps from conj-appctl list --json if available
    QProcess proc;
    proc.start("conj-appctl", QStringList() << "list");
    if (proc.waitForFinished(500)) {
        QString out = proc.readAllStandardOutput();
        for (const QString &line : out.split('\n')) {
            QString trimmed = line.trimmed();
            if (trimmed.isEmpty() || trimmed.startsWith("ID")) continue;
            QStringList parts = trimmed.split(QRegularExpression("\\s{2,}"));
            if (!parts.isEmpty()) {
                QString id = parts[0].trimmed();
                if (!m_knownApps.contains(id)) {
                    RegisteredAppInfo app;
                    app.id = id;
                    app.name = (parts.size() > 1) ? parts[1].trimmed() : id;
                    app.icon = "application-x-executable";
                    m_knownApps.insert(id, app);
                }
            }
        }
    }
}

RegisteredAppInfo ShellState::resolveApp(const ShellWindowEntry &win)
{
    QString cleanId = win.appId.trimmed();
    if (cleanId.endsWith(".desktop")) {
        cleanId.chop(8);
    }

    // 1. Exact appId match
    if (m_knownApps.contains(cleanId)) {
        return m_knownApps.value(cleanId);
    }
    if (m_knownApps.contains(win.appId)) {
        return m_knownApps.value(win.appId);
    }

    // 2. Fallback by window title or process
    RegisteredAppInfo fallback;
    fallback.id = !cleanId.isEmpty() ? cleanId : QString("unknown.%1").arg(win.pid);
    fallback.name = !win.title.trimmed().isEmpty() ? win.title.trimmed() : (!cleanId.isEmpty() ? cleanId : "Application");
    fallback.icon = "application-x-executable";
    return fallback;
}

void ShellState::updateDockItems()
{
    QList<ShellWindowEntry> allWindows = m_winMgr->windows();
    QMap<QString, QList<ShellWindowEntry>> appWindows;

    for (const auto &win : allWindows) {
        RegisteredAppInfo app = resolveApp(win);
        appWindows[app.id].append(win);
    }

    QVariantList newItems;
    QSet<QString> processedApps;

    // 1. Pinned apps in exact order
    for (const QString &pinnedId : m_pinnedApps) {
        processedApps.insert(pinnedId);
        QVariantMap item;
        item["id"] = pinnedId;
        item["pinned"] = true;

        RegisteredAppInfo app = m_knownApps.value(pinnedId);
        item["name"] = !app.name.isEmpty() ? app.name : pinnedId;
        item["icon"] = !app.icon.isEmpty() ? app.icon : "application-x-executable";

        QList<ShellWindowEntry> wins = appWindows.value(pinnedId);
        item["running"] = !wins.isEmpty();
        item["windowCount"] = wins.size();

        bool active = false;
        QStringList winIds;
        for (const auto &w : wins) {
            winIds.append(w.internalId);
            if (w.active) active = true;
        }
        item["active"] = active;
        item["windowIds"] = winIds;

        newItems.append(item);
    }

    // 2. Unpinned running apps
    for (auto it = appWindows.constBegin(); it != appWindows.constEnd(); ++it) {
        QString appId = it.key();
        if (processedApps.contains(appId) || it.value().isEmpty()) {
            continue;
        }
        processedApps.insert(appId);

        RegisteredAppInfo app = resolveApp(it.value().first());
        QVariantMap item;
        item["id"] = appId;
        item["name"] = app.name;
        item["icon"] = app.icon;
        item["pinned"] = false;
        item["running"] = true;
        item["windowCount"] = it.value().size();

        bool active = false;
        QStringList winIds;
        for (const auto &w : it.value()) {
            winIds.append(w.internalId);
            if (w.active) active = true;
        }
        item["active"] = active;
        item["windowIds"] = winIds;

        newItems.append(item);
    }

    m_dockItems = newItems;
    Q_EMIT dockItemsChanged();
}

void ShellState::updateActiveApp()
{
    ShellWindowEntry activeWin = m_winMgr->activeWindow();
    if (!activeWin.internalId.isEmpty()) {
        RegisteredAppInfo app = resolveApp(activeWin);
        m_activeAppName = app.name;
        m_activeAppId = app.id;
        m_activeWindowId = activeWin.internalId;
        m_isFullscreen = activeWin.isFullscreen;

        // Check if menu registrar has exported menus for this window
        uint winId = activeWin.internalId.toUInt();
        if (winId > 0 && m_menuReg->hasMenuForWindow(winId)) {
            m_globalMenus = m_menuReg->fetchLayoutForWindow(winId);
        } else {
            // No exported menu
            m_globalMenus.clear();
        }
    } else {
        m_activeAppName = "Finder";
        m_activeAppId = "org.conjunction.finder";
        m_activeWindowId.clear();
        m_isFullscreen = false;
        m_globalMenus.clear();
    }

    Q_EMIT activeAppChanged();
    Q_EMIT fullscreenChanged();
    Q_EMIT globalMenusChanged();
}

void ShellState::onWindowListChanged()
{
    updateDockItems();
    updateActiveApp();
}

void ShellState::onActiveWindowChanged(const QString &winId)
{
    Q_UNUSED(winId);
    updateDockItems();
    updateActiveApp();
}

void ShellState::onMenuUpdated(uint windowId)
{
    if (m_activeWindowId.toUInt() == windowId) {
        updateActiveApp();
    }
}

void ShellState::launchApp(const QString &appId)
{
    qInfo() << "[ShellState] Launching application:" << appId;
    // Use conj-open or conj-appctl
    QProcess::startDetached("conj-open", QStringList() << appId);
}

void ShellState::focusApp(const QString &appId)
{
    for (const auto &val : m_dockItems) {
        QVariantMap item = val.toMap();
        if (item["id"].toString() == appId) {
            QStringList winIds = item["windowIds"].toStringList();
            if (!winIds.isEmpty()) {
                activateWindow(winIds.first());
            } else {
                launchApp(appId);
            }
            return;
        }
    }
    launchApp(appId);
}

void ShellState::activateWindow(const QString &windowId)
{
    m_winMgr->activateWindow(windowId);
}

void ShellState::closeWindow(const QString &windowId)
{
    m_winMgr->closeWindow(windowId);
}

void ShellState::triggerMenuAction(int actionId)
{
    uint winId = m_activeWindowId.toUInt();
    if (winId > 0) {
        m_menuReg->triggerAction(winId, actionId);
    }
}

void ShellState::pinApp(const QString &appId)
{
    if (!m_pinnedApps.contains(appId)) {
        m_pinnedApps.append(appId);
        saveDockConfig();
        updateDockItems();
    }
}

void ShellState::unpinApp(const QString &appId)
{
    if (m_pinnedApps.removeAll(appId) > 0) {
        saveDockConfig();
        updateDockItems();
    }
}

void ShellState::quitApp(const QString &appId)
{
    for (const auto &val : m_dockItems) {
        QVariantMap item = val.toMap();
        if (item["id"].toString() == appId) {
            QStringList winIds = item["windowIds"].toStringList();
            for (const auto &wId : winIds) {
                closeWindow(wId);
            }
            return;
        }
    }
}


void ShellState::simulateWindow(const QString &winId, const QString &title, const QString &appId, bool active)
{
    if (active) {
        m_winMgr->WindowActivated(winId, title, appId, 1234, false);
    } else {
        m_winMgr->WindowAdded(winId, title, appId, 1234, false);
    }
}

void ShellState::simulateGlobalMenu(const QVariantList &menus)
{
    m_globalMenus = menus;
    Q_EMIT globalMenusChanged();
}

void ShellState::simulateNotification(uint id, const QString &appName, const QString &summary, const QString &body)
{
    QJsonObject obj;
    obj["id"] = (int)id;
    obj["appName"] = appName;
    obj["summary"] = summary;
    obj["body"] = body;
    obj["icon"] = "dialog-information";
    obj["urgency"] = 1;
    obj["actions"] = QJsonArray();
    QJsonDocument doc(obj);
    onNotificationAdded(id, QString::fromUtf8(doc.toJson(QJsonDocument::Compact)));
}

void ShellState::performSearch(const QString &query)
{
    QString q = query.trimmed().toLower();
    QVariantList results;

    if (q.isEmpty()) {
        QStringList defaultAppIds = {"dev.conjunction.gallery", "dev.conjunction.reference", "org.conjunction.files"};
        for (const auto &appId : defaultAppIds) {
            if (m_knownApps.contains(appId)) {
                RegisteredAppInfo app = m_knownApps[appId];
                QVariantMap item;
                item["id"] = app.id;
                item["title"] = app.name;
                item["subtitle"] = "Application • " + app.id;
                item["category"] = "Applications";
                item["icon"] = app.icon;
                item["actionData"] = "app:" + app.id;
                results.append(item);
            }
        }
        m_searchResults = results;
        Q_EMIT searchResultsChanged();
        return;
    }

    // 1. Search Applications
    for (auto it = m_knownApps.constBegin(); it != m_knownApps.constEnd(); ++it) {
        const auto &app = it.value();
        if (app.name.toLower().contains(q) || app.id.toLower().contains(q) || app.packageName.toLower().contains(q)) {
            QVariantMap item;
            item["id"] = app.id;
            item["title"] = app.name;
            item["subtitle"] = "Application • " + app.id;
            item["category"] = "Applications";
            item["icon"] = app.icon;
            item["actionData"] = "app:" + app.id;
            results.append(item);
        }
    }

    // 2. Search Settings & Actions from Canonical Registry
    struct SettingDef { const char *id; const char *title; const char *sub; const char *icon; const char *act; const char *kw; };
    static const SettingDef settingsList[] = {
        {"appearance.mode", "Appearance Mode", "Theme • Switch between Light and Dark desktop themes", "preferences-desktop-theme", "settings://appearance?setting=appearance.mode", "dark light theme mode night color"},
        {"appearance.accent", "Accent Color", "Theme • System highlight and focus tint color", "preferences-desktop-theme", "settings://appearance?setting=appearance.accent", "accent tint highlight color blue"},
        {"dock.magnification", "Dock Magnification", "Dock • Magnify Dock icons on pointer hover", "preferences-desktop", "settings://dock?setting=dock.magnification", "dock magnification zoom hover scale"},
        {"dock.size", "Dock Size", "Dock • Base height and icon scale of the desktop Dock", "preferences-desktop", "settings://dock?setting=dock.size", "dock size icons height bar"},
        {"dock.magnificationScale", "Magnification Scale", "Dock • Maximum scale multiplier for hovered Dock icons", "preferences-desktop", "settings://dock?setting=dock.magnificationScale", "dock zoom scale max magnification"},
        {"displays.scale", "Display Scale", "Scale & Resolution • User interface scaling factor for displays", "video-display", "settings://displays?setting=displays.scale", "screen scale monitor resolution hidpi zoom"},
        {"sound.volume", "Output Volume", "Output • Main speaker and headphone output volume", "audio-volume-high", "settings://sound?setting=sound.volume", "sound volume speaker audio loudness"},
        {"sound.muted", "Mute Sound", "Output • Mute all audio output", "audio-volume-muted", "settings://sound?setting=sound.muted", "mute sound silence audio"},
        {"network.wifi.enabled", "Wi-Fi", "Wi-Fi • Enable or disable wireless networking", "network-wireless", "settings://network?setting=network.wifi.enabled", "wifi wireless network internet ssid hotspot"},
        {"bluetooth.enabled", "Bluetooth", "Bluetooth Adapter • Enable or disable Bluetooth wireless adapter", "bluetooth", "settings://bluetooth?setting=bluetooth.enabled", "bluetooth wireless pair devices mouse keyboard"},
        {"desktop.wallpaper", "Desktop Background", "Wallpaper • Wallpaper image and desktop style", "preferences-desktop-wallpaper", "settings://dock?setting=desktop.wallpaper", "wallpaper background desktop picture"},
        {"general.about", "About Conjunction", "System • OS, kernel, specs, and memory", "help-about", "settings://about", "about system kernel cpu ram specs info version"},
        {"settings.appearance", "Appearance & Theme", "Appearance • Dark mode, light mode, and accent colors", "preferences-desktop-theme", "settings://appearance", "theme dark light appearance"},
        {"settings.dock", "Desktop & Dock", "Dock • Dock size, magnification, and auto-hide", "preferences-desktop", "settings://dock", "dock desktop magnification autohide"},
        {"settings.display", "Displays & Brightness", "Displays • Resolution, refresh rate, scaling", "video-display", "settings://displays", "screen monitor resolution brightness displays"},
        {"settings.sound", "Sound & Audio", "Sound • Output volume, audio devices", "audio-volume-high", "settings://sound", "audio volume speakers sound"},
        {"settings.network", "Wi-Fi & Network", "Network • Wireless connections, Ethernet", "network-wireless", "settings://network", "wifi wireless network internet"},
        {"settings.bluetooth", "Bluetooth", "Bluetooth • Connected devices and wireless pairing", "bluetooth", "settings://bluetooth", "bluetooth wireless pair devices"},
        {"action.lock", "Lock Screen", "Lock session (Ctrl+Alt+L)", "system-lock-screen", "action:lock", "lock screen session"},
        {"action.logout", "Log Out", "Log out current user", "system-log-out", "action:logout", "logout exit sign out"},
        {"action.restart", "Restart Computer", "Reboot system", "system-reboot", "action:restart", "restart reboot"},
        {"action.shutdown", "Shut Down", "Power off system", "system-shutdown", "action:shutdown", "shutdown power off"},
        {"action.overview", "Mission Control / Overview", "Show all open windows", "view-paged", "action:overview", "overview mission control expose windows"}
    };

    for (const auto &s : settingsList) {
        QString titleStr = QString::fromUtf8(s.title);
        QString kwStr = QString::fromUtf8(s.kw);
        if (titleStr.toLower().contains(q) || kwStr.contains(q)) {
            QVariantMap item;
            item["id"] = QString::fromUtf8(s.id);
            item["title"] = titleStr;
            item["subtitle"] = QString::fromUtf8(s.sub);
            item["category"] = "Settings & Actions";
            item["icon"] = QString::fromUtf8(s.icon);
            item["actionData"] = QString::fromUtf8(s.act);
            results.append(item);
        }
    }

    // 3. Search Bounded Files in Home
    QString home = QDir::homePath();
    QStringList searchDirs = { home + "/Documents", home + "/Downloads", home + "/Desktop" };
    int fileCount = 0;
    for (const auto &dirPath : searchDirs) {
        if (fileCount >= 5) break;
        QDir dir(dirPath);
        if (dir.exists()) {
            QFileInfoList entries = dir.entryInfoList(QDir::Files | QDir::NoDotAndDotDot);
            for (const auto &fi : entries) {
                if (fileCount >= 5) break;
                if (fi.fileName().toLower().contains(q)) {
                    QVariantMap item;
                    item["id"] = fi.absoluteFilePath();
                    item["title"] = fi.fileName();
                    item["subtitle"] = fi.absolutePath();
                    item["category"] = "Files";
                    item["icon"] = "text-x-generic";
                    item["actionData"] = "file:" + fi.absoluteFilePath();
                    results.append(item);
                    fileCount++;
                }
            }
        }
    }

    m_searchResults = results;
    Q_EMIT searchResultsChanged();
}

void ShellState::activateSearchResult(int index)
{
    if (index < 0 || index >= m_searchResults.size()) return;
    QVariantMap item = m_searchResults[index].toMap();
    QString actionData = item["actionData"].toString();
    setSpotlightVisible(false);

    if (actionData.startsWith("app:")) {
        QString appId = actionData.mid(4);
        focusApp(appId);
    } else if (actionData.startsWith("settings://") || actionData.startsWith("settings:")) {
        QString url = actionData;
        if (url.startsWith("settings:") && !url.startsWith("settings://")) {
            url = "settings://" + url.mid(9);
        }
        QProcess::startDetached("conjunction-settings", QStringList() << "--url" << url);
    } else if (actionData.startsWith("action:")) {
        QString act = actionData.mid(7);
        if (act == "overview") {
            toggleOverview();
        } else {
            requestSystemAction(act);
        }
    } else if (actionData.startsWith("file:")) {
        QString path = actionData.mid(5);
        QProcess::startDetached("xdg-open", QStringList() << path);
    }
}

// ==================== Phase 7A Additions ====================

bool ShellState::notificationCenterVisible() const { return m_notificationCenterVisible; }
void ShellState::setNotificationCenterVisible(bool visible)
{
    if (m_notificationCenterVisible != visible) {
        m_notificationCenterVisible = visible;
        if (visible) {
            setControlCenterVisible(false);
            setSpotlightVisible(false);
            onNotificationHistoryChanged();
        }
        Q_EMIT notificationCenterVisibleChanged();
    }
}

QVariantList ShellState::activeBanners() const { return m_activeBanners; }
QVariantList ShellState::notificationHistory() const { return m_notificationHistory; }

bool ShellState::reducedMotion() const { return m_reducedMotion; }
void ShellState::setReducedMotion(bool rm)
{
    if (m_reducedMotion != rm) {
        m_reducedMotion = rm;
        saveSetting("accessibility.reducedMotion", rm);
        syncPortalAppearance();
        Q_EMIT reducedMotionChanged();
    }
}

void ShellState::toggleNotificationCenter()
{
    setNotificationCenterVisible(!m_notificationCenterVisible);
}

void ShellState::dismissNotification(uint id)
{
    QDBusMessage msg = QDBusMessage::createMethodCall(
        QStringLiteral("org.conjunction.Notifications"),
        QStringLiteral("/org/conjunction/Notifications"),
        QStringLiteral("org.conjunction.Notifications"),
        QStringLiteral("Dismiss")
    );
    msg << id;
    QDBusConnection::sessionBus().call(msg, QDBus::NoBlock);

    onNotificationRemoved(id);
}

void ShellState::invokeNotificationAction(uint id, const QString &actionKey)
{
    QDBusMessage msg = QDBusMessage::createMethodCall(
        QStringLiteral("org.conjunction.Notifications"),
        QStringLiteral("/org/conjunction/Notifications"),
        QStringLiteral("org.conjunction.Notifications"),
        QStringLiteral("TriggerAction")
    );
    msg << id << actionKey;
    QDBusConnection::sessionBus().call(msg, QDBus::NoBlock);

    onNotificationRemoved(id);
}

void ShellState::clearNotificationHistory()
{
    QDBusMessage msg = QDBusMessage::createMethodCall(
        QStringLiteral("org.conjunction.Notifications"),
        QStringLiteral("/org/conjunction/Notifications"),
        QStringLiteral("org.conjunction.Notifications"),
        QStringLiteral("ClearAll")
    );
    QDBusConnection::sessionBus().call(msg, QDBus::NoBlock);

    m_activeBanners.clear();
    m_notificationHistory.clear();
    Q_EMIT activeBannersChanged();
    Q_EMIT notificationHistoryChanged();
}

void ShellState::lockScreen()
{
    QDBusMessage call = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.ScreenSaver"),
        QStringLiteral("/ScreenSaver"),
        QStringLiteral("org.freedesktop.ScreenSaver"),
        QStringLiteral("Lock")
    );
    QDBusConnection::sessionBus().call(call, QDBus::NoBlock);
    Q_EMIT systemActionTriggered("lock");
}

void ShellState::suspendSession()
{
    QDBusMessage call = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.login1"),
        QStringLiteral("/org/freedesktop/login1"),
        QStringLiteral("org.freedesktop.login1.Manager"),
        QStringLiteral("Suspend")
    );
    call << true;
    QDBusConnection::systemBus().call(call, QDBus::NoBlock);
    Q_EMIT systemActionTriggered("suspend");
}

void ShellState::restartSystem()
{
    QDBusMessage call = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.login1"),
        QStringLiteral("/org/freedesktop/login1"),
        QStringLiteral("org.freedesktop.login1.Manager"),
        QStringLiteral("Reboot")
    );
    call << true;
    QDBusConnection::systemBus().call(call, QDBus::NoBlock);
    Q_EMIT systemActionTriggered("restart");
}

void ShellState::shutdownSystem()
{
    QDBusMessage call = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.login1"),
        QStringLiteral("/org/freedesktop/login1"),
        QStringLiteral("org.freedesktop.login1.Manager"),
        QStringLiteral("PowerOff")
    );
    call << true;
    QDBusConnection::systemBus().call(call, QDBus::NoBlock);
    Q_EMIT systemActionTriggered("shutdown");
}

void ShellState::logoutSession()
{
    QDBusMessage call = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.ksmserver"),
        QStringLiteral("/KSMServer"),
        QStringLiteral("org.kde.KSMServerInterface"),
        QStringLiteral("logout")
    );
    call << 0 << 0 << 0;
    QDBusConnection::sessionBus().call(call, QDBus::NoBlock);
    Q_EMIT systemActionTriggered("logout");
}

void ShellState::requestSystemAction(const QString &action)
{
    if (action == "lock") lockScreen();
    else if (action == "suspend" || action == "sleep") suspendSession();
    else if (action == "restart" || action == "reboot") restartSystem();
    else if (action == "shutdown" || action == "poweroff") shutdownSystem();
    else if (action == "logout") logoutSession();
}

bool ShellState::canSuspend() const
{
    QDBusMessage call = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.login1"),
        QStringLiteral("/org/freedesktop/login1"),
        QStringLiteral("org.freedesktop.login1.Manager"),
        QStringLiteral("CanSuspend")
    );
    QDBusMessage reply = QDBusConnection::systemBus().call(call, QDBus::Block, 500);
    if (reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()) {
        return reply.arguments().at(0).toString() == QStringLiteral("yes");
    }
    return true;
}

bool ShellState::canReboot() const
{
    QDBusMessage call = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.login1"),
        QStringLiteral("/org/freedesktop/login1"),
        QStringLiteral("org.freedesktop.login1.Manager"),
        QStringLiteral("CanReboot")
    );
    QDBusMessage reply = QDBusConnection::systemBus().call(call, QDBus::Block, 500);
    if (reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()) {
        return reply.arguments().at(0).toString() == QStringLiteral("yes");
    }
    return true;
}

bool ShellState::canPowerOff() const
{
    QDBusMessage call = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.login1"),
        QStringLiteral("/org/freedesktop/login1"),
        QStringLiteral("org.freedesktop.login1.Manager"),
        QStringLiteral("CanPowerOff")
    );
    QDBusMessage reply = QDBusConnection::systemBus().call(call, QDBus::Block, 500);
    if (reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()) {
        return reply.arguments().at(0).toString() == QStringLiteral("yes");
    }
    return true;
}

QVariantList ShellState::checkInhibitors() const
{
    QVariantList list;
    QDBusMessage msg = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.login1"),
        QStringLiteral("/org/freedesktop/login1"),
        QStringLiteral("org.freedesktop.login1.Manager"),
        QStringLiteral("ListInhibitors")
    );
    QDBusMessage reply = QDBusConnection::systemBus().call(msg, QDBus::Block, 500);
    if (reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()) {
        const QDBusArgument arg = reply.arguments().at(0).value<QDBusArgument>();
        arg.beginArray();
        while (!arg.atEnd()) {
            arg.beginStructure();
            QString what, who, why, mode;
            uint uid, pid;
            arg >> what >> who >> why >> mode >> uid >> pid;
            arg.endStructure();
            QVariantMap item;
            item["what"] = what;
            item["who"] = who;
            item["why"] = why;
            item["mode"] = mode;
            item["uid"] = uid;
            item["pid"] = pid;
            list.append(item);
        }
        arg.endArray();
    }
    return list;
}

void ShellState::initNotificationService()
{
    QDBusConnection session = QDBusConnection::sessionBus();
    session.connect(
        QStringLiteral("org.conjunction.Notifications"),
        QStringLiteral("/org/conjunction/Notifications"),
        QStringLiteral("org.conjunction.Notifications"),
        QStringLiteral("NotificationAdded"),
        this,
        SLOT(onNotificationAdded(uint,QString))
    );
    session.connect(
        QStringLiteral("org.conjunction.Notifications"),
        QStringLiteral("/org/conjunction/Notifications"),
        QStringLiteral("org.conjunction.Notifications"),
        QStringLiteral("NotificationUpdated"),
        this,
        SLOT(onNotificationUpdated(uint,QString))
    );
    session.connect(
        QStringLiteral("org.conjunction.Notifications"),
        QStringLiteral("/org/conjunction/Notifications"),
        QStringLiteral("org.conjunction.Notifications"),
        QStringLiteral("NotificationRemoved"),
        this,
        SLOT(onNotificationRemoved(uint))
    );
    session.connect(
        QStringLiteral("org.conjunction.Notifications"),
        QStringLiteral("/org/conjunction/Notifications"),
        QStringLiteral("org.conjunction.Notifications"),
        QStringLiteral("HistoryChanged"),
        this,
        SLOT(onNotificationHistoryChanged())
    );

    fetchNotifications();
}

void ShellState::fetchNotifications()
{
    QDBusMessage msg = QDBusMessage::createMethodCall(
        QStringLiteral("org.conjunction.Notifications"),
        QStringLiteral("/org/conjunction/Notifications"),
        QStringLiteral("org.conjunction.Notifications"),
        QStringLiteral("GetActiveBannersJson")
    );
    QDBusMessage reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 500);
    if (reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()) {
        QString json = reply.arguments().at(0).toString();
        QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
        if (doc.isArray()) {
            QVariantList list;
            for (const auto &val : doc.array()) {
                list.append(val.toObject().toVariantMap());
            }
            m_activeBanners = list;
            Q_EMIT activeBannersChanged();
        }
    }

    onNotificationHistoryChanged();
}

void ShellState::onNotificationAdded(uint id, const QString &json)
{
    Q_UNUSED(id);
    QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    if (doc.isObject()) {
        QVariantMap map = doc.object().toVariantMap();
        bool bannerVis = map.value("bannerVisible", true).toBool();
        if (bannerVis) {
            m_activeBanners.append(map);
            Q_EMIT activeBannersChanged();
        }
    }
    onNotificationHistoryChanged();
}

void ShellState::onNotificationUpdated(uint id, const QString &json)
{
    QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    if (doc.isObject()) {
        QVariantMap map = doc.object().toVariantMap();
        for (int i = 0; i < m_activeBanners.size(); ++i) {
            if (m_activeBanners[i].toMap().value("id").toUInt() == id) {
                m_activeBanners[i] = map;
                Q_EMIT activeBannersChanged();
                break;
            }
        }
    }
    onNotificationHistoryChanged();
}

void ShellState::onNotificationRemoved(uint id)
{
    for (int i = 0; i < m_activeBanners.size(); ++i) {
        if (m_activeBanners[i].toMap().value("id").toUInt() == id) {
            m_activeBanners.removeAt(i);
            Q_EMIT activeBannersChanged();
            break;
        }
    }
}

void ShellState::onNotificationHistoryChanged()
{
    QDBusMessage msg = QDBusMessage::createMethodCall(
        QStringLiteral("org.conjunction.Notifications"),
        QStringLiteral("/org/conjunction/Notifications"),
        QStringLiteral("org.conjunction.Notifications"),
        QStringLiteral("GetHistoryJson")
    );
    QDBusMessage reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 500);
    if (reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()) {
        QString json = reply.arguments().at(0).toString();
        QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
        if (doc.isArray()) {
            QVariantList list;
            for (const auto &val : doc.array()) {
                list.append(val.toObject().toVariantMap());
            }
            m_notificationHistory = list;
            Q_EMIT notificationHistoryChanged();
        }
    }
}

void ShellState::syncPortalAppearance()
{
    QString configDir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
    QDir().mkpath(configDir);

    // 1. Update kdeglobals for xdg-desktop-portal-kde
    QString kdeglobalsPath = configDir + "/kdeglobals";
    QSettings kde(kdeglobalsPath, QSettings::IniFormat);
    kde.beginGroup("General");
    kde.setValue("ColorScheme", m_isDark ? "BreezeDark" : "BreezeLight");
    kde.endGroup();
    kde.beginGroup("KDE");
    kde.setValue("widgetStyle", "Breeze");
    kde.setValue("AnimationDurationFactor", m_reducedMotion ? 0.0 : 1.0);
    kde.endGroup();
    kde.sync();

    // 2. Update kwinrc for animations
    QString kwinrcPath = configDir + "/kwinrc";
    QSettings kwin(kwinrcPath, QSettings::IniFormat);
    kwin.beginGroup("Windows");
    kwin.setValue("AnimationSpeed", m_reducedMotion ? 0 : 3);
    kwin.endGroup();
    kwin.sync();
}
