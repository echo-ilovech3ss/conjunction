#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class BluetoothBackend : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool hasAdapter READ hasAdapter NOTIFY adapterStatusChanged)
    Q_PROPERTY(bool isEnabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(QString adapterName READ adapterName NOTIFY adapterStatusChanged)
    Q_PROPERTY(QVariantList pairedDevices READ pairedDevices NOTIFY devicesChanged)

public:
    explicit BluetoothBackend(QObject *parent = nullptr);
    ~BluetoothBackend() override;

    bool hasAdapter() const;
    bool isEnabled() const;
    void setEnabled(bool enabled);

    QString adapterName() const;
    QVariantList pairedDevices() const;

    Q_INVOKABLE void startDiscovery();
    Q_INVOKABLE void stopDiscovery();
    Q_INVOKABLE void connectDevice(const QString &address);
    Q_INVOKABLE void disconnectDevice(const QString &address);

Q_SIGNALS:
    void adapterStatusChanged();
    void enabledChanged();
    void devicesChanged();

private:
    void probeBluez();

    bool m_hasAdapter = false;
    bool m_isEnabled = false;
    QString m_adapterName = "No Bluetooth Adapter Found";
    QVariantList m_pairedDevices;
};
