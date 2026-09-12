#include "notification_manager.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QStandardPaths>
#include <QSettings>
#include <QRegularExpression>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDebug>

QVariantMap NotificationItem::toMap() const {
    QVariantMap m;
    m["id"] = id;
    m["appName"] = appName;
    m["appId"] = appId;
    m["appIcon"] = appIcon;
    m["summary"] = summary;
    m["body"] = body;
    m["actions"] = actions;
    m["urgency"] = urgency;
    m["timestamp"] = timestamp;
    m["timeoutMs"] = timeoutMs;
    m["isRead"] = isRead;
    m["bannerVisible"] = bannerVisible;
    return m;
}

NotificationItem NotificationItem::fromMap(const QVariantMap &m) {
    NotificationItem item;
    item.id = m.value("id").toUInt();
    item.appName = m.value("appName").toString();
    item.appId = m.value("appId").toString();
    item.appIcon = m.value("appIcon").toString();
    item.summary = m.value("summary").toString();
    item.body = m.value("body").toString();
    item.actions = m.value("actions").toStringList();
    item.urgency = m.value("urgency", 1).toInt();
    item.timestamp = m.value("timestamp").toLongLong();
    item.timeoutMs = m.value("timeoutMs", 5000).toInt();
    item.isRead = m.value("isRead", false).toBool();
    item.bannerVisible = m.value("bannerVisible", false).toBool();
    return item;
}

NotificationManager::NotificationManager(QObject *parent)
    : QObject(parent)
{
    loadHistory();
}

NotificationManager::~NotificationManager() {
    saveHistory();
}

QString NotificationManager::sanitizeMarkup(const QString &raw) {
    if (raw.isEmpty()) return QString();

    QString clean = raw;
    // Strip script and iframe tags completely
    clean.remove(QRegularExpression(QStringLiteral("<script[^>]*>.*?</script>"), QRegularExpression::CaseInsensitiveOption));
    clean.remove(QRegularExpression(QStringLiteral("<iframe[^>]*>.*?</iframe>"), QRegularExpression::CaseInsensitiveOption));
    // Strip remote images
    clean.remove(QRegularExpression(QStringLiteral("<img[^>]*>"), QRegularExpression::CaseInsensitiveOption));

    // Convert common tags like <br>, <p> to newline
    clean.replace(QRegularExpression(QStringLiteral("<br\\s*/?>"), QRegularExpression::CaseInsensitiveOption), QStringLiteral("\n"));
    clean.replace(QRegularExpression(QStringLiteral("</p>"), QRegularExpression::CaseInsensitiveOption), QStringLiteral("\n"));

    // Remove remaining HTML tags to keep safe plain text
    clean.remove(QRegularExpression(QStringLiteral("<[^>]+>")));

    // Decode standard entities
    clean.replace(QStringLiteral("&amp;"), QStringLiteral("&"));
    clean.replace(QStringLiteral("&lt;"), QStringLiteral("<"));
    clean.replace(QStringLiteral("&gt;"), QStringLiteral(">"));
    clean.replace(QStringLiteral("&quot;"), QStringLiteral("\""));
    clean.replace(QStringLiteral("&apos;"), QStringLiteral("'"));

    // Collapse multiple whitespace
    clean.replace(QRegularExpression(QStringLiteral("[ \\t]+")), QStringLiteral(" "));

    return clean.trimmed();
}

bool NotificationManager::isDoNotDisturbActive() const {
    if (m_hasDndOverride) {
        return m_dndOverride;
    }

    // Check D-Bus org.conjunction.Settings
    QDBusMessage call = QDBusMessage::createMethodCall(
        QStringLiteral("org.conjunction.Settings"),
        QStringLiteral("/org/conjunction/Settings"),
        QStringLiteral("org.conjunction.Settings"),
        QStringLiteral("GetSetting")
    );
    call << QStringLiteral("sound.doNotDisturb");
    QDBusMessage reply = QDBusConnection::sessionBus().call(call, QDBus::NoBlock, 200);
    if (reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()) {
        QVariant var = reply.arguments().at(0);
        if (var.userType() == qMetaTypeId<QDBusVariant>()) {
            var = qvariant_cast<QDBusVariant>(var).variant();
        }
        return var.toBool();
    }

    // Fallback: check ~/.config/conjunction/settings.ini
    QString cfgPath = QDir::homePath() + QStringLiteral("/.config/conjunction/settings.ini");
    if (QFile::exists(cfgPath)) {
        QSettings s(cfgPath, QSettings::IniFormat);
        return s.value(QStringLiteral("sound/doNotDisturb"), false).toBool();
    }

    return false;
}

void NotificationManager::setDoNotDisturbOverride(bool dnd) {
    m_hasDndOverride = true;
    m_dndOverride = dnd;
}

int NotificationManager::resolveUrgency(const QVariantMap &hints) const {
    if (hints.contains(QStringLiteral("urgency"))) {
        return hints.value(QStringLiteral("urgency")).toInt();
    }
    return 1; // Default normal
}

QString NotificationManager::resolveAppId(const QString &appName, const QVariantMap &hints) const {
    if (hints.contains(QStringLiteral("desktop-entry"))) {
        QString de = hints.value(QStringLiteral("desktop-entry")).toString().trimmed();
        if (!de.isEmpty()) {
            return de.endsWith(QStringLiteral(".desktop")) ? de.left(de.length() - 8) : de;
        }
    }
    QString lower = appName.toLower().trimmed();
    if (lower.isEmpty()) return QStringLiteral("org.conjunction.generic");
    return lower;
}

uint NotificationManager::Notify(const QString &app_name, uint replaces_id,
                                 const QString &app_icon, const QString &summary,
                                 const QString &body, const QStringList &actions,
                                 const QVariantMap &hints, int expire_timeout)
{
    uint id = 0;
    bool isReplacement = false;

    if (replaces_id > 0 && m_active.contains(replaces_id)) {
        id = replaces_id;
        isReplacement = true;
    } else {
        id = m_nextId++;
    }

    NotificationItem item;
    item.id = id;
    item.appName = app_name.trimmed().isEmpty() ? QStringLiteral("System") : app_name.trimmed();
    item.appId = resolveAppId(item.appName, hints);
    item.appIcon = app_icon;
    item.summary = sanitizeMarkup(summary).left(256);
    item.body = sanitizeMarkup(body).left(4096);
    item.actions = actions;
    item.hints = hints;
    item.urgency = resolveUrgency(hints);
    item.timestamp = QDateTime::currentMSecsSinceEpoch();
    item.timeoutMs = (expire_timeout > 0) ? expire_timeout : 5000;
    item.isRead = false;

    // Do Not Disturb evaluation:
    // When DND is ON, suppress banners unless urgency is critical (2)
    bool dnd = isDoNotDisturbActive();
    if (dnd && item.urgency < 2) {
        item.bannerVisible = false;
    } else {
        item.bannerVisible = true;
    }

    m_active[id] = item;

    // Update history (replace if replacement ID exists, otherwise prepend)
    bool foundInHistory = false;
    if (isReplacement) {
        for (int i = 0; i < m_history.size(); ++i) {
            if (m_history[i].id == id) {
                m_history[i] = item;
                foundInHistory = true;
                break;
            }
        }
    }
    if (!foundInHistory) {
        m_history.prepend(item);
        // Bound history to 100 entries
        while (m_history.size() > 100) {
            m_history.removeLast();
        }
    }

    saveHistory();

    QJsonObject obj = QJsonObject::fromVariantMap(item.toMap());
    QString jsonStr = QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact));

    if (isReplacement) {
        emit NotificationUpdated(id, jsonStr);
    } else {
        emit NotificationAdded(id, jsonStr);
    }
    emit HistoryChanged();

    return id;
}

void NotificationManager::CloseNotification(uint id) {
    if (m_active.contains(id)) {
        m_active.remove(id);
        emit NotificationClosed(id, 3); // Reason 3: closed by call to CloseNotification
        emit NotificationRemoved(id);
    }
}

QStringList NotificationManager::GetCapabilities() const {
    return QStringList() << QStringLiteral("actions")
                         << QStringLiteral("body")
                         << QStringLiteral("body-markup")
                         << QStringLiteral("icon-static")
                         << QStringLiteral("persistence");
}

QString NotificationManager::GetServerInformation(QString &vendor, QString &version, QString &spec_version) const {
    vendor = QStringLiteral("Conjunction");
    version = QStringLiteral("1.0");
    spec_version = QStringLiteral("1.2");
    return QStringLiteral("Conjunction Notification Daemon");
}

QString NotificationManager::GetHistoryJson() const {
    QJsonArray arr;
    for (const auto &item : m_history) {
        arr.append(QJsonObject::fromVariantMap(item.toMap()));
    }
    return QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact));
}

QString NotificationManager::GetActiveBannersJson() const {
    QJsonArray arr;
    for (const auto &item : m_active.values()) {
        if (item.bannerVisible) {
            arr.append(QJsonObject::fromVariantMap(item.toMap()));
        }
    }
    return QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact));
}

void NotificationManager::Dismiss(uint id) {
    if (m_active.contains(id)) {
        m_active.remove(id);
        emit NotificationClosed(id, 2); // Reason 2: user dismissed
        emit NotificationRemoved(id);
    }
    // Mark as read in history
    for (int i = 0; i < m_history.size(); ++i) {
        if (m_history[i].id == id) {
            m_history[i].isRead = true;
            break;
        }
    }
    saveHistory();
    emit HistoryChanged();
}

void NotificationManager::ClearAll() {
    for (auto id : m_active.keys()) {
        emit NotificationClosed(id, 2);
        emit NotificationRemoved(id);
    }
    m_active.clear();
    m_history.clear();
    saveHistory();
    emit HistoryChanged();
}

void NotificationManager::TriggerAction(uint id, const QString &action_key) {
    emit ActionInvoked(id, action_key);
    Dismiss(id);
}

QString NotificationManager::historyFilePath() const {
    QString stateDir = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/conjunction");
    QDir().mkpath(stateDir);
    return stateDir + QStringLiteral("/notifications.json");
}

void NotificationManager::loadHistory() {
    QFile file(historyFilePath());
    if (!file.open(QIODevice::ReadOnly)) {
        return;
    }

    QByteArray data = file.readAll();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isArray()) return;

    m_history.clear();
    QJsonArray arr = doc.array();
    uint maxId = 0;

    for (const auto &val : arr) {
        if (val.isObject()) {
            NotificationItem item = NotificationItem::fromMap(val.toObject().toVariantMap());
            item.bannerVisible = false; // Restored from disk, do not pop banner
            m_history.append(item);
            if (item.id > maxId) {
                maxId = item.id;
            }
        }
    }
    m_nextId = maxId + 1;
}

void NotificationManager::saveHistory() {
    QFile file(historyFilePath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return;
    }

    QJsonArray arr;
    for (const auto &item : m_history) {
        arr.append(QJsonObject::fromVariantMap(item.toMap()));
    }
    file.write(QJsonDocument(arr).toJson(QJsonDocument::Compact));
}
