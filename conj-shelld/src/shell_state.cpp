#include "shell_state.h"
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QLocale>
#include <QProcess>
#include <QRegularExpression>
#include <QStorageInfo>
#include <QTextStream>
#include <QWindow>
#include <QDebug>
#ifdef Q_OS_UNIX
#include <unistd.h>
#endif
#ifdef HAVE_LAYERSHELLQT
#include <LayerShellQt/Window>
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
    loadQuickNote();
    reloadKnownApps();
    refreshMountedVolumes();
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
    QString newTime = QLocale::c().toString(QDateTime::currentDateTime(), QStringLiteral("ddd MMM d  h:mm AP"));
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
    bus.registerObject("/org/conjunction/Shell", this, QDBusConnection::ExportAllContents);

    qInfo() << "[ShellState] Successfully registered org.conjunction.Settings on session bus";
    initNotificationService();
    syncPortalAppearance();
    return true;
}

void ShellState::loadSettings()
{
    QString path = settingsFilePath();
    QSettings s(path, QSettings::IniFormat);

    QString mode = s.value("Appearance/mode", "light").toString();
    m_isDark = (mode == "dark");
    m_accentColor = s.value("Appearance/accent", "blue").toString();

    if (s.contains("Dock/magnification")) {
        m_dockMagnification = s.value("Dock/magnification", true).toBool();
    }
    if (s.contains("Dock/magnification_scale")) {
        m_dockScaleMax = s.value("Dock/magnification_scale", 1.45).toReal();
    }
    if (s.contains("Dock/size")) {
        m_dockTileSize = qBound(16, s.value("Dock/size", 54).toInt(), 128);
    }
    if (s.contains("Dock/autoHide")) {
        m_dockAutoHide = s.value("Dock/autoHide", false).toBool();
    }
    if (s.contains("Dock/minimizeEffect")) {
        m_minimizeEffect = s.value("Dock/minimizeEffect", "genie").toString();
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
    if (s.contains("Accessibility/reduceTransparency")) {
        m_reduceTransparency = s.value("Accessibility/reduceTransparency", false).toBool();
    }
    if (s.contains("Accessibility/increaseContrast")) {
        m_increaseContrast = s.value("Accessibility/increaseContrast", false).toBool();
    }
}

void ShellState::saveSetting(const QString &key, const QVariant &val)
{
    QString path = settingsFilePath();
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSettings s(path, QSettings::IniFormat);

    if (key == "appearance.mode" || key == "Appearance/mode") {
        s.setValue("Appearance/mode", val.toString());
    } else if (key == "appearance.accent" || key == "Appearance/accent") {
        s.setValue("Appearance/accent", val.toString());
    } else if (key == "dock.size" || key == "Dock/size") {
        s.setValue("Dock/size", val.toInt());
    } else if (key == "dock.magnification") {
        s.setValue("Dock/magnification", val.toBool());
    } else if (key == "dock.magnificationScale") {
        s.setValue("Dock/magnification_scale", val.toReal());
    } else if (key == "dock.autoHide" || key == "Dock/autoHide") {
        s.setValue("Dock/autoHide", val.toBool());
    } else if (key == "dock.minimizeEffect" || key == "Dock/minimizeEffect") {
        s.setValue("Dock/minimizeEffect", val.toString());
    } else if (key == "sound.doNotDisturb") {
        s.setValue("Sound/doNotDisturb", val.toBool());
    } else if (key == "accessibility.reducedMotion" || key == "Accessibility/reducedMotion") {
        s.setValue("Accessibility/reducedMotion", val.toBool());
    } else if (key == "accessibility.reduceTransparency" || key == "Accessibility/reduceTransparency") {
        s.setValue("Accessibility/reduceTransparency", val.toBool());
    } else if (key == "accessibility.increaseContrast" || key == "Accessibility/increaseContrast") {
        s.setValue("Accessibility/increaseContrast", val.toBool());
    } else if (key == "sound.volume") {
        s.setValue("Sound/volume", val.toInt());
    } else if (key == "network.wifi.enabled") {
        s.setValue("Network/wifi_enabled", val.toBool());
    } else if (key == "bluetooth.enabled") {
        s.setValue("Bluetooth/enabled", val.toBool());
    } else {
        s.setValue(key, val);
    }
    s.sync();
    Q_EMIT SettingChanged(key, val);
}

QDBusVariant ShellState::GetSetting(const QString &key) const
{
    if (key == "appearance.mode" || key == "Appearance/mode") return QDBusVariant(m_isDark ? "dark" : "light");
    if (key == "appearance.accent" || key == "Appearance/accent") return QDBusVariant(m_accentColor);
    if (key == "dock.size" || key == "Dock/size") return QDBusVariant(m_dockTileSize);
    if (key == "dock.magnification") return QDBusVariant(m_dockMagnification);
    if (key == "dock.magnificationScale") return QDBusVariant(m_dockScaleMax);
    if (key == "dock.autoHide" || key == "Dock/autoHide") return QDBusVariant(m_dockAutoHide);
    if (key == "dock.minimizeEffect" || key == "Dock/minimizeEffect") return QDBusVariant(m_minimizeEffect);
    if (key == "sound.volume") return QDBusVariant(m_volume);
    if (key == "network.wifi.enabled") return QDBusVariant(m_wifiEnabled);
    if (key == "bluetooth.enabled") return QDBusVariant(m_bluetoothEnabled);
    if (key == "displays.scale") return QDBusVariant(1.0);
    if (key == "sound.doNotDisturb") return QDBusVariant(m_doNotDisturb);
    if (key == "accessibility.reducedMotion" || key == "Accessibility/reducedMotion") return QDBusVariant(m_reducedMotion);
    if (key == "accessibility.reduceTransparency" || key == "Accessibility/reduceTransparency") return QDBusVariant(m_reduceTransparency);
    if (key == "accessibility.increaseContrast" || key == "Accessibility/increaseContrast") return QDBusVariant(m_increaseContrast);

    QString path = settingsFilePath();
    QSettings s(path, QSettings::IniFormat);
    return QDBusVariant(s.value(key));
}

bool ShellState::SetSetting(const QString &key, const QDBusVariant &dbusValue)
{
    QVariant value = dbusValue.variant();
    if (key == "appearance.mode" || key == "Appearance/mode") {
        QString mode = value.toString().toLower();
        if (mode != "dark" && mode != "light") return false;
        setIsDark(mode == "dark");
        return true;
    }
    if (key == "appearance.accent" || key == "Appearance/accent") {
        setAccentColor(value.toString().toLower());
        return true;
    }
    if (key == "dock.size" || key == "Dock/size") {
        bool ok = false;
        int sz = value.toInt(&ok);
        if (!ok || sz < 16 || sz > 128) return false;
        setDockTileSize(sz);
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
    if (key == "dock.autoHide" || key == "Dock/autoHide") {
        setDockAutoHide(value.toBool());
        return true;
    }
    if (key == "dock.minimizeEffect" || key == "Dock/minimizeEffect") {
        setMinimizeEffect(value.toString().toLower());
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
    if (key == "accessibility.reducedMotion" || key == "Accessibility/reducedMotion") {
        if (!value.canConvert<bool>()) return false;
        setReducedMotion(value.toBool());
        return true;
    }
    if (key == "accessibility.reduceTransparency" || key == "Accessibility/reduceTransparency") {
        if (!value.canConvert<bool>()) return false;
        setReduceTransparency(value.toBool());
        return true;
    }
    if (key == "accessibility.increaseContrast" || key == "Accessibility/increaseContrast") {
        if (!value.canConvert<bool>()) return false;
        setIncreaseContrast(value.toBool());
        return true;
    }

    saveSetting(key, value);
    return true;
}

QVariantMap ShellState::GetAllSettings() const
{
    QVariantMap map;
    map["appearance.mode"] = m_isDark ? "dark" : "light";
    map["appearance.accent"] = m_accentColor;
    map["dock.size"] = m_dockTileSize;
    map["dock.magnification"] = m_dockMagnification;
    map["dock.magnificationScale"] = m_dockScaleMax;
    map["dock.autoHide"] = m_dockAutoHide;
    map["dock.minimizeEffect"] = m_minimizeEffect;
    map["sound.volume"] = m_volume;
    map["network.wifi.enabled"] = m_wifiEnabled;
    map["bluetooth.enabled"] = m_bluetoothEnabled;
    map["displays.scale"] = 1.0;
    map["sound.doNotDisturb"] = m_doNotDisturb;
    map["accessibility.reducedMotion"] = m_reducedMotion;
    map["accessibility.reduceTransparency"] = m_reduceTransparency;
    map["accessibility.increaseContrast"] = m_increaseContrast;
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
    m_knownApps.clear();

    auto regBuiltin = [&](const QString &id, const QString &name, const QString &icon,
                          const QString &exec, const QString &cat) {
        RegisteredAppInfo info;
        info.id = id;
        info.name = name;
        info.icon = icon;
        info.executablePath = exec;
        info.category = cat;
        m_knownApps.insert(id, info);
    };

    regBuiltin("org.conjunction.files", "Files", "folder", "/usr/bin/conjunction-files", "Utilities");
    regBuiltin("org.conjunction.terminal", "Terminal", "terminal", "/usr/bin/conjunction-terminal", "Development");
    regBuiltin("org.conjunction.settings", "System Settings", "settings", "/usr/bin/conjunction-settings", "System");
    regBuiltin("dev.conjunction.gallery", "Conjunction Gallery", "gallery", "/usr/bin/conjunction-design-gallery", "Development");
    regBuiltin("dev.conjunction.reference", "Desktop Reference", "desktop", "/usr/bin/conjunction-reference-app", "Utilities");

    // Scan .app bundles directly across /Applications, /var/Applications, ~/Applications
    const QStringList bundleRoots = {
        QStringLiteral("/Applications"),
        QStringLiteral("/var/Applications"),
        QDir::homePath() + QStringLiteral("/Applications")
    };
    auto parseTomlString = [](const QString &text, const QString &key) -> QString {
        QRegularExpression rx(QStringLiteral("^\\s*%1\\s*=\\s*\"([^\"]*)\"").arg(QRegularExpression::escape(key)),
                              QRegularExpression::MultilineOption);
        auto m = rx.match(text);
        return m.hasMatch() ? m.captured(1).trimmed() : QString();
    };

    for (const QString &rootPath : bundleRoots) {
        QDir root(rootPath);
        if (!root.exists()) continue;
        const QFileInfoList entries = root.entryInfoList(QStringList() << "*.app", QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QFileInfo &fi : entries) {
            const QString infoPath = fi.absoluteFilePath() + QStringLiteral("/Contents/Info.toml");
            QFile tf(infoPath);
            QString content;
            if (tf.open(QIODevice::ReadOnly | QIODevice::Text)) {
                content = QString::fromUtf8(tf.readAll());
            }
            RegisteredAppInfo app;
            app.isBundle = true;
            app.bundlePath = fi.absoluteFilePath();
            app.id = parseTomlString(content, "id");
            if (app.id.isEmpty()) app.id = fi.completeBaseName();
            app.name = parseTomlString(content, "name");
            if (app.name.isEmpty()) app.name = fi.completeBaseName();
            app.icon = parseTomlString(content, "icon");
            if (app.icon.isEmpty()) {
                app.icon = QStringLiteral("applications");
            } else if (!app.icon.startsWith('/') && QFile::exists(fi.absoluteFilePath() + "/Contents/Resources/" + app.icon)) {
                app.icon = fi.absoluteFilePath() + "/Contents/Resources/" + app.icon;
            }
            app.executablePath = parseTomlString(content, "executable");
            if (app.executablePath.isEmpty()) app.executablePath = fi.absoluteFilePath();
            app.category = parseTomlString(content, "category");
            if (app.category.isEmpty()) app.category = QStringLiteral("Utilities");
            m_knownApps.insert(app.id, app);
        }
    }

    // Scan XDG .desktop entries generated by conj-appd or installed on Fedora
    const QStringList xdgDirs = {
        QDir::homePath() + QStringLiteral("/.local/share/conjunction/xdg/applications"),
        QDir::homePath() + QStringLiteral("/.local/share/applications"),
        QStringLiteral("/usr/share/applications")
    };
    for (const QString &dirPath : xdgDirs) {
        QDir d(dirPath);
        if (!d.exists()) continue;
        const QFileInfoList desks = d.entryInfoList(QStringList() << "*.desktop", QDir::Files);
        for (const QFileInfo &fi : desks) {
            if (fi.completeBaseName() == QStringLiteral("conjunction-files-helper")) continue;
            QFile df(fi.absoluteFilePath());
            if (!df.open(QIODevice::ReadOnly | QIODevice::Text)) continue;
            QString txt = QString::fromUtf8(df.readAll());
            if (txt.contains(QStringLiteral("NoDisplay=true"))) continue;
            auto getField = [&](const QString &k) -> QString {
                QRegularExpression rx(QStringLiteral("^%1=(.+)$").arg(k), QRegularExpression::MultilineOption);
                auto m = rx.match(txt);
                return m.hasMatch() ? m.captured(1).trimmed() : QString();
            };
            QString id = fi.completeBaseName();
            if (m_knownApps.contains(id)) continue;
            RegisteredAppInfo app;
            app.id = id;
            app.name = getField("Name");
            if (app.name.isEmpty()) app.name = id;
            app.icon = getField("Icon");
            if (app.icon.isEmpty()) app.icon = QStringLiteral("applications");
            app.executablePath = getField("Exec").split(' ').first();
            QString cats = getField("Categories");
            if (cats.contains("Network")) app.category = "Internet";
            else if (cats.contains("Development")) app.category = "Development";
            else if (cats.contains("System") || cats.contains("Settings")) app.category = "System";
            else app.category = "Utilities";
            m_knownApps.insert(id, app);
        }
    }

    // Merge registered bundles from conj-appctl list --json if daemon/registry exists
    QProcess proc;
    proc.start("conj-appctl", QStringList() << "list" << "--json");
    if (proc.waitForFinished(450)) {
        const QByteArray raw = proc.readAllStandardOutput();
        QJsonDocument jdoc = QJsonDocument::fromJson(raw);
        if (jdoc.isArray()) {
            for (const auto &v : jdoc.array()) {
                const QJsonObject o = v.toObject();
                const QString id = o.value("id").toString();
                if (id.isEmpty()) continue;
                RegisteredAppInfo app = m_knownApps.value(id);
                app.id = id;
                if (!o.value("name").toString().isEmpty()) app.name = o.value("name").toString();
                if (!o.value("bundle_path").toString().isEmpty()) {
                    app.bundlePath = o.value("bundle_path").toString();
                    app.isBundle = true;
                }
                if (app.icon.isEmpty()) app.icon = QStringLiteral("applications");
                if (app.category.isEmpty()) app.category = QStringLiteral("Utilities");
                m_knownApps.insert(id, app);
            }
        }
    }

    QVariantList catalog;
    for (auto it = m_knownApps.constBegin(); it != m_knownApps.constEnd(); ++it) {
        const auto &a = it.value();
        QVariantMap row;
        row["id"] = a.id;
        row["name"] = a.name;
        row["icon"] = a.icon;
        row["category"] = a.category;
        row["isBundle"] = a.isBundle;
        row["bundlePath"] = a.bundlePath;
        row["executable"] = a.executablePath;
        catalog.append(row);
    }
    m_appCatalog = catalog;
    Q_EMIT appCatalogChanged();
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

    m_minimizedWindows.clear();
    QVariantList mins;
    for (const auto &w : allWindows) {
        if (w.minimized) {
            RegisteredAppInfo app = resolveApp(w);
            QVariantMap mw;
            mw["internalId"] = w.internalId;
            mw["title"] = w.title;
            mw["appId"] = app.id;
            mw["appName"] = app.name;
            mw["icon"] = app.icon;
            mins.append(mw);
        }
    }
    m_minimizedWindows = mins;
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
        m_activeAppName = "Files";
        m_activeAppId = "org.conjunction.files";
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
    if (m_knownApps.contains(appId)) {
        const auto &info = m_knownApps[appId];
        if (info.isBundle && !info.bundlePath.isEmpty()) {
            launchBundle(info.bundlePath);
            return;
        }
        if (!info.executablePath.isEmpty() && QFile::exists(info.executablePath)) {
            QProcess::startDetached(info.executablePath, QStringList());
            return;
        }
    }
    if (!QProcess::startDetached("conj-open", QStringList() << appId)) {
        QProcess::startDetached(appId, QStringList());
    }
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

    // 1. Search Applications (.app bundles + XDG + built-ins)
    for (auto it = m_knownApps.constBegin(); it != m_knownApps.constEnd(); ++it) {
        const auto &app = it.value();
        if (app.name.toLower().contains(q) || app.id.toLower().contains(q)
            || app.packageName.toLower().contains(q) || app.bundlePath.toLower().contains(q)) {
            QVariantMap item;
            item["id"] = app.id;
            item["title"] = app.name;
            item["subtitle"] = app.isBundle
                ? (QStringLiteral("App Bundle • ") + app.bundlePath)
                : (QStringLiteral("Application • ") + app.id);
            item["category"] = "Apps";
            item["icon"] = app.icon;
            item["previewDetail"] = app.isBundle
                ? QStringLiteral("Bundle: %1\nID: %2\nCategory: %3\nExecutable: %4").arg(app.bundlePath, app.id, app.category, app.executablePath)
                : QStringLiteral("Application ID: %1\nExecutable: %2").arg(app.id, app.executablePath);
            item["actionData"] = app.isBundle ? ("bundle:" + app.bundlePath) : ("app:" + app.id);
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

    if (actionData.startsWith("bundle:")) {
        launchBundle(actionData.mid(7));
    } else if (actionData.startsWith("app:")) {
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
        openPath(path);
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

    QString kwinrcPath = configDir + "/kwinrc";
    QSettings kwin(kwinrcPath, QSettings::IniFormat);
    kwin.beginGroup("Windows");
    kwin.setValue("AnimationSpeed", m_reducedMotion ? 0 : 3);
    kwin.endGroup();
    kwin.beginGroup("Effect-conjunctionmotion");
    kwin.setValue("MinimizeEffect", m_minimizeEffect);
    kwin.setValue("ReduceMotion", m_reducedMotion);
    kwin.endGroup();
    kwin.sync();
}

QVariantList ShellState::minimizedWindows() const { return m_minimizedWindows; }
QVariantList ShellState::mountedVolumes() const { return m_mountedVolumes; }
QVariantList ShellState::appCatalog() const { return m_appCatalog; }

QString ShellState::accentColor() const { return m_accentColor; }
void ShellState::setAccentColor(const QString &accent)
{
    if (m_accentColor != accent && !accent.isEmpty()) {
        m_accentColor = accent;
        saveSetting("appearance.accent", accent);
        Q_EMIT accentColorChanged();
    }
}

bool ShellState::notchBar() const { return m_notchBar; }
void ShellState::setNotchBar(bool notch)
{
    if (m_notchBar != notch) {
        m_notchBar = notch;
        Q_EMIT notchBarChanged();
    }
}

bool ShellState::quickLookVisible() const { return m_quickLookVisible; }
void ShellState::setQuickLookVisible(bool visible)
{
    if (m_quickLookVisible != visible) {
        m_quickLookVisible = visible;
        Q_EMIT quickLookChanged();
    }
}
QString ShellState::quickLookTitle() const { return m_quickLookTitle; }
QString ShellState::quickLookSubtitle() const { return m_quickLookSubtitle; }
QString ShellState::quickLookBody() const { return m_quickLookBody; }
QString ShellState::quickLookIcon() const { return m_quickLookIcon; }

void ShellState::openQuickLook(int index)
{
    if (index < 0 || index >= m_searchResults.size()) return;
    QVariantMap item = m_searchResults[index].toMap();
    m_quickLookTitle = item.value("title").toString();
    m_quickLookSubtitle = item.value("subtitle").toString();
    m_quickLookIcon = item.value("icon").toString();
    QString detail = item.value("previewDetail").toString();
    if (detail.isEmpty() && item.value("actionData").toString().startsWith("file:")) {
        QString fp = item.value("actionData").toString().mid(5);
        QFileInfo fi(fp);
        detail = QStringLiteral("Path: %1\nSize: %2 bytes\nModified: %3")
                     .arg(fp)
                     .arg(fi.size())
                     .arg(fi.lastModified().toString(Qt::ISODate));
        if (fi.size() > 0 && fi.size() < 65536) {
            QFile f(fp);
            if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
                detail += QStringLiteral("\n\n") + QString::fromUtf8(f.read(600));
            }
        }
    }
    m_quickLookBody = detail.isEmpty() ? m_quickLookSubtitle : detail;
    m_quickLookVisible = true;
    Q_EMIT quickLookChanged();
}

void ShellState::closeQuickLook()
{
    setQuickLookVisible(false);
}

bool ShellState::appLauncherVisible() const { return m_appLauncherVisible; }
void ShellState::setAppLauncherVisible(bool visible)
{
    if (m_appLauncherVisible != visible) {
        m_appLauncherVisible = visible;
        if (visible) {
            setControlCenterVisible(false);
            setNotificationCenterVisible(false);
            setSpotlightVisible(false);
            reloadKnownApps();
        }
        Q_EMIT appLauncherVisibleChanged();
    }
}
void ShellState::toggleAppLauncher()
{
    setAppLauncherVisible(!m_appLauncherVisible);
}

bool ShellState::quickNoteVisible() const { return m_quickNoteVisible; }
void ShellState::setQuickNoteVisible(bool visible)
{
    if (m_quickNoteVisible != visible) {
        m_quickNoteVisible = visible;
        Q_EMIT quickNoteVisibleChanged();
    }
}
void ShellState::toggleQuickNote() { setQuickNoteVisible(!m_quickNoteVisible); }
void ShellState::triggerQuickNote() { setQuickNoteVisible(true); }

QString ShellState::quickNoteText() const { return m_quickNoteText; }
void ShellState::setQuickNoteText(const QString &text)
{
    if (m_quickNoteText != text) {
        m_quickNoteText = text;
        saveQuickNote();
        Q_EMIT quickNoteTextChanged();
    }
}

void ShellState::loadQuickNote()
{
    const QString path = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
                         + QStringLiteral("/conjunction/quicknote.md");
    QFile f(path);
    if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        m_quickNoteText = QString::fromUtf8(f.readAll());
    } else {
        m_quickNoteText = QStringLiteral("Quick Note\n- Press Bottom-Right hot corner to toggle\n");
    }
}

void ShellState::saveQuickNote()
{
    const QString path = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
                         + QStringLiteral("/conjunction/quicknote.md");
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile f(path);
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        f.write(m_quickNoteText.toUtf8());
    }
}

bool ShellState::appSwitcherVisible() const { return m_appSwitcherVisible; }
void ShellState::setAppSwitcherVisible(bool visible)
{
    if (m_appSwitcherVisible != visible) {
        m_appSwitcherVisible = visible;
        Q_EMIT appSwitcherChanged();
    }
}
int ShellState::appSwitcherIndex() const { return m_appSwitcherIndex; }
void ShellState::setAppSwitcherIndex(int idx)
{
    if (m_appSwitcherIndex != idx) {
        m_appSwitcherIndex = idx;
        Q_EMIT appSwitcherChanged();
    }
}
void ShellState::showAppSwitcher(bool reverse)
{
    const int count = qMax(1, int(m_dockItems.size()));
    if (!m_appSwitcherVisible) {
        m_appSwitcherIndex = (count > 1) ? 1 : 0;
        m_appSwitcherVisible = true;
    } else {
        m_appSwitcherIndex = (m_appSwitcherIndex + (reverse ? -1 : 1) + count) % count;
    }
    Q_EMIT appSwitcherChanged();
}
void ShellState::commitAppSwitcher()
{
    if (m_appSwitcherIndex >= 0 && m_appSwitcherIndex < m_dockItems.size()) {
        QString id = m_dockItems[m_appSwitcherIndex].toMap().value("id").toString();
        focusApp(id);
    }
    setAppSwitcherVisible(false);
}
void ShellState::dismissAppSwitcher() { setAppSwitcherVisible(false); }

bool ShellState::nearbyShareEnabled() const { return m_nearbyShareEnabled; }
void ShellState::setNearbyShareEnabled(bool enabled)
{
    if (m_nearbyShareEnabled != enabled) {
        m_nearbyShareEnabled = enabled;
        Q_EMIT nearbyShareChanged();
    }
}
void ShellState::toggleNearbyShare() { setNearbyShareEnabled(!m_nearbyShareEnabled); }

bool ShellState::stageManagerEnabled() const { return m_stageManagerEnabled; }
void ShellState::setStageManagerEnabled(bool enabled)
{
    if (m_stageManagerEnabled != enabled) {
        m_stageManagerEnabled = enabled;
        Q_EMIT stageManagerChanged();
    }
}
void ShellState::toggleStageManager() { setStageManagerEnabled(!m_stageManagerEnabled); }

bool ShellState::nightShiftEnabled() const { return m_nightShiftEnabled; }
void ShellState::setNightShiftEnabled(bool enabled)
{
    if (m_nightShiftEnabled != enabled) {
        m_nightShiftEnabled = enabled;
        Q_EMIT nightShiftChanged();
    }
}
void ShellState::toggleNightShift() { setNightShiftEnabled(!m_nightShiftEnabled); }

int ShellState::dockTileSize() const { return m_dockTileSize; }
void ShellState::setDockTileSize(int size)
{
    size = qBound(16, size, 128);
    if (m_dockTileSize != size) {
        m_dockTileSize = size;
        saveSetting("dock.size", size);
        Q_EMIT dockTileSizeChanged();
    }
}

bool ShellState::dockAutoHide() const { return m_dockAutoHide; }
void ShellState::setDockAutoHide(bool autoHide)
{
    if (m_dockAutoHide != autoHide) {
        m_dockAutoHide = autoHide;
        saveSetting("dock.autoHide", autoHide);
        Q_EMIT dockAutoHideChanged();
    }
}

QString ShellState::minimizeEffect() const { return m_minimizeEffect; }
void ShellState::setMinimizeEffect(const QString &effect)
{
    QString clean = (effect == "scale") ? QStringLiteral("scale") : QStringLiteral("genie");
    if (m_minimizeEffect != clean) {
        m_minimizeEffect = clean;
        saveSetting("dock.minimizeEffect", clean);
        syncPortalAppearance();
        Q_EMIT minimizeEffectChanged();
    }
}

bool ShellState::isDraggingDockItem() const { return m_isDraggingDockItem; }
QString ShellState::draggingItemType() const { return m_draggingItemType; }
QString ShellState::draggingItemId() const { return m_draggingItemId; }
void ShellState::setDraggingDockItem(bool dragging, const QString &type, const QString &id)
{
    m_isDraggingDockItem = dragging;
    m_draggingItemType = type;
    m_draggingItemId = id;
    Q_EMIT draggingDockItemChanged();
}

bool ShellState::reduceTransparency() const { return m_reduceTransparency; }
void ShellState::setReduceTransparency(bool rt)
{
    if (m_reduceTransparency != rt) {
        m_reduceTransparency = rt;
        saveSetting("accessibility.reduceTransparency", rt);
        Q_EMIT reduceTransparencyChanged();
    }
}

bool ShellState::increaseContrast() const { return m_increaseContrast; }
void ShellState::setIncreaseContrast(bool ic)
{
    if (m_increaseContrast != ic) {
        m_increaseContrast = ic;
        saveSetting("accessibility.increaseContrast", ic);
        Q_EMIT increaseContrastChanged();
    }
}

bool ShellState::layerShellMode() const { return m_layerShellMode; }
void ShellState::setLayerShellMode(bool enabled)
{
    if (m_layerShellMode != enabled) {
        m_layerShellMode = enabled;
        Q_EMIT layerShellModeChanged();
    }
}

void ShellState::bindLayerShell(QObject *windowObj, const QString &role, int exclusiveZone)
{
#ifdef HAVE_LAYERSHELLQT
    auto *w = qobject_cast<QWindow *>(windowObj);
    if (!w || !m_layerShellMode) return;
    auto *ls = LayerShellQt::Window::get(w);
    if (!ls) return;
    if (role == QStringLiteral("topbar")) {
        ls->setAnchors(LayerShellQt::Window::Anchors(LayerShellQt::Window::AnchorTop | LayerShellQt::Window::AnchorLeft | LayerShellQt::Window::AnchorRight));
        ls->setLayer(LayerShellQt::Window::LayerTop);
        ls->setExclusiveZone(exclusiveZone > 0 ? exclusiveZone : (m_notchBar ? 39 : 28));
        ls->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityOnDemand);
        ls->setScope(QStringLiteral("conjunction-topbar"));
    } else if (role == QStringLiteral("dock")) {
        ls->setAnchors(LayerShellQt::Window::AnchorBottom);
        ls->setLayer(LayerShellQt::Window::LayerTop);
        ls->setExclusiveZone(exclusiveZone);
        ls->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
        ls->setScope(QStringLiteral("conjunction-dock"));
    } else {
        ls->setAnchors(LayerShellQt::Window::Anchors(LayerShellQt::Window::AnchorTop | LayerShellQt::Window::AnchorBottom | LayerShellQt::Window::AnchorLeft | LayerShellQt::Window::AnchorRight));
        ls->setLayer(LayerShellQt::Window::LayerOverlay);
        ls->setExclusiveZone(-1);
        ls->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityOnDemand);
        ls->setScope(QStringLiteral("conjunction-overlay"));
    }
#else
    Q_UNUSED(windowObj)
    Q_UNUSED(role)
    Q_UNUSED(exclusiveZone)
#endif
}

void ShellState::launchBundle(const QString &bundlePath)
{
    qInfo() << "[ShellState] Launching bundle via conj-open:" << bundlePath;
    if (!QProcess::startDetached("conj-open", QStringList() << bundlePath)) {
        openPath(bundlePath);
    }
}

void ShellState::minimizeWindow(const QString &windowId)
{
    m_winMgr->minimizeWindow(windowId);
}

void ShellState::unminimizeWindow(const QString &windowId)
{
    m_winMgr->unminimizeWindow(windowId);
}

void ShellState::refreshMountedVolumes()
{
    QVariantList vols;
    for (const QStorageInfo &st : QStorageInfo::mountedVolumes()) {
        if (!st.isValid() || !st.isReady()) continue;
        const QString mp = st.rootPath();
        if (mp.startsWith("/run/media") || mp.startsWith("/media") || mp.startsWith("/mnt/conj-cdmg")) {
            QVariantMap v;
            v["name"] = !st.name().isEmpty() ? st.name() : QFileInfo(mp).fileName();
            v["mountPoint"] = mp;
            v["device"] = QString::fromUtf8(st.device());
            vols.append(v);
        }
    }
    m_mountedVolumes = vols;
    Q_EMIT mountedVolumesChanged();
}

void ShellState::ejectVolume(const QString &mountPoint)
{
    if (!QProcess::startDetached("conj-open", QStringList() << "--eject" << mountPoint)) {
        QProcess::startDetached("umount", QStringList() << mountPoint);
    }
    for (int i = 0; i < m_mountedVolumes.size(); ++i) {
        if (m_mountedVolumes[i].toMap().value("mountPoint").toString() == mountPoint) {
            m_mountedVolumes.removeAt(i);
            Q_EMIT mountedVolumesChanged();
            break;
        }
    }
}

void ShellState::openPath(const QString &path)
{
    if (!QProcess::startDetached("conj-open", QStringList() << path)) {
        QProcess::startDetached("conjunction-files", QStringList() << path);
    }
}

void ShellState::simulateMinimizedWindow(const QString &winId, const QString &title, const QString &appId)
{
    m_winMgr->WindowMinimizedChanged(winId, title, appId, true);
}

void ShellState::simulateMountedVolume(const QString &name, const QString &mountPoint)
{
    QVariantMap v;
    v["name"] = name;
    v["mountPoint"] = mountPoint;
    v["device"] = QStringLiteral("/dev/loop0");
    m_mountedVolumes.append(v);
    Q_EMIT mountedVolumesChanged();
}
