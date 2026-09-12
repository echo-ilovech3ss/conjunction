#include "audio_backend.h"
#include <QProcess>
#include <QDebug>

AudioBackend::AudioBackend(QObject *parent)
    : QObject(parent)
{
    m_outputDevices.append("Built-in Audio (Speaker)");
    m_outputDevices.append("Headphones (Stereo 3.5mm)");
    m_outputDevices.append("HDMI / DisplayPort Audio");
}

AudioBackend::~AudioBackend() = default;

int AudioBackend::volume() const { return m_volume; }
void AudioBackend::setVolume(int vol)
{
    vol = qBound(0, vol, 100);
    if (m_volume != vol) {
        m_volume = vol;
        Q_EMIT volumeChanged();
    }
}

bool AudioBackend::muted() const { return m_muted; }
void AudioBackend::setMuted(bool mute)
{
    if (m_muted != mute) {
        m_muted = mute;
        Q_EMIT mutedChanged();
    }
}

QString AudioBackend::currentDevice() const { return m_currentDevice; }
void AudioBackend::setCurrentDevice(const QString &device)
{
    if (m_currentDevice != device) {
        m_currentDevice = device;
        Q_EMIT deviceChanged();
    }
}

QVariantList AudioBackend::outputDevices() const
{
    return m_outputDevices;
}
