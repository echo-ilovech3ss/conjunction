#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QTimer>

class DisplayBackend : public QObject {
    Q_OBJECT

    Q_PROPERTY(QString primaryResolution READ primaryResolution NOTIFY screensChanged)
    Q_PROPERTY(QString primaryRefreshRate READ primaryRefreshRate NOTIFY screensChanged)
    Q_PROPERTY(int screenCount READ screenCount NOTIFY screensChanged)
    Q_PROPERTY(qreal currentScale READ currentScale WRITE setCurrentScale NOTIFY currentScaleChanged)
    Q_PROPERTY(QVariantList availableScales READ availableScales CONSTANT)
    Q_PROPERTY(QVariantList displays READ displays NOTIFY screensChanged)
    Q_PROPERTY(bool revertDialogVisible READ revertDialogVisible NOTIFY revertDialogVisibleChanged)
    Q_PROPERTY(int revertCountdown READ revertCountdown NOTIFY revertCountdownChanged)

public:
    explicit DisplayBackend(QObject *parent = nullptr);
    ~DisplayBackend() override;

    QString primaryResolution() const;
    QString primaryRefreshRate() const;
    int screenCount() const;
    qreal currentScale() const;
    void setCurrentScale(qreal scale);

    QVariantList availableScales() const;
    QVariantList displays() const;
    bool revertDialogVisible() const;
    int revertCountdown() const;

    Q_INVOKABLE void applyScaleWithTimeout(qreal newScale, int timeoutSeconds = 15);
    Q_INVOKABLE void confirmScaleChange();
    Q_INVOKABLE void revertScaleChange();

Q_SIGNALS:
    void screensChanged();
    void currentScaleChanged();
    void revertDialogVisibleChanged();
    void revertCountdownChanged();

private Q_SLOTS:
    void onRevertTick();

private:
    void refreshScreens();

    QString m_primaryResolution = "1920 x 1080";
    QString m_primaryRefreshRate = "60 Hz";
    int m_screenCount = 1;
    qreal m_currentScale = 1.0;
    qreal m_previousScale = 1.0;
    QVariantList m_displays;

    bool m_revertDialogVisible = false;
    int m_revertCountdown = 15;
    QTimer *m_revertTimer = nullptr;
};
