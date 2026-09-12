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
        Q_EMIT wifiChanged();
    }
}
QString ShellState::wifiSsid() const { return m_wifiEnabled ? m_wifiSsid : "Not Connected"; }
bool ShellState::bluetoothEnabled() const { return m_bluetoothEnabled; }
void ShellState::setBluetoothEnabled(bool enabled)
{
    if (m_bluetoothEnabled != enabled) {
        m_bluetoothEnabled = enabled;
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
        Q_EMIT dockMagnificationChanged();
    }
}
qreal ShellState::dockScaleMax() const { return m_dockScaleMax; }
void ShellState::setDockScaleMax(qreal maxScale)
{
    if (!qFuzzyCompare(m_dockScaleMax, maxScale)) {
        m_dockScaleMax = maxScale;
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

void ShellState::requestSystemAction(const QString &action)
{
    qInfo() << "[ShellState] System action requested:" << action;
    Q_EMIT systemActionTriggered(action);
    if (action == "logout") {
#ifdef Q_OS_UNIX
        QProcess::startDetached("loginctl", QStringList() << "terminate-user" << QString::number(getuid()));
#else
        QProcess::startDetached("loginctl", QStringList() << "terminate-session" << "self");
#endif
    } else if (action == "restart") {
        QProcess::startDetached("systemctl", QStringList() << "reboot");
    } else if (action == "shutdown") {
        QProcess::startDetached("systemctl", QStringList() << "poweroff");
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

    // 2. Search Settings & Actions
    struct SettingDef { const char *id; const char *title; const char *sub; const char *icon; const char *act; const char *kw; };
    static const SettingDef settingsList[] = {
        {"settings.display", "Displays & Brightness", "Resolution, refresh rate", "video-display", "settings:display", "screen monitor brightness night"},
        {"settings.sound", "Sound & Audio", "Output volume, alert sound", "audio-volume-high", "settings:sound", "audio volume speaker sound"},
        {"settings.network", "Wi-Fi & Network", "Wireless connections, IP", "network-wireless", "settings:network", "wifi wireless internet network"},
        {"settings.bluetooth", "Bluetooth", "Connected devices, pairing", "bluetooth", "settings:bluetooth", "bluetooth wireless keyboard mouse"},
        {"settings.appearance", "Appearance & Theme", "Dark mode, light mode, accents", "preferences-desktop-theme", "settings:appearance", "theme dark light color"},
        {"settings.dock", "Desktop & Dock", "Dock size, magnification, auto-hide", "preferences-desktop", "settings:dock", "dock magnification autohide"},
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
    } else if (actionData.startsWith("settings:")) {
        launchApp("org.conjunction.settings");
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
