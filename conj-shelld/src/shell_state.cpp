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
