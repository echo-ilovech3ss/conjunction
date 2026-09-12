#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>

class AudioBackend : public QObject {
    Q_OBJECT

    Q_PROPERTY(int volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool muted READ muted WRITE setMuted NOTIFY mutedChanged)
    Q_PROPERTY(QString currentDevice READ currentDevice WRITE setCurrentDevice NOTIFY deviceChanged)
    Q_PROPERTY(QVariantList outputDevices READ outputDevices CONSTANT)

public:
    explicit AudioBackend(QObject *parent = nullptr);
    ~AudioBackend() override;

    int volume() const;
    void setVolume(int vol);

    bool muted() const;
    void setMuted(bool mute);

    QString currentDevice() const;
    void setCurrentDevice(const QString &device);

    QVariantList outputDevices() const;

Q_SIGNALS:
    void volumeChanged();
    void mutedChanged();
    void deviceChanged();

private:
    int m_volume = 75;
    bool m_muted = false;
    QString m_currentDevice = "Default Audio Output (PipeWire / WirePlumber)";
    QVariantList m_outputDevices;
};
