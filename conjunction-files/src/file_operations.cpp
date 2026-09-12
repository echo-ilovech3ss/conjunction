#include "file_operations.h"
#include "file_item.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QDesktopServices>
#include <QUrl>
#include <QDebug>
#include <QStandardPaths>
#include <QRegularExpression>

#ifdef HAVE_KF6_KIO
#include <KIO/CopyJob>
#include <KIO/DeleteJob>
#include <KIO/Job>
#endif

FileOperations::FileOperations(QObject *parent)
    : QObject(parent)
{
}

bool FileOperations::openItem(const QString &filePath)
{
    QFileInfo info(filePath);
    if (!info.exists()) return false;

    FileItem item = FileItem::fromPath(filePath);

    // If it's a valid .app bundle, launch via conj-open or direct executable
    if (item.isAppBundle) {
        QString conjOpen = QStandardPaths::findExecutable("conj-open");
        if (!conjOpen.isEmpty()) {
            return QProcess::startDetached(conjOpen, QStringList() << filePath);
        } else if (!item.bundleExecutable.isEmpty()) {
            return QProcess::startDetached(item.bundleExecutable, QStringList());
        }
    }

    // Default desktop service opening
    return QDesktopServices::openUrl(QUrl::fromLocalFile(filePath));
}

bool FileOperations::openInTerminal(const QString &targetPath)
{
    QFileInfo info(targetPath);
    if (!info.exists()) {
        qWarning() << "[FileOperations] Target path does not exist for terminal:" << targetPath;
        return false;
    }

    QString dirPath = info.isDir() ? info.absoluteFilePath() : info.absolutePath();

    QString conjTerm = QStandardPaths::findExecutable("conjunction-terminal");
    if (conjTerm.isEmpty()) {
        conjTerm = QStringLiteral("/usr/bin/conjunction-terminal");
    }

    QStringList args;
    args << QStringLiteral("--working-directory") << dirPath;

    qInfo() << "[FileOperations] Launching terminal in directory:" << dirPath;
    return QProcess::startDetached(conjTerm, args);
}

QString FileOperations::openPackageContents(const QString &bundlePath)
{
    QFileInfo info(bundlePath);
    if (info.exists() && info.isDir()) {
        return info.absoluteFilePath();
    }
    return QString();
}

bool FileOperations::createFolder(const QString &parentPath, const QString &folderName)
{
    QDir dir(parentPath);
    if (!dir.exists()) return false;

    QString name = folderName.trimmed();
    if (name.isEmpty()) name = QStringLiteral("untitled folder");

    QString finalName = name;
    int counter = 2;
    while (dir.exists(finalName)) {
        finalName = QStringLiteral("%1 %2").arg(name).arg(counter++);
    }

    bool ok = dir.mkdir(finalName);
    if (ok) {
        emit directoryChanged(parentPath);
        emit operationFinished(true, QStringLiteral("Created '%1'").arg(finalName));
    }
    return ok;
}

bool FileOperations::renameItem(const QString &oldPath, const QString &newName)
{
    QFileInfo info(oldPath);
    if (!info.exists()) return false;

    QString trimmed = newName.trimmed();
    if (trimmed.isEmpty() || trimmed == info.fileName()) return true;

    QString newPath = info.dir().absoluteFilePath(trimmed);
    if (QFile::exists(newPath)) return false;

    bool ok = QFile::rename(oldPath, newPath);
    if (ok) {
        emit directoryChanged(info.dir().absolutePath());
        emit operationFinished(true, QStringLiteral("Renamed to '%1'").arg(trimmed));
    }
    return ok;
}

bool FileOperations::duplicateItem(const QString &path)
{
    QFileInfo info(path);
    if (!info.exists()) return false;

    QString dirPath = info.dir().absolutePath();
    QString base = info.completeBaseName();
    QString ext = info.suffix();
    if (!ext.isEmpty()) ext = "." + ext;

    QString destName = QStringLiteral("%1 copy%2").arg(base, ext);
    int counter = 2;
    while (QFile::exists(dirPath + "/" + destName)) {
        destName = QStringLiteral("%1 copy %2%3").arg(base).arg(counter++).arg(ext);
    }
    QString destPath = dirPath + "/" + destName;

    bool ok = false;
    if (info.isDir()) {
        // Recursive copy directory
        QProcess proc;
        proc.start("cp", QStringList() << "-r" << path << destPath);
        proc.waitForFinished();
        ok = (proc.exitCode() == 0);
    } else {
        ok = QFile::copy(path, destPath);
    }

    if (ok) {
        emit directoryChanged(dirPath);
        emit operationFinished(true, QStringLiteral("Duplicated '%1'").arg(info.fileName()));
    }
    return ok;
}

bool FileOperations::moveToTrash(const QStringList &paths)
{
    if (paths.isEmpty()) return false;

    QString home = QDir::homePath();
    QString trashDir = home + "/.local/share/Trash";
    QString filesDir = trashDir + "/files";
    QString infoDir = trashDir + "/info";

    QDir().mkpath(filesDir);
    QDir().mkpath(infoDir);

    bool allOk = true;
    QString parentDir;

    for (const QString &path : paths) {
        QFileInfo fi(path);
        if (!fi.exists()) continue;
        if (parentDir.isEmpty()) parentDir = fi.dir().absolutePath();

        QString baseName = fi.fileName();
        QString destName = baseName;
        int counter = 1;
        while (QFile::exists(filesDir + "/" + destName)) {
            destName = QStringLiteral("%1.%2").arg(baseName).arg(counter++);
        }

        QString destFile = filesDir + "/" + destName;
        QString destInfo = infoDir + "/" + destName + ".trashinfo";

        // Write .trashinfo metadata
        QFile infoFile(destInfo);
        if (infoFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QString dateStr = QDateTime::currentDateTime().toString(Qt::ISODate);
            QString content = QStringLiteral("[Trash Info]\nPath=%1\nDeletionDate=%2\n")
                                  .arg(fi.canonicalFilePath(), dateStr);
            infoFile.write(content.toUtf8());
            infoFile.close();
        }

        bool moved = QFile::rename(path, destFile);
        if (!moved) {
            // Fallback: copy and remove
            if (fi.isDir()) {
                QProcess p;
                p.start("cp", QStringList() << "-r" << path << destFile);
                p.waitForFinished();
                if (p.exitCode() == 0) {
                    QDir(path).removeRecursively();
                    moved = true;
                }
            } else {
                if (QFile::copy(path, destFile)) {
                    QFile::remove(path);
                    moved = true;
                }
            }
        }
        if (!moved) allOk = false;
    }

    if (!parentDir.isEmpty()) {
        emit directoryChanged(parentDir);
    }
    emit operationFinished(allOk, allOk ? QStringLiteral("Moved to Trash") : QStringLiteral("Failed to trash some items"));
    return allOk;
}

bool FileOperations::emptyTrash()
{
    QString home = QDir::homePath();
    QString trashDir = home + "/.local/share/Trash";
    QString filesDir = trashDir + "/files";
    QString infoDir = trashDir + "/info";

    QDir fDir(filesDir);
    if (fDir.exists()) {
        fDir.removeRecursively();
        QDir().mkpath(filesDir);
    }

    QDir iDir(infoDir);
    if (iDir.exists()) {
        iDir.removeRecursively();
        QDir().mkpath(infoDir);
    }

    emit operationFinished(true, QStringLiteral("Trash emptied"));
    return true;
}

bool FileOperations::copyItems(const QStringList &sources, const QString &destDir)
{
    if (sources.isEmpty() || !QDir(destDir).exists()) return false;

    bool allOk = true;
    for (const QString &src : sources) {
        QFileInfo fi(src);
        if (!fi.exists()) continue;

        QString target = destDir + "/" + fi.fileName();
        if (QFile::exists(target)) {
            // Duplicate name
            QString base = fi.completeBaseName();
            QString ext = fi.suffix();
            if (!ext.isEmpty()) ext = "." + ext;
            int counter = 2;
            while (QFile::exists(destDir + "/" + QStringLiteral("%1 %2%3").arg(base).arg(counter).arg(ext))) {
                counter++;
            }
            target = destDir + "/" + QStringLiteral("%1 %2%3").arg(base).arg(counter).arg(ext);
        }

        if (fi.isDir()) {
            QProcess p;
            p.start("cp", QStringList() << "-r" << src << target);
            p.waitForFinished();
            if (p.exitCode() != 0) allOk = false;
        } else {
            if (!QFile::copy(src, target)) allOk = false;
        }
    }

    emit directoryChanged(destDir);
    emit operationFinished(allOk, allOk ? QStringLiteral("Copied items") : QStringLiteral("Failed to copy some items"));
    return allOk;
}

bool FileOperations::moveItems(const QStringList &sources, const QString &destDir)
{
    if (sources.isEmpty() || !QDir(destDir).exists()) return false;

    bool allOk = true;
    QString sourceDir;
    for (const QString &src : sources) {
        QFileInfo fi(src);
        if (!fi.exists()) continue;
        if (sourceDir.isEmpty()) sourceDir = fi.dir().absolutePath();

        QString target = destDir + "/" + fi.fileName();
        if (!QFile::rename(src, target)) {
            allOk = false;
        }
    }

    if (!sourceDir.isEmpty()) emit directoryChanged(sourceDir);
    emit directoryChanged(destDir);
    emit operationFinished(allOk, allOk ? QStringLiteral("Moved items") : QStringLiteral("Failed to move some items"));
    return allOk;
}

void FileOperations::cleanApplicationData(const QString &appId)
{
    QString trimmed = appId.trimmed();
    if (trimmed.isEmpty() || trimmed != appId) return;
    if (appId.contains('/') || appId.contains('\\') || appId.contains("..")) return;

    static QRegularExpression safeIdRegex("^[a-zA-Z0-9_-]+(\\.[a-zA-Z0-9_-]+)+$");
    if (!safeIdRegex.match(appId).hasMatch()) return;

    QString home = QDir::homePath();
    QStringList targets = {
        home + "/.config/" + appId,
        home + "/.local/share/" + appId,
        home + "/.cache/" + appId,
        home + "/.conjunction/apps/" + appId + ".json",
        home + "/.var/app/" + appId
    };

    for (const QString &tgt : targets) {
        QFileInfo fi(tgt);
        if (fi.exists() || fi.isSymLink()) {
            if (fi.isSymLink()) {
                // If it is a symlink, delete only the link, never traverse
                QFile::remove(tgt);
            } else if (fi.isDir()) {
                QDir(tgt).removeRecursively();
            } else {
                QFile::remove(tgt);
            }
        }
    }
}

bool FileOperations::removeApplication(const QString &appPathOrId, bool removeData)
{
    QString idToUninstall = appPathOrId;
    QFileInfo info(appPathOrId);

    // If a path was passed, check if it's a .app bundle
    if (info.exists() && info.isDir()) {
        FileItem item = FileItem::fromPath(appPathOrId);
        if (item.isAppBundle && !item.bundleId.isEmpty()) {
            idToUninstall = item.bundleId;
        }
    }

    // Try conj-appctl uninstall
    QString conjAppctl = QStandardPaths::findExecutable("conj-appctl");
    bool success = false;

    if (!conjAppctl.isEmpty()) {
        QStringList args = { "uninstall", "--yes" };
        if (removeData) {
            args.append("--with-data");
        }
        args.append(idToUninstall);

        QProcess proc;
        proc.start(conjAppctl, args);
        proc.waitForFinished();
        success = (proc.exitCode() == 0);
    }

    // Fallback: if native bundle folder still exists, delete directly
    if (info.exists() && info.isDir()) {
        QDir(appPathOrId).removeRecursively();
        success = true;
    }

    if (removeData) {
        cleanApplicationData(idToUninstall);
    }

    emit operationFinished(success, success ? QStringLiteral("Application removed") : QStringLiteral("Failed to remove application"));
    return success;
}

QVariantMap FileOperations::getFileInfo(const QString &filePath)
{
    QVariantMap map;
    QFileInfo info(filePath);
    if (!info.exists()) return map;

    FileItem item = FileItem::fromPath(filePath);

    map["name"] = info.fileName();
    map["path"] = info.absoluteFilePath();
    map["dir"] = info.dir().absolutePath();
    map["isDir"] = item.isDir;
    map["isAppBundle"] = item.isAppBundle;
    map["sizeFormatted"] = item.sizeFormatted;
    map["sizeBytes"] = item.sizeBytes;
    map["created"] = info.birthTime().isValid() ? info.birthTime().toString("yyyy-MM-dd HH:mm") : info.lastModified().toString("yyyy-MM-dd HH:mm");
    map["modified"] = item.modifiedFormatted;
    map["mimeType"] = item.mimeType;
    map["owner"] = info.owner();
    map["group"] = info.group();
    map["isReadable"] = info.isReadable();
    map["isWritable"] = info.isWritable();
    map["isExecutable"] = info.isExecutable();

    if (item.isAppBundle) {
        map["bundleId"] = item.bundleId;
        map["bundleName"] = item.bundleName;
        map["bundleIcon"] = item.bundleIcon;
        map["bundleExecutable"] = item.bundleExecutable;
    }

    return map;
}
