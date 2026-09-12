#pragma once

#include <QObject>
#include <QString>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>
#include <QSettings>

class SettingsManager : public QObject {
    Q_OBJECT

    Q_PROPERTY(QString appearanceMode READ appearanceMode WRITE setAppearanceMode NOTIFY appearanceModeChanged)
    Q_PROPERTY(QString appearanceAccent READ appearanceAccent WRITE setAppearanceAccent NOTIFY appearanceAccentChanged)
    Q_PROPERTY(int dockSize READ dockSize WRITE setDockSize NOTIFY dockSizeChanged)
    Q_PROPERTY(bool dockMagnification READ dockMagnification WRITE setDockMagnification NOTIFY dockMagnificationChanged)
    Q_PROPERTY(qreal dockMagnificationScale READ dockMagnificationScale WRITE setDockMagnificationScale NOTIFY dockMagnificationScaleChanged)
    Q_PROPERTY(QString dockDisplayPolicy READ dockDisplayPolicy WRITE setDockDisplayPolicy NOTIFY dockDisplayPolicyChanged)
    Q_PROPERTY(qreal displayScale READ displayScale WRITE setDisplayScale NOTIFY displayScaleChanged)
    Q_PROPERTY(int soundVolume READ soundVolume WRITE setSoundVolume NOTIFY soundVolumeChanged)
    Q_PROPERTY(bool soundMuted READ soundMuted WRITE setSoundMuted NOTIFY soundMutedChanged)
    Q_PROPERTY(bool wifiEnabled READ wifiEnabled WRITE setWifiEnabled NOTIFY wifiEnabledChanged)
    Q_PROPERTY(bool bluetoothEnabled READ bluetoothEnabled WRITE setBluetoothEnabled NOTIFY bluetoothEnabledChanged)
    Q_PROPERTY(QString desktopWallpaper READ desktopWallpaper WRITE setDesktopWallpaper NOTIFY desktopWallpaperChanged)

    Q_PROPERTY(QString activePage READ activePage WRITE setActivePage NOTIFY activePageChanged)
    Q_PROPERTY(QString highlightedSetting READ highlightedSetting WRITE setHighlightedSetting NOTIFY highlightedSettingChanged)
    Q_PROPERTY(QString searchQuery READ searchQuery WRITE setSearchQuery NOTIFY searchQueryChanged)
    Q_PROPERTY(QVariantList searchResults READ searchResults NOTIFY searchResultsChanged)
    Q_PROPERTY(QVariantList pages READ pages CONSTANT)

public:
    explicit SettingsManager(QObject *parent = nullptr);
    ~SettingsManager() override;

    QString appearanceMode() const;
    void setAppearanceMode(const QString &mode);

    QString appearanceAccent() const;
    void setAppearanceAccent(const QString &accent);

    int dockSize() const;
    void setDockSize(int size);

    bool dockMagnification() const;
    void setDockMagnification(bool enabled);

    qreal dockMagnificationScale() const;
    void setDockMagnificationScale(qreal scale);

    QString dockDisplayPolicy() const;
    void setDockDisplayPolicy(const QString &policy);

    qreal displayScale() const;
    void setDisplayScale(qreal scale);

    int soundVolume() const;
    void setSoundVolume(int vol);

    bool soundMuted() const;
    void setSoundMuted(bool muted);

    bool wifiEnabled() const;
    void setWifiEnabled(bool enabled);

    bool bluetoothEnabled() const;
    void setBluetoothEnabled(bool enabled);

    QString desktopWallpaper() const;
    void setDesktopWallpaper(const QString &wallpaper);

    QString activePage() const;
    void setActivePage(const QString &page);

    QString highlightedSetting() const;
    void setHighlightedSetting(const QString &settingId);

    QString searchQuery() const;
    void setSearchQuery(const QString &query);

    QVariantList searchResults() const;
    QVariantList pages() const;

    Q_INVOKABLE void navigateTo(const QString &page, const QString &settingId = QString());
    Q_INVOKABLE void handleUrl(const QString &url);
    Q_INVOKABLE void resetSetting(const QString &key);

Q_SIGNALS:
    void appearanceModeChanged();
    void appearanceAccentChanged();
    void dockSizeChanged();
    void dockMagnificationChanged();
    void dockMagnificationScaleChanged();
    void dockDisplayPolicyChanged();
    void displayScaleChanged();
    void soundVolumeChanged();
    void soundMutedChanged();
    void wifiEnabledChanged();
    void bluetoothEnabledChanged();
    void desktopWallpaperChanged();

    void activePageChanged();
    void highlightedSettingChanged();
    void searchQueryChanged();
    void searchResultsChanged();

private Q_SLOTS:
    void onDBusSettingChanged(const QString &key, const QVariant &value);

private:
    void loadSettings();
    void writeSetting(const QString &key, const QVariant &value);
    void performSearch(const QString &query);

    QString m_appearanceMode = "dark";
    QString m_appearanceAccent = "#0066CC";
    int m_dockSize = 68;
    bool m_dockMagnification = true;
    qreal m_dockMagnificationScale = 1.35;
    QString m_dockDisplayPolicy = "primary";
    qreal m_displayScale = 1.0;
    int m_soundVolume = 75;
    bool m_soundMuted = false;
    bool m_wifiEnabled = true;
    bool m_bluetoothEnabled = true;
    QString m_desktopWallpaper = "default.jpg";

    QString m_activePage = "about";
    QString m_highlightedSetting;
    QString m_searchQuery;
    QVariantList m_searchResults;
};
