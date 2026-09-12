#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantMap>

class ColumnBrowserModel : public QObject {
    Q_OBJECT
    Q_PROPERTY(int columnCount READ columnCount NOTIFY columnsChanged)
    Q_PROPERTY(QStringList columnPaths READ columnPaths NOTIFY columnsChanged)
    Q_PROPERTY(QString previewPath READ previewPath NOTIFY previewChanged)
    Q_PROPERTY(bool hasPreview READ hasPreview NOTIFY previewChanged)
    Q_PROPERTY(QVariantMap previewData READ previewData NOTIFY previewChanged)

public:
    explicit ColumnBrowserModel(QObject *parent = nullptr);

    int columnCount() const;
    QStringList columnPaths() const;
    QString previewPath() const;
    bool hasPreview() const;
    QVariantMap previewData() const;

    Q_INVOKABLE void resetToPath(const QString &rootPath);
    Q_INVOKABLE void selectItem(int columnIndex, const QString &itemPath, bool isDir, bool isAppBundle);
    Q_INVOKABLE QString getColumnPath(int index) const;

signals:
    void columnsChanged();
    void previewChanged();

private:
    QStringList m_columnPaths;
    QString m_previewPath;
    QVariantMap m_previewData;
};
