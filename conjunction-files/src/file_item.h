#pragma once

#include <QString>
#include <QFileInfo>
#include <QDateTime>
#include <QVariantMap>

class FileItem {
public:
    FileItem();
    static FileItem fromPath(const QString &filePath);

    QString name;
    QString path;
    QString sizeFormatted;
    qint64 sizeBytes = 0;
    QString modifiedFormatted;
    qint64 modifiedTimestamp = 0;
    bool isDir = false;
    bool isAppBundle = false;
    bool isSymlink = false;
    bool isHidden = false;
    QString bundleId;
    QString bundleName;
    QString bundleIcon;
    QString bundleExecutable;
    QString mimeType;
    QString iconName;
    bool canShowPackageContents = false;

    QVariantMap toMap() const;
    static QString formatSize(qint64 bytes, bool isDirectory);
    static QString detectMimeType(const QString &filePath);
    static QString resolveIconName(const QString &mimeType, bool isDir, bool isAppBundle);
};
