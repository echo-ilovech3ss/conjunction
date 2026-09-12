#include "menu_registrar.h"
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusArgument>
#include <QDBusMetaType>
#include <QDebug>

MenuRegistrar::MenuRegistrar(QObject *parent)
    : QObject(parent)
{
}

MenuRegistrar::~MenuRegistrar() = default;

bool MenuRegistrar::initDBus()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        qWarning() << "[MenuRegistrar] Session D-Bus not connected";
        return false;
    }

    if (!bus.registerService("com.canonical.AppMenu.Registrar")) {
        qWarning() << "[MenuRegistrar] Failed to register service com.canonical.AppMenu.Registrar:" << bus.lastError().message();
    }

    if (!bus.registerObject("/com/canonical/AppMenu/Registrar", this, QDBusConnection::ExportScriptableContents | QDBusConnection::ExportAllSignals)) {
        qWarning() << "[MenuRegistrar] Failed to register object /com/canonical/AppMenu/Registrar:" << bus.lastError().message();
        return false;
    }

    connect(bus.interface(), &QDBusConnectionInterface::serviceUnregistered,
            this, &MenuRegistrar::onServiceUnregistered);

    qInfo() << "[MenuRegistrar] Successfully registered com.canonical.AppMenu.Registrar";
    return true;
}

bool MenuRegistrar::hasMenuForWindow(uint windowId) const
{
    return m_registrations.contains(windowId);
}

MenuRegistration MenuRegistrar::getRegistration(uint windowId) const
{
    return m_registrations.value(windowId);
}

void MenuRegistrar::RegisterWindow(uint windowId, const QDBusObjectPath &menuObjectPath)
{
    QString service = message().service();
    if (service.isEmpty()) {
        service = "org.conjunction.local";
    }

    MenuRegistration reg;
    reg.windowId = windowId;
    reg.service = service;
    reg.objectPath = menuObjectPath.path();

    m_registrations.insert(windowId, reg);
    qInfo() << "[MenuRegistrar] Registered window" << windowId << "to service" << service << "path" << reg.objectPath;

    Q_EMIT WindowRegistered(windowId, service, menuObjectPath);
    Q_EMIT menuUpdated(windowId);
}

void MenuRegistrar::UnregisterWindow(uint windowId)
{
    if (m_registrations.remove(windowId) > 0) {
        qInfo() << "[MenuRegistrar] Unregistered window" << windowId;
        Q_EMIT WindowUnregistered(windowId);
        Q_EMIT menuUpdated(windowId);
    }
}

QString MenuRegistrar::GetMenuForWindow(uint windowId, QString &service, QDBusObjectPath &menuObjectPath)
{
    if (m_registrations.contains(windowId)) {
        const auto &reg = m_registrations[windowId];
        service = reg.service;
        menuObjectPath.setPath(reg.objectPath);
        return service;
    }
    return QString();
}

void MenuRegistrar::onServiceUnregistered(const QString &serviceName)
{
    QList<uint> toRemove;
    for (auto it = m_registrations.constBegin(); it != m_registrations.constEnd(); ++it) {
        if (it.value().service == serviceName) {
            toRemove.append(it.key());
        }
    }

    for (uint winId : toRemove) {
        UnregisterWindow(winId);
    }
}

static QVariantMap parseDBusMenuItem(const QDBusArgument &arg)
{
    QVariantMap itemMap;
    int id = 0;
    QVariantMap props;

    arg.beginStructure();
    arg >> id;
    arg >> props;

    QVariantList children;
    arg.beginArray();
    while (!arg.atEnd()) {
        QDBusVariant varChild;
        arg >> varChild;
        QDBusArgument childArg = varChild.variant().value<QDBusArgument>();
        children.append(parseDBusMenuItem(childArg));
    }
    arg.endArray();
    arg.endStructure();

    itemMap["id"] = id;
    itemMap["label"] = props.value("label").toString();
    itemMap["enabled"] = props.value("enabled", true).toBool();
    itemMap["visible"] = props.value("visible", true).toBool();
    itemMap["iconName"] = props.value("icon-name").toString();
    itemMap["children"] = children;

    return itemMap;
}

QVariantList MenuRegistrar::fetchLayoutForWindow(uint windowId)
{
    if (!m_registrations.contains(windowId)) {
        return {};
    }

    const auto &reg = m_registrations[windowId];
    QDBusInterface dbusmenu(reg.service, reg.objectPath, "com.canonical.dbusmenu", QDBusConnection::sessionBus());
    if (!dbusmenu.isValid()) {
        return {};
    }

    QDBusMessage reply = dbusmenu.call("GetLayout", 0, 2, QStringList());
    if (reply.type() == QDBusMessage::ErrorMessage) {
        return {};
    }

    const QList<QVariant> args = reply.arguments();
    if (args.size() < 2) {
        return {};
    }

    const QDBusArgument rootArg = args[1].value<QDBusArgument>();
    QVariantMap rootItem = parseDBusMenuItem(rootArg);
    return rootItem.value("children").toList();
}

bool MenuRegistrar::triggerAction(uint windowId, int actionId)
{
    if (!m_registrations.contains(windowId)) {
        return false;
    }

    const auto &reg = m_registrations[windowId];
    QDBusInterface dbusmenu(reg.service, reg.objectPath, "com.canonical.dbusmenu", QDBusConnection::sessionBus());
    if (!dbusmenu.isValid()) {
        return false;
    }

    QDBusMessage reply = dbusmenu.call("Event", actionId, "clicked", QVariant::fromValue(QDBusVariant(0)), 0u);
    return reply.type() != QDBusMessage::ErrorMessage;
}
