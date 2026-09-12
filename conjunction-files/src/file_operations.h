#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantMap>

class FileOperations : public QObject {
    Q_OBJECT

public:
    explicit FileOperations(QObject *parent = nullptr);

    Q_INVOKABLE bool openItem(const QString &filePath);
    Q_INVOKABLE bool openInTerminal(const QString &targetPath);
    Q_INVOKABLE QString openPackageContents(const QString &bundlePath);
    Q_INVOKABLE bool createFolder(const QString &parentPath, const QString &folderName);
    Q_INVOKABLE bool renameItem(const QString &oldPath, const QString &newName);
    Q_INVOKABLE bool duplicateItem(const QString &path);
    Q_INVOKABLE bool moveToTrash(const QStringList &paths);
    Q_INVOKABLE bool emptyTrash();
    Q_INVOKABLE bool copyItems(const QStringList &sources, const QString &destDir);
    Q_INVOKABLE bool moveItems(const QStringList &sources, const QString &destDir);
    Q_INVOKABLE bool removeApplication(const QString &appPathOrId, bool removeData);
    Q_INVOKABLE QVariantMap getFileInfo(const QString &filePath);

signals:
    void operationFinished(bool success, const QString &message);
    void directoryChanged(const QString &path);

private:
    void cleanApplicationData(const QString &appId);
};
