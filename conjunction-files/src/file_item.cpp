#include "file_item.h"
#include <QDir>
#include <QFile>
#include <QMimeDatabase>
#include <QMimeType>
#include <QRegularExpression>

FileItem::FileItem() {}

QString FileItem::formatSize(qint64 bytes, bool isDirectory)
{
    if (isDirectory) {
        return QStringLiteral("--");
    }
    const qint64 KB = 1024;
    const qint64 MB = 1024 * KB;
    const qint64 GB = 1024 * MB;

    if (bytes >= GB) {
        return QString::number(static_cast<double>(bytes) / GB, 'f', 1) + QStringLiteral(" GB");
    } else if (bytes >= MB) {
        return QString::number(static_cast<double>(bytes) / MB, 'f', 1) + QStringLiteral(" MB");
    } else if (bytes >= KB) {
        return QString::number(static_cast<double>(bytes) / KB, 'f', 1) + QStringLiteral(" KB");
    } else {
        return QString::number(bytes) + QStringLiteral(" B");
    }
}

QString FileItem::detectMimeType(const QString &filePath)
{
    QMimeDatabase db;
    QMimeType mime = db.mimeTypeForFile(filePath, QMimeDatabase::MatchDefault);
    if (mime.isValid()) {
        return mime.name();
    }
    return QStringLiteral("application/octet-stream");
}

QString FileItem::resolveIconName(const QString &mimeType, bool isDir, bool isAppBundle)
{
    if (isAppBundle) {
        return QStringLiteral("application-x-executable");
    }
    if (isDir) {
        return QStringLiteral("folder");
    }
    if (mimeType.startsWith("image/")) {
        return QStringLiteral("image-x-generic");
    }
    if (mimeType.startsWith("video/")) {
        return QStringLiteral("video-x-generic");
    }
    if (mimeType.startsWith("audio/")) {
        return QStringLiteral("audio-x-generic");
    }
    if (mimeType == "application/pdf") {
        return QStringLiteral("application-pdf");
    }
    if (mimeType.startsWith("text/") || mimeType.contains("json") || mimeType.contains("xml") || mimeType.contains("toml")) {
        return QStringLiteral("text-x-generic");
    }
    if (mimeType.contains("archive") || mimeType.contains("tar") || mimeType.contains("zip") || mimeType.contains("gzip")) {
        return QStringLiteral("package-x-generic");
    }
    return QStringLiteral("text-x-generic");
}

FileItem FileItem::fromPath(const QString &filePath)
{
    FileItem item;
    QFileInfo info(filePath);
    item.path = info.absoluteFilePath();
    item.name = info.fileName();
    item.isSymlink = info.isSymLink();
    item.isDir = info.isDir();
    item.isHidden = info.isHidden();
    item.sizeBytes = item.isDir ? 0 : info.size();
    item.sizeFormatted = formatSize(item.sizeBytes, item.isDir);
    item.modifiedTimestamp = info.lastModified().toSecsSinceEpoch();
    item.modifiedFormatted = info.lastModified().toString("yyyy-MM-dd HH:mm");

    // Check for .app bundle
    if (item.isDir && item.name.endsWith(".app")) {
        QString infoTomlPath = item.path + "/Contents/Info.toml";
        QString infoPlistPath = item.path + "/Contents/Info.plist";
        bool validBundle = false;

        if (QFile::exists(infoTomlPath)) {
            QFile tomlFile(infoTomlPath);
            if (tomlFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
                QString content = QString::fromUtf8(tomlFile.readAll());
                // Extract simple TOML key-values
                QRegularExpression idRx(R"(id\s*=\s*["']([^"']+)["'])");
                QRegularExpression nameRx(R"(name\s*=\s*["']([^"']+)["'])");
                QRegularExpression execRx(R"(executable\s*=\s*["']([^"']+)["'])");
                QRegularExpression iconRx(R"(icon\s*=\s*["']([^"']+)["'])");

                auto idMatch = idRx.match(content);
                auto nameMatch = nameRx.match(content);
                auto execMatch = execRx.match(content);
                auto iconMatch = iconRx.match(content);

                if (idMatch.hasMatch()) item.bundleId = idMatch.captured(1);
                if (nameMatch.hasMatch()) item.bundleName = nameMatch.captured(1);
                if (execMatch.hasMatch()) {
                    QString relExec = execMatch.captured(1);
                    QString fullExec = item.path + "/" + relExec;
                    if (QFile::exists(fullExec)) {
                        item.bundleExecutable = fullExec;
                        validBundle = true;
                    }
                }
                if (iconMatch.hasMatch()) {
                    QString iconVal = iconMatch.captured(1);
                    QString resIcon = item.path + "/Contents/Resources/" + iconVal;
                    if (QFile::exists(resIcon)) {
                        item.bundleIcon = resIcon;
                    }
                }
            }
        } else if (QFile::exists(infoPlistPath)) {
            QFile plistFile(infoPlistPath);
            if (plistFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
                QString content = QString::fromUtf8(plistFile.readAll());
                QRegularExpression idRx(R"(<key>CFBundleIdentifier</key>\s*<string>([^<]+)</string>)");
                QRegularExpression nameRx(R"(<key>CFBundleName</key>\s*<string>([^<]+)</string>)");
                QRegularExpression execRx(R"(<key>CFBundleExecutable</key>\s*<string>([^<]+)</string>)");

                auto idMatch = idRx.match(content);
                auto nameMatch = nameRx.match(content);
                auto execMatch = execRx.match(content);

                if (idMatch.hasMatch()) item.bundleId = idMatch.captured(1);
                if (nameMatch.hasMatch()) item.bundleName = nameMatch.captured(1);
                if (execMatch.hasMatch()) {
                    QString fullExec = item.path + "/Contents/MacOS/" + execMatch.captured(1);
                    if (QFile::exists(fullExec)) {
                        item.bundleExecutable = fullExec;
                        validBundle = true;
                    }
                }
            }
        }

        if (validBundle) {
            item.isAppBundle = true;
            item.canShowPackageContents = true;
            item.mimeType = QStringLiteral("application/x-conjunction-app");

            // Look for fallback icon in Contents/Resources
            if (item.bundleIcon.isEmpty()) {
                const QStringList candidateIcons = {
                    "icon.png", "icon.svg", "AppIcon.png", "AppIcon.svg"
                };
                for (const QString &cand : candidateIcons) {
                    QString p = item.path + "/Contents/Resources/" + cand;
                    if (QFile::exists(p)) {
                        item.bundleIcon = p;
                        break;
                    }
                }
            }
        }
    }

    if (!item.isAppBundle) {
        if (item.isDir) {
            item.mimeType = QStringLiteral("inode/directory");
        } else {
            item.mimeType = detectMimeType(item.path);
        }
    }

    item.iconName = resolveIconName(item.mimeType, item.isDir, item.isAppBundle);
    return item;
}

QVariantMap FileItem::toMap() const
{
    QVariantMap map;
    map["name"] = name;
    map["path"] = path;
    map["sizeFormatted"] = sizeFormatted;
    map["sizeBytes"] = sizeBytes;
    map["modifiedFormatted"] = modifiedFormatted;
    map["modifiedTimestamp"] = modifiedTimestamp;
    map["isDir"] = isDir;
    map["isAppBundle"] = isAppBundle;
    map["isSymlink"] = isSymlink;
    map["isHidden"] = isHidden;
    map["bundleId"] = bundleId;
    map["bundleName"] = bundleName;
    map["bundleIcon"] = bundleIcon;
    map["bundleExecutable"] = bundleExecutable;
    map["mimeType"] = mimeType;
    map["iconName"] = iconName;
    map["canShowPackageContents"] = canShowPackageContents;
    return map;
}
