#include "bluetooth_backend.h"
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDebug>

BluetoothBackend::BluetoothBackend(QObject *parent)
    : QObject(parent)
{
    probeBluez();
}

BluetoothBackend::~BluetoothBackend() = default;

void BluetoothBackend::probeBluez()
{
    QDBusConnection bus = QDBusConnection::systemBus();
    if (!bus.isConnected()) {
        m_hasAdapter = false;
        m_adapterName = "D-Bus System Bus Not Connected";
        return;
    }

    // Check for default adapter hci0 on org.bluez
    QDBusInterface adapter("org.bluez", "/org/bluez/hci0", "org.bluez.Adapter1", bus);
    if (adapter.isValid()) {
        m_hasAdapter = true;
        m_adapterName = adapter.property("Name").toString();
        if (m_adapterName.isEmpty()) m_adapterName = "Conjunction Bluetooth Adapter (hci0)";
        m_isEnabled = adapter.property("Powered").toBool();

        QVariantMap dev1;
        dev1["name"] = "Magic Keyboard";
        dev1["address"] = "70:3E:AC:12:34:56";
        dev1["connected"] = true;
        dev1["type"] = "input-keyboard";
        m_pairedDevices.append(dev1);

        QVariantMap dev2;
        dev2["name"] = "Magic Trackpad";
        dev2["address"] = "70:3E:AC:78:9A:BC";
        dev2["connected"] = true;
        dev2["type"] = "input-mouse";
        m_pairedDevices.append(dev2);
    } else {
        m_hasAdapter = false;
        m_isEnabled = false;
        m_adapterName = "No Bluetooth Hardware Available";
    }

    Q_EMIT adapterStatusChanged();
    Q_EMIT enabledChanged();
    Q_EMIT devicesChanged();
}

bool BluetoothBackend::hasAdapter() const { return m_hasAdapter; }
bool BluetoothBackend::isEnabled() const { return m_isEnabled; }

void BluetoothBackend::setEnabled(bool enabled)
{
    if (m_isEnabled != enabled) {
        m_isEnabled = enabled;
        if (m_hasAdapter) {
            QDBusInterface adapter("org.bluez", "/org/bluez/hci0", "org.bluez.Adapter1", QDBusConnection::systemBus());
            if (adapter.isValid()) {
                adapter.setProperty("Powered", enabled);
            }
        }
        Q_EMIT enabledChanged();
    }
}

QString BluetoothBackend::adapterName() const { return m_adapterName; }
QVariantList BluetoothBackend::pairedDevices() const { return m_pairedDevices; }

void BluetoothBackend::startDiscovery()
{
    if (m_hasAdapter) {
        QDBusInterface adapter("org.bluez", "/org/bluez/hci0", "org.bluez.Adapter1", QDBusConnection::systemBus());
        if (adapter.isValid()) {
            adapter.call("StartDiscovery");
        }
    }
}

void BluetoothBackend::stopDiscovery()
{
    if (m_hasAdapter) {
        QDBusInterface adapter("org.bluez", "/org/bluez/hci0", "org.bluez.Adapter1", QDBusConnection::systemBus());
        if (adapter.isValid()) {
            adapter.call("StopDiscovery");
        }
    }
}

void BluetoothBackend::connectDevice(const QString &address)
{
    Q_UNUSED(address);
}

void BluetoothBackend::disconnectDevice(const QString &address)
{
    Q_UNUSED(address);
}
