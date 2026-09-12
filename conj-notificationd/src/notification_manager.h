#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <QList>
#include <QDateTime>
#include <QDBusVariant>
#include <QDBusContext>

struct NotificationItem {
    uint id = 0;
    QString appName;
    QString appId;
    QString appIcon;
    QString summary;
    QString body;
    QStringList actions;
    QVariantMap hints;
    int urgency = 1; // 0=low, 1=normal, 2=critical
    qint64 timestamp = 0;
    int timeoutMs = 5000;
    bool isRead = false;
    bool bannerVisible = true;

    QVariantMap toMap() const;
    static NotificationItem fromMap(const QVariantMap &map);
};

class NotificationManager : public QObject, protected QDBusContext {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.Notifications")

public:
    explicit NotificationManager(QObject *parent = nullptr);
    ~NotificationManager() override;

    bool isDoNotDisturbActive() const;
    void setDoNotDisturbOverride(bool dnd);

    static QString sanitizeMarkup(const QString &raw);

public Q_SLOTS:
    // org.freedesktop.Notifications Specification
    Q_SCRIPTABLE uint Notify(const QString &app_name, uint replaces_id,
                             const QString &app_icon, const QString &summary,
                             const QString &body, const QStringList &actions,
                             const QVariantMap &hints, int expire_timeout);

    Q_SCRIPTABLE void CloseNotification(uint id);
    Q_SCRIPTABLE QStringList GetCapabilities() const;
    Q_SCRIPTABLE QString GetServerInformation(QString &vendor, QString &version, QString &spec_version) const;

    // org.conjunction.Notifications Internal Integration Interface
    Q_SCRIPTABLE QString GetHistoryJson() const;
    Q_SCRIPTABLE QString GetActiveBannersJson() const;
    Q_SCRIPTABLE void Dismiss(uint id);
    Q_SCRIPTABLE void ClearAll();
    Q_SCRIPTABLE void TriggerAction(uint id, const QString &action_key);
    Q_SCRIPTABLE void SetDoNotDisturb(bool dnd) { setDoNotDisturbOverride(dnd); }
    Q_SCRIPTABLE bool IsDoNotDisturb() const { return isDoNotDisturbActive(); }

Q_SIGNALS:
    // org.freedesktop.Notifications Standard Signals
    Q_SCRIPTABLE void NotificationClosed(uint id, uint reason);
    Q_SCRIPTABLE void ActionInvoked(uint id, const QString &action_key);

    // org.conjunction.Notifications Signals
    Q_SCRIPTABLE void NotificationAdded(uint id, const QString &json);
    Q_SCRIPTABLE void NotificationUpdated(uint id, const QString &json);
    Q_SCRIPTABLE void NotificationRemoved(uint id);
    Q_SCRIPTABLE void HistoryChanged();

private:
    void loadHistory();
    void saveHistory();
    QString historyFilePath() const;
    int resolveUrgency(const QVariantMap &hints) const;
    QString resolveAppId(const QString &appName, const QVariantMap &hints) const;

    uint m_nextId = 1;
    QList<NotificationItem> m_history;
    QMap<uint, NotificationItem> m_active;
    bool m_dndOverride = false;
    bool m_hasDndOverride = false;
};
