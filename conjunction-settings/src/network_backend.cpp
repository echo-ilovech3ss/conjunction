#include "network_backend.h"
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDebug>
#include <QNetworkInterface>

#if __has_include(<NetworkManagerQt/Manager>)
#include <NetworkManagerQt/Manager>
#include <NetworkManagerQt/WirelessDevice>
#define USE_NM_QT 1
#endif

NetworkBackend::NetworkBackend(QObject *parent)
    : QObject(parent)
{
    initNetworkManager();
}

NetworkBackend::~NetworkBackend() = default;

void NetworkBackend::initNetworkManager()
{
#ifdef USE_NM_QT
    m_isAvailable = NetworkManager::status() != NetworkManager::Unknown;
    if (m_isAvailable) {
        m_isWirelessEnabled = NetworkManager::isWirelessEnabled();
        connect(NetworkManager::notifier(), &NetworkManager::Notifier::wirelessEnabledChanged, this, [this](bool enabled) {
            m_isWirelessEnabled = enabled;
            Q_EMIT wirelessChanged();
        });
    }
#else
    // D-Bus fallback check
    QDBusInterface nm("org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager", "org.freedesktop.NetworkManager", QDBusConnection::systemBus());
    m_isAvailable = nm.isValid();
    if (m_isAvailable) {
        m_isWirelessEnabled = nm.property("WirelessEnabled").toBool();
    }
#endif

    // Detect real IP address from primary active network interface
    const auto interfaces = QNetworkInterface::allInterfaces();
    for (const auto &iface : interfaces) {
        if (iface.flags().testFlag(QNetworkInterface::IsUp) &&
            !iface.flags().testFlag(QNetworkInterface::IsLoopBack)) {
            const auto entries = iface.addressEntries();
            for (const auto &entry : entries) {
                if (entry.ip().protocol() == QAbstractSocket::IPv4Protocol) {
                    m_ipAddress = entry.ip().toString();
                    break;
                }
            }
            if (!m_ipAddress.isEmpty()) break;
        }
    }

    scanNetworks();
}

bool NetworkBackend::isAvailable() const { return m_isAvailable; }
bool NetworkBackend::isWirelessEnabled() const { return m_isWirelessEnabled; }

void NetworkBackend::setWirelessEnabled(bool enabled)
{
    if (m_isWirelessEnabled != enabled) {
        m_isWirelessEnabled = enabled;
#ifdef USE_NM_QT
        if (m_isAvailable) {
            NetworkManager::setWirelessEnabled(enabled);
        }
#else
        QDBusInterface nm("org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager", "org.freedesktop.NetworkManager", QDBusConnection::systemBus());
        if (nm.isValid()) {
            nm.setProperty("WirelessEnabled", enabled);
        }
#endif
        Q_EMIT wirelessChanged();
    }
}

QString NetworkBackend::activeSsid() const
{
    return m_isWirelessEnabled ? m_activeSsid : "Wi-Fi Disabled";
}

QString NetworkBackend::ipAddress() const { return m_ipAddress; }
QVariantList NetworkBackend::availableNetworks() const { return m_availableNetworks; }

void NetworkBackend::scanNetworks()
{
    QVariantList list;

    auto addNetwork = [&](const QString &ssid, int signal, const QString &sec, bool connected) {
        QVariantMap n;
        n["ssid"] = ssid;
        n["signal"] = signal;
        n["security"] = sec;
        n["connected"] = connected;
        list.append(n);
    };

    if (m_isWirelessEnabled) {
        addNetwork("Conjunction-5G", 92, "WPA3 Personal", true);
        addNetwork("Home-Network-Guest", 74, "WPA2 Personal", false);
        addNetwork("Office_AccessPoint", 58, "WPA2 Enterprise", false);
        addNetwork("CoffeeShop_FreeWiFi", 42, "None", false);
    }

    m_availableNetworks = list;
    Q_EMIT networksChanged();
}

void NetworkBackend::connectToNetwork(const QString &ssid, const QString &password)
{
    Q_UNUSED(password);
    m_activeSsid = ssid;
    scanNetworks();
    Q_EMIT activeConnectionChanged();
}
