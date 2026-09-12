#include "quicklook_service.h"
#include "file_item.h"
#include <QDesktopServices>
#include <QUrl>
#include <QFile>
#include <QImageReader>
#include <QFileInfo>

QuickLookService::QuickLookService(QObject *parent)
    : QObject(parent)
{
}

bool QuickLookService::isImageMime(const QString &mime)
{
    return mime.startsWith("image/");
}

bool QuickLookService::isTextMime(const QString &mime, const QString &ext)
{
    if (mime.startsWith("text/") || mime.contains("json") || mime.contains("xml") ||
        mime.contains("toml") || mime.contains("yaml") || mime.contains("javascript")) {
        return true;
    }
    const QStringList codeExts = {
        "rs", "c", "h", "cpp", "hpp", "cc", "cxx", "py", "sh", "bash",
        "js", "ts", "qml", "toml", "json", "yaml", "yml", "conf", "ini", "md", "txt", "desktop"
    };
    return codeExts.contains(ext.toLower());
}

QVariantMap QuickLookService::inspect(const QString &filePath) const
{
    QVariantMap result;
    QFileInfo info(filePath);
    if (!info.exists()) {
        result["valid"] = false;
        return result;
    }

    result["valid"] = true;
    result["name"] = info.fileName();
    result["path"] = info.absoluteFilePath();
    result["fileUrl"] = QUrl::fromLocalFile(info.absoluteFilePath()).toString();

    FileItem item = FileItem::fromPath(filePath);
    result["sizeFormatted"] = item.sizeFormatted;
    result["sizeBytes"] = item.sizeBytes;
    result["modifiedFormatted"] = item.modifiedFormatted;
    result["mimeType"] = item.mimeType;
    result["isDir"] = item.isDir;
    result["isAppBundle"] = item.isAppBundle;

    QVariantMap metadata;
    metadata["Where"] = info.absolutePath();
    metadata["Size"] = item.sizeFormatted;
    metadata["Modified"] = item.modifiedFormatted;

    QString ext = info.suffix().toLower();

    if (item.isAppBundle) {
        result["previewType"] = QStringLiteral("app");
        result["bundleId"] = item.bundleId;
        result["bundleName"] = item.bundleName;
        result["bundleIcon"] = item.bundleIcon;
        result["bundleExecutable"] = item.bundleExecutable;

        metadata["Bundle Identifier"] = item.bundleId;
        metadata["Application Name"] = item.bundleName;
        if (!item.bundleExecutable.isEmpty()) {
            metadata["Executable"] = item.bundleExecutable;
        }
    } else if (item.isDir) {
        result["previewType"] = QStringLiteral("directory");
        metadata["Kind"] = QStringLiteral("Folder");
    } else if (isImageMime(item.mimeType) || ext == "png" || ext == "jpg" || ext == "jpeg" || ext == "svg" || ext == "webp") {
        result["previewType"] = QStringLiteral("image");
        metadata["Kind"] = QStringLiteral("Image (%1)").arg(item.mimeType);

        QImageReader reader(filePath);
        QSize size = reader.size();
        if (size.isValid()) {
            metadata["Dimensions"] = QStringLiteral("%1 × %2 pixels").arg(size.width()).arg(size.height());
            result["dimensions"] = QStringLiteral("%1 × %2").arg(size.width()).arg(size.height());
        }
    } else if (item.mimeType == "application/pdf" || ext == "pdf") {
        result["previewType"] = QStringLiteral("pdf");
        metadata["Kind"] = QStringLiteral("PDF Document");
    } else if (isTextMime(item.mimeType, ext)) {
        result["previewType"] = QStringLiteral("text");
        metadata["Kind"] = QStringLiteral("Text Document (%1)").arg(item.mimeType);

        QFile file(filePath);
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            // Read up to 64KB safely
            QByteArray chunk = file.read(65536);
            result["textContent"] = QString::fromUtf8(chunk);
            result["lineCount"] = chunk.count('\n') + 1;
        }
    } else {
        result["previewType"] = QStringLiteral("generic");
        metadata["Kind"] = QStringLiteral("Document (%1)").arg(item.mimeType);
    }

    result["metadata"] = metadata;
    return result;
}

void QuickLookService::openWithDefault(const QString &filePath) const
{
    QDesktopServices::openUrl(QUrl::fromLocalFile(filePath));
}
