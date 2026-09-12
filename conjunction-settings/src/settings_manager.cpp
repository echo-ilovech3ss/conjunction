#include "settings_manager.h"
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QUrl>
#include <QUrlQuery>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusInterface>
#include <QDebug>

static QString settingsFilePath()
{
    QString configDir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
    return configDir + "/conjunction/settings.ini";
}

SettingsManager::SettingsManager(QObject *parent)
    : QObject(parent)
{
    loadSettings();

    // Listen for live setting changes broadcast over D-Bus from Shell or Control Center
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (bus.isConnected()) {
        bus.connect(
            "org.conjunction.Settings",
            "/org/conjunction/Settings",
            "org.conjunction.Settings",
            "SettingChanged",
            this,
            SLOT(onDBusSettingChanged(QString, QVariant))
        );
    }
}

SettingsManager::~SettingsManager() = default;

void SettingsManager::loadSettings()
{
    QString path = settingsFilePath();
    QSettings s(path, QSettings::IniFormat);

    m_appearanceMode = s.value("Appearance/mode", "dark").toString();
    m_appearanceAccent = s.value("Appearance/accent", "#0066CC").toString();

    m_dockSize = s.value("Dock/size", 68).toInt();
    m_dockMagnification = s.value("Dock/magnification", true).toBool();
    m_dockMagnificationScale = s.value("Dock/magnification_scale", 1.35).toReal();
    m_dockDisplayPolicy = s.value("Dock/display_policy", "primary").toString();

    m_displayScale = s.value("Displays/scale", 1.0).toReal();
    m_soundVolume = s.value("Sound/volume", 75).toInt();
    m_soundMuted = s.value("Sound/muted", false).toBool();
    m_wifiEnabled = s.value("Network/wifi_enabled", true).toBool();
    m_bluetoothEnabled = s.value("Bluetooth/enabled", true).toBool();
    m_desktopWallpaper = s.value("Desktop/wallpaper", "default.jpg").toString();
}

void SettingsManager::writeSetting(const QString &key, const QVariant &value)
{
    // 1. Authoritative local file persistence
    QString path = settingsFilePath();
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSettings s(path, QSettings::IniFormat);

    if (key == "appearance.mode") s.setValue("Appearance/mode", value.toString());
    else if (key == "appearance.accent") s.setValue("Appearance/accent", value.toString());
    else if (key == "dock.size") s.setValue("Dock/size", value.toInt());
    else if (key == "dock.magnification") s.setValue("Dock/magnification", value.toBool());
    else if (key == "dock.magnificationScale") s.setValue("Dock/magnification_scale", value.toReal());
    else if (key == "dock.displayPolicy") s.setValue("Dock/display_policy", value.toString());
    else if (key == "displays.scale") s.setValue("Displays/scale", value.toReal());
    else if (key == "sound.volume") s.setValue("Sound/volume", value.toInt());
    else if (key == "sound.muted") s.setValue("Sound/muted", value.toBool());
    else if (key == "network.wifi.enabled") s.setValue("Network/wifi_enabled", value.toBool());
    else if (key == "bluetooth.enabled") s.setValue("Bluetooth/enabled", value.toBool());
    else if (key == "desktop.wallpaper") s.setValue("Desktop/wallpaper", value.toString());
    s.sync();

    // 2. Synchronize via D-Bus to conj-shelld if available
    QDBusInterface shellSettings(
        "org.conjunction.Settings",
        "/org/conjunction/Settings",
        "org.conjunction.Settings",
        QDBusConnection::sessionBus()
    );
    if (shellSettings.isValid()) {
        shellSettings.call("SetSetting", key, value);
    }
}

void SettingsManager::onDBusSettingChanged(const QString &key, const QVariant &value)
{
    if (key == "appearance.mode") {
        QString m = value.toString();
        if (m_appearanceMode != m) {
            m_appearanceMode = m;
            Q_EMIT appearanceModeChanged();
        }
    } else if (key == "appearance.accent") {
        QString a = value.toString();
        if (m_appearanceAccent != a) {
            m_appearanceAccent = a;
            Q_EMIT appearanceAccentChanged();
        }
    } else if (key == "dock.size") {
        int sz = value.toInt();
        if (m_dockSize != sz) {
            m_dockSize = sz;
            Q_EMIT dockSizeChanged();
        }
    } else if (key == "dock.magnification") {
        bool b = value.toBool();
        if (m_dockMagnification != b) {
            m_dockMagnification = b;
            Q_EMIT dockMagnificationChanged();
        }
    } else if (key == "dock.magnificationScale") {
        qreal sc = value.toReal();
        if (!qFuzzyCompare(m_dockMagnificationScale, sc)) {
            m_dockMagnificationScale = sc;
            Q_EMIT dockMagnificationScaleChanged();
        }
    } else if (key == "dock.displayPolicy") {
        QString p = value.toString();
        if (m_dockDisplayPolicy != p) {
            m_dockDisplayPolicy = p;
            Q_EMIT dockDisplayPolicyChanged();
        }
    } else if (key == "displays.scale") {
        qreal sc = value.toReal();
        if (!qFuzzyCompare(m_displayScale, sc)) {
            m_displayScale = sc;
            Q_EMIT displayScaleChanged();
        }
    } else if (key == "sound.volume") {
        int v = value.toInt();
        if (m_soundVolume != v) {
            m_soundVolume = v;
            Q_EMIT soundVolumeChanged();
        }
    } else if (key == "sound.muted") {
        bool m = value.toBool();
        if (m_soundMuted != m) {
            m_soundMuted = m;
            Q_EMIT soundMutedChanged();
        }
    } else if (key == "network.wifi.enabled") {
        bool b = value.toBool();
        if (m_wifiEnabled != b) {
            m_wifiEnabled = b;
            Q_EMIT wifiEnabledChanged();
        }
    } else if (key == "bluetooth.enabled") {
        bool b = value.toBool();
        if (m_bluetoothEnabled != b) {
            m_bluetoothEnabled = b;
            Q_EMIT bluetoothEnabledChanged();
        }
    }
}

QString SettingsManager::appearanceMode() const { return m_appearanceMode; }
void SettingsManager::setAppearanceMode(const QString &mode)
{
    QString m = mode.toLower();
    if (m != "dark" && m != "light") return;
    if (m_appearanceMode != m) {
        m_appearanceMode = m;
        writeSetting("appearance.mode", m);
        Q_EMIT appearanceModeChanged();
    }
}

QString SettingsManager::appearanceAccent() const { return m_appearanceAccent; }
void SettingsManager::setAppearanceAccent(const QString &accent)
{
    if (m_appearanceAccent != accent) {
        m_appearanceAccent = accent;
        writeSetting("appearance.accent", accent);
        Q_EMIT appearanceAccentChanged();
    }
}

int SettingsManager::dockSize() const { return m_dockSize; }
void SettingsManager::setDockSize(int size)
{
    size = qBound(36, size, 96);
    if (m_dockSize != size) {
        m_dockSize = size;
        writeSetting("dock.size", size);
        Q_EMIT dockSizeChanged();
    }
}

bool SettingsManager::dockMagnification() const { return m_dockMagnification; }
void SettingsManager::setDockMagnification(bool enabled)
{
    if (m_dockMagnification != enabled) {
        m_dockMagnification = enabled;
        writeSetting("dock.magnification", enabled);
        Q_EMIT dockMagnificationChanged();
    }
}

qreal SettingsManager::dockMagnificationScale() const { return m_dockMagnificationScale; }
void SettingsManager::setDockMagnificationScale(qreal scale)
{
    scale = qBound(1.1, scale, 2.0);
    if (!qFuzzyCompare(m_dockMagnificationScale, scale)) {
        m_dockMagnificationScale = scale;
        writeSetting("dock.magnificationScale", scale);
        Q_EMIT dockMagnificationScaleChanged();
    }
}

QString SettingsManager::dockDisplayPolicy() const { return m_dockDisplayPolicy; }
void SettingsManager::setDockDisplayPolicy(const QString &policy)
{
    if (m_dockDisplayPolicy != policy) {
        m_dockDisplayPolicy = policy;
        writeSetting("dock.displayPolicy", policy);
        Q_EMIT dockDisplayPolicyChanged();
    }
}

qreal SettingsManager::displayScale() const { return m_displayScale; }
void SettingsManager::setDisplayScale(qreal scale)
{
    scale = qBound(1.0, scale, 2.5);
    if (!qFuzzyCompare(m_displayScale, scale)) {
        m_displayScale = scale;
        writeSetting("displays.scale", scale);
        Q_EMIT displayScaleChanged();
    }
}

int SettingsManager::soundVolume() const { return m_soundVolume; }
void SettingsManager::setSoundVolume(int vol)
{
    vol = qBound(0, vol, 100);
    if (m_soundVolume != vol) {
        m_soundVolume = vol;
        writeSetting("sound.volume", vol);
        Q_EMIT soundVolumeChanged();
    }
}

bool SettingsManager::soundMuted() const { return m_soundMuted; }
void SettingsManager::setSoundMuted(bool muted)
{
    if (m_soundMuted != muted) {
        m_soundMuted = muted;
        writeSetting("sound.muted", muted);
        Q_EMIT soundMutedChanged();
    }
}

bool SettingsManager::wifiEnabled() const { return m_wifiEnabled; }
void SettingsManager::setWifiEnabled(bool enabled)
{
    if (m_wifiEnabled != enabled) {
        m_wifiEnabled = enabled;
        writeSetting("network.wifi.enabled", enabled);
        Q_EMIT wifiEnabledChanged();
    }
}

bool SettingsManager::bluetoothEnabled() const { return m_bluetoothEnabled; }
void SettingsManager::setBluetoothEnabled(bool enabled)
{
    if (m_bluetoothEnabled != enabled) {
        m_bluetoothEnabled = enabled;
        writeSetting("bluetooth.enabled", enabled);
        Q_EMIT bluetoothEnabledChanged();
    }
}

QString SettingsManager::desktopWallpaper() const { return m_desktopWallpaper; }
void SettingsManager::setDesktopWallpaper(const QString &wallpaper)
{
    if (m_desktopWallpaper != wallpaper) {
        m_desktopWallpaper = wallpaper;
        writeSetting("desktop.wallpaper", wallpaper);
        Q_EMIT desktopWallpaperChanged();
    }
}

QString SettingsManager::activePage() const { return m_activePage; }
void SettingsManager::setActivePage(const QString &page)
{
    if (m_activePage != page) {
        m_activePage = page;
        Q_EMIT activePageChanged();
    }
}

QString SettingsManager::highlightedSetting() const { return m_highlightedSetting; }
void SettingsManager::setHighlightedSetting(const QString &settingId)
{
    if (m_highlightedSetting != settingId) {
        m_highlightedSetting = settingId;
        Q_EMIT highlightedSettingChanged();
    }
}

QString SettingsManager::searchQuery() const { return m_searchQuery; }
void SettingsManager::setSearchQuery(const QString &query)
{
    if (m_searchQuery != query) {
        m_searchQuery = query;
        performSearch(query);
        Q_EMIT searchQueryChanged();
    }
}

QVariantList SettingsManager::searchResults() const { return m_searchResults; }

QVariantList SettingsManager::pages() const
{
    QVariantList list;
    auto addPage = [&](const QString &id, const QString &title, const QString &section, const QString &icon) {
        QVariantMap p;
        p["id"] = id;
        p["title"] = title;
        p["section"] = section;
        p["icon"] = icon;
        list.append(p);
    };

    addPage("about", "General", "System", "help-about");
    addPage("appearance", "Appearance", "Personalization", "preferences-desktop-theme");
    addPage("dock", "Desktop & Dock", "Personalization", "preferences-desktop");
    addPage("displays", "Displays", "Hardware", "video-display");
    addPage("sound", "Sound", "Hardware", "audio-volume-high");
    addPage("network", "Network", "Connectivity", "network-wireless");
    addPage("bluetooth", "Bluetooth", "Connectivity", "bluetooth");

    return list;
}

void SettingsManager::navigateTo(const QString &page, const QString &settingId)
{
    setActivePage(page);
    setHighlightedSetting(settingId);
}

void SettingsManager::handleUrl(const QString &url)
{
    // Parses settings://<page>?setting=<id> or settings://<page>
    QString clean = url.trimmed();
    if (clean.startsWith("settings://")) {
        clean = clean.mid(11);
    } else if (clean.startsWith("settings:")) {
        clean = clean.mid(9);
    }

    QUrl parsed("settings://" + clean);
    QString page = parsed.host().isEmpty() ? parsed.path() : parsed.host();
    if (page.startsWith("/")) page = page.mid(1);

    QUrlQuery query(parsed);
    QString settingId = query.queryItemValue("setting");

    if (page == "search") {
        QString q = query.queryItemValue("q");
        if (q.isEmpty()) q = query.queryItemValue("query");
        if (!q.isEmpty()) {
            setSearchQuery(q);
            return;
        }
    }

    if (page.isEmpty() && !settingId.isEmpty()) {
        // Infer page from settingId
        if (settingId.startsWith("appearance.")) page = "appearance";
        else if (settingId.startsWith("dock.") || settingId.startsWith("desktop.")) page = "dock";
        else if (settingId.startsWith("displays.")) page = "displays";
        else if (settingId.startsWith("sound.")) page = "sound";
        else if (settingId.startsWith("network.")) page = "network";
        else if (settingId.startsWith("bluetooth.")) page = "bluetooth";
        else page = "about";
    }

    if (page.isEmpty()) page = "about";
    navigateTo(page, settingId);
}

void SettingsManager::resetSetting(const QString &key)
{
    if (key == "dock.size") setDockSize(68);
    else if (key == "dock.magnification") setDockMagnification(true);
    else if (key == "dock.magnificationScale") setDockMagnificationScale(1.35);
    else if (key == "displays.scale") setDisplayScale(1.0);
    else if (key == "sound.volume") setSoundVolume(75);
    else if (key == "sound.muted") setSoundMuted(false);
    else if (key == "appearance.mode") setAppearanceMode("dark");
}

void SettingsManager::performSearch(const QString &query)
{
    QString q = query.trimmed().toLower();
    QVariantList results;

    if (q.isEmpty()) {
        m_searchResults = results;
        Q_EMIT searchResultsChanged();
        return;
    }

    struct SettingSearchItem {
        const char *id;
        const char *page;
        const char *section;
        const char *title;
        const char *desc;
        const char *icon;
        const char *kw;
    };

    static const SettingSearchItem catalog[] = {
        {"appearance.mode", "appearance", "Theme", "Appearance Mode", "Switch between Light and Dark desktop themes", "preferences-desktop-theme", "dark light theme mode night color"},
        {"appearance.accent", "appearance", "Theme", "Accent Color", "System highlight and focus tint color", "preferences-desktop-theme", "accent tint highlight color blue"},
        {"dock.magnification", "dock", "Dock", "Dock Magnification", "Magnify Dock icons on pointer hover", "preferences-desktop", "dock magnification zoom hover scale"},
        {"dock.size", "dock", "Dock", "Dock Size", "Base height and icon scale of the desktop Dock", "preferences-desktop", "dock size icons height bar"},
        {"dock.magnificationScale", "dock", "Dock", "Magnification Scale", "Maximum scale multiplier for hovered Dock icons", "preferences-desktop", "dock zoom scale max magnification"},
        {"dock.displayPolicy", "dock", "Dock", "Dock Display Placement", "Which connected displays show the Dock", "preferences-desktop", "dock display monitor placement"},
        {"displays.scale", "displays", "Scale & Resolution", "Display Scale", "User interface scaling factor for displays", "video-display", "screen scale monitor resolution hidpi zoom"},
        {"sound.volume", "sound", "Output", "Output Volume", "Main speaker and headphone output volume", "audio-volume-high", "sound volume speaker audio loudness"},
        {"sound.muted", "sound", "Output", "Mute Sound", "Mute all audio output", "audio-volume-muted", "mute sound silence audio"},
        {"network.wifi.enabled", "network", "Wi-Fi", "Wi-Fi", "Enable or disable wireless networking", "network-wireless", "wifi wireless network internet ssid hotspot"},
        {"bluetooth.enabled", "bluetooth", "Bluetooth Adapter", "Bluetooth", "Enable or disable Bluetooth wireless adapter", "bluetooth", "bluetooth wireless pair devices mouse keyboard"},
        {"desktop.wallpaper", "dock", "Wallpaper", "Desktop Background", "Wallpaper image and desktop style", "preferences-desktop-wallpaper", "wallpaper background desktop picture"},
        {"general.about", "about", "System", "About Conjunction", "OS, kernel, processor, memory, and specs", "help-about", "about system kernel cpu ram specs info version"}
    };

    for (const auto &item : catalog) {
        QString titleStr = QString::fromUtf8(item.title);
        QString descStr = QString::fromUtf8(item.desc);
        QString kwStr = QString::fromUtf8(item.kw);
        QString pageStr = QString::fromUtf8(item.page);

        if (titleStr.toLower().contains(q) || kwStr.contains(q) || descStr.toLower().contains(q) || pageStr.contains(q)) {
            QVariantMap hit;
            hit["id"] = QString::fromUtf8(item.id);
            hit["page"] = pageStr;
            hit["section"] = QString::fromUtf8(item.section);
            hit["title"] = titleStr;
            hit["description"] = descStr;
            hit["icon"] = QString::fromUtf8(item.icon);
            results.append(hit);
        }
    }

    m_searchResults = results;
    Q_EMIT searchResultsChanged();
}
