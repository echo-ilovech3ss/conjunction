#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class NetworkBackend : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool isAvailable READ isAvailable NOTIFY statusChanged)
    Q_PROPERTY(bool isWirelessEnabled READ isWirelessEnabled WRITE setWirelessEnabled NOTIFY wirelessChanged)
    Q_PROPERTY(QString activeSsid READ activeSsid NOTIFY activeConnectionChanged)
    Q_PROPERTY(QString ipAddress READ ipAddress NOTIFY ipAddressChanged)
    Q_PROPERTY(QVariantList availableNetworks READ availableNetworks NOTIFY networksChanged)

public:
    explicit NetworkBackend(QObject *parent = nullptr);
    ~NetworkBackend() override;

    bool isAvailable() const;
    bool isWirelessEnabled() const;
    void setWirelessEnabled(bool enabled);

    QString activeSsid() const;
    QString ipAddress() const;
    QVariantList availableNetworks() const;

    Q_INVOKABLE void scanNetworks();
    Q_INVOKABLE void connectToNetwork(const QString &ssid, const QString &password = QString());

Q_SIGNALS:
    void statusChanged();
    void wirelessChanged();
    void activeConnectionChanged();
    void ipAddressChanged();
    void networksChanged();

private:
    void initNetworkManager();

    bool m_isAvailable = true;
    bool m_isWirelessEnabled = true;
    QString m_activeSsid = "Conjunction-5G";
    QString m_ipAddress = "192.168.1.105";
    QVariantList m_availableNetworks;
};
