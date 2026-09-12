#include "column_model.h"
#include "file_item.h"
#include <QDir>
#include <QFileInfo>

ColumnBrowserModel::ColumnBrowserModel(QObject *parent)
    : QObject(parent)
{
    resetToPath(QDir::homePath());
}

int ColumnBrowserModel::columnCount() const
{
    return m_columnPaths.count();
}

QStringList ColumnBrowserModel::columnPaths() const
{
    return m_columnPaths;
}

QString ColumnBrowserModel::previewPath() const
{
    return m_previewPath;
}

bool ColumnBrowserModel::hasPreview() const
{
    return !m_previewPath.isEmpty();
}

QVariantMap ColumnBrowserModel::previewData() const
{
    return m_previewData;
}

void ColumnBrowserModel::resetToPath(const QString &rootPath)
{
    QString clean = QDir::cleanPath(rootPath);
    if (!QFileInfo::exists(clean)) return;

    m_columnPaths.clear();
    m_columnPaths.append(clean);
    m_previewPath.clear();
    m_previewData.clear();

    emit columnsChanged();
    emit previewChanged();
}

void ColumnBrowserModel::selectItem(int columnIndex, const QString &itemPath, bool isDir, bool isAppBundle)
{
    if (columnIndex < 0 || columnIndex >= m_columnPaths.size()) return;

    // Truncate columns beyond this selection
    while (m_columnPaths.size() > columnIndex + 1) {
        m_columnPaths.removeLast();
    }

    if (isDir && !isAppBundle) {
        m_previewPath.clear();
        m_previewData.clear();
        m_columnPaths.append(itemPath);
        emit columnsChanged();
        emit previewChanged();
    } else {
        m_previewPath = itemPath;
        FileItem item = FileItem::fromPath(itemPath);
        m_previewData = item.toMap();
        emit columnsChanged();
        emit previewChanged();
    }
}

QString ColumnBrowserModel::getColumnPath(int index) const
{
    return m_columnPaths.value(index);
}
