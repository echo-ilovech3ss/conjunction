#pragma once

#include <QObject>
#include <QString>

class SystemInfo : public QObject {
    Q_OBJECT

    Q_PROPERTY(QString osName READ osName CONSTANT)
    Q_PROPERTY(QString osKernel READ osKernel CONSTANT)
    Q_PROPERTY(QString cpuModel READ cpuModel CONSTANT)
    Q_PROPERTY(QString memoryTotal READ memoryTotal CONSTANT)
    Q_PROPERTY(QString graphicsDevice READ graphicsDevice CONSTANT)
    Q_PROPERTY(QString desktopSession READ desktopSession CONSTANT)
    Q_PROPERTY(QString uptime READ uptime NOTIFY uptimeChanged)

public:
    explicit SystemInfo(QObject *parent = nullptr);
    ~SystemInfo() override;

    QString osName() const;
    QString osKernel() const;
    QString cpuModel() const;
    QString memoryTotal() const;
    QString graphicsDevice() const;
    QString desktopSession() const;
    QString uptime() const;

Q_SIGNALS:
    void uptimeChanged();

private:
    void probeSystem();

    QString m_osName = "Conjunction 2026.09 (Rolling Release)";
    QString m_osKernel = "Linux";
    QString m_cpuModel = "x86_64 Processor";
    QString m_memoryTotal = "16.0 GB";
    QString m_graphicsDevice = "Generic DRM / KMS Controller";
    QString m_desktopSession = "Conjunction (KWin Wayland)";
};
