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
    Q_PROPERTY(bool reducedMotion READ reducedMotion WRITE setReducedMotion NOTIFY reducedMotionChanged)
    Q_PROPERTY(bool reduceTransparency READ reduceTransparency WRITE setReduceTransparency NOTIFY reduceTransparencyChanged)
    Q_PROPERTY(bool increaseContrast READ increaseContrast WRITE setIncreaseContrast NOTIFY increaseContrastChanged)
    Q_PROPERTY(int dockSize READ dockSize WRITE setDockSize NOTIFY dockSizeChanged)
    Q_PROPERTY(bool dockMagnification READ dockMagnification WRITE setDockMagnification NOTIFY dockMagnificationChanged)
    Q_PROPERTY(qreal dockMagnificationScale READ dockMagnificationScale WRITE setDockMagnificationScale NOTIFY dockMagnificationScaleChanged)
    Q_PROPERTY(QString dockMinimizeEffect READ dockMinimizeEffect WRITE setDockMinimizeEffect NOTIFY dockMinimizeEffectChanged)
    Q_PROPERTY(QString dockDisplayPolicy READ dockDisplayPolicy WRITE setDockDisplayPolicy NOTIFY dockDisplayPolicyChanged)
    Q_PROPERTY(int hotCornerBottomRight READ hotCornerBottomRight WRITE setHotCornerBottomRight NOTIFY hotCornerBottomRightChanged)
    Q_PROPERTY(bool canGoBack READ canGoBack NOTIFY navigationHistoryChanged)
    Q_PROPERTY(bool canGoForward READ canGoForward NOTIFY navigationHistoryChanged)
    Q_PROPERTY(qreal displayScale READ displayScale WRITE setDisplayScale NOTIFY displayScaleChanged)
    Q_PROPERTY(int soundVolume READ soundVolume WRITE setSoundVolume NOTIFY soundVolumeChanged)
    Q_PROPERTY(bool soundMuted READ soundMuted WRITE setSoundMuted NOTIFY soundMutedChanged)
    Q_PROPERTY(bool wifiEnabled READ wifiEnabled WRITE setWifiEnabled NOTIFY wifiEnabledChanged)
    Q_PROPERTY(bool bluetoothEnabled READ bluetoothEnabled WRITE setBluetoothEnabled NOTIFY bluetoothEnabledChanged)
    Q_PROPERTY(QString desktopWallpaper READ desktopWallpaper WRITE setDesktopWallpaper NOTIFY desktopWallpaperChanged)

    Q_PROPERTY(QVariantList defaultAppCategories READ defaultAppCategories NOTIFY defaultAppsChanged)
    Q_PROPERTY(QVariantList shortcuts READ shortcuts NOTIFY shortcutsChanged)

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

    bool reducedMotion() const;
    void setReducedMotion(bool enabled);

    bool reduceTransparency() const;
    Q_INVOKABLE void setReduceTransparency(bool enabled);

    bool increaseContrast() const;
    Q_INVOKABLE void setIncreaseContrast(bool enabled);

    QString dockMinimizeEffect() const;
    Q_INVOKABLE void setDockMinimizeEffect(const QString &effect);

    int hotCornerBottomRight() const;
    Q_INVOKABLE void setHotCornerBottomRight(int actionCode);

    bool canGoBack() const;
    bool canGoForward() const;
    Q_INVOKABLE void goBack();
    Q_INVOKABLE void goForward();

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

    QVariantList defaultAppCategories() const;
    Q_INVOKABLE QVariantList getAvailableHandlers(const QString &mimeType) const;
    Q_INVOKABLE bool setDefaultHandler(const QString &mimeType, const QString &desktopId);

    QVariantList shortcuts() const;
    Q_INVOKABLE bool updateShortcut(const QString &id, const QString &keySequence);
    Q_INVOKABLE void resetShortcuts();

    Q_INVOKABLE void navigateTo(const QString &page, const QString &settingId = QString());
    Q_INVOKABLE void handleUrl(const QString &url);
    Q_INVOKABLE void resetSetting(const QString &key);

Q_SIGNALS:
    void appearanceModeChanged();
    void appearanceAccentChanged();
    void reducedMotionChanged();
    void reduceTransparencyChanged();
    void increaseContrastChanged();
    void dockMinimizeEffectChanged();
    void hotCornerBottomRightChanged();
    void navigationHistoryChanged();
    void defaultAppsChanged();
    void shortcutsChanged();
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

    QString m_appearanceMode = "light";
    QString m_appearanceAccent = "blue";
    int m_dockSize = 54;
    bool m_dockMagnification = true;
    qreal m_dockMagnificationScale = 1.45;
    QString m_dockMinimizeEffect = "genie";
    QString m_dockDisplayPolicy = "primary";
    int m_hotCornerBottomRight = 14;
    qreal m_displayScale = 1.0;
    int m_soundVolume = 75;
    bool m_soundMuted = false;
    bool m_wifiEnabled = true;
    bool m_bluetoothEnabled = true;
    QString m_desktopWallpaper = "conjunction-light.svg";
    bool m_reducedMotion = false;
    bool m_reduceTransparency = false;
    bool m_increaseContrast = false;
    QString m_activePage = "about";
    QStringList m_pageHistory = {"about"};
    int m_pageHistoryIdx = 0;
    QString m_highlightedSetting;
    QString m_searchQuery;
    QVariantList m_searchResults;
    QMap<QString, QString> m_customShortcuts;

    void loadShortcuts();
    QString resolveDefaultHandler(const QString &mimeType) const;
};
