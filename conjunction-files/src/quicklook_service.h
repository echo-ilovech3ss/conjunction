#pragma once

#include <QObject>
#include <QVariantMap>

class QuickLookService : public QObject {
    Q_OBJECT

public:
    explicit QuickLookService(QObject *parent = nullptr);

    Q_INVOKABLE QVariantMap inspect(const QString &filePath) const;
    Q_INVOKABLE void openWithDefault(const QString &filePath) const;

private:
    static bool isImageMime(const QString &mime);
    static bool isTextMime(const QString &mime, const QString &ext);
};
