#pragma once

#include <QObject>
#include <QString>
#include <QMap>
#include <QVariantList>
#include <QDBusContext>
#include <QDBusObjectPath>
#include <QDBusConnection>
#include <QDBusMessage>

struct MenuRegistration {
    uint windowId;
    QString service;
    QString objectPath;
};

class MenuRegistrar : public QObject, protected QDBusContext {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "com.canonical.AppMenu.Registrar")

public:
    explicit MenuRegistrar(QObject *parent = nullptr);
    ~MenuRegistrar() override;

    bool initDBus();
    bool hasMenuForWindow(uint windowId) const;
    MenuRegistration getRegistration(uint windowId) const;

    QVariantList fetchLayoutForWindow(uint windowId);
    bool triggerAction(uint windowId, int actionId);

public Q_SLOTS:
    Q_SCRIPTABLE void RegisterWindow(uint windowId, const QDBusObjectPath &menuObjectPath);
    Q_SCRIPTABLE void UnregisterWindow(uint windowId);
    Q_SCRIPTABLE QString GetMenuForWindow(uint windowId, QString &service, QDBusObjectPath &menuObjectPath);

Q_SIGNALS:
    Q_SCRIPTABLE void WindowRegistered(uint windowId, const QString &service, const QDBusObjectPath &menuObjectPath);
    Q_SCRIPTABLE void WindowUnregistered(uint windowId);

    void menuUpdated(uint windowId);

private Q_SLOTS:
    void onServiceUnregistered(const QString &serviceName);

private:
    QMap<uint, MenuRegistration> m_registrations;
};
