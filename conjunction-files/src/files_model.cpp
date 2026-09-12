#include "files_model.h"
#include <QDir>
#include <QFileInfo>
#include <algorithm>

FilesModel::FilesModel(QObject *parent)
    : QAbstractListModel(parent)
{
    QString homePath = QDir::homePath();
    setPath(homePath);
}

int FilesModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_filteredItems.count();
}

QVariant FilesModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_filteredItems.count())
        return QVariant();

    const FileItem &item = m_filteredItems.at(index.row());

    switch (role) {
    case NameRole: return item.name;
    case PathRole: return item.path;
    case SizeRole: return item.sizeFormatted;
    case SizeBytesRole: return item.sizeBytes;
    case ModifiedRole: return item.modifiedFormatted;
    case ModifiedTimestampRole: return item.modifiedTimestamp;
    case IsDirRole: return item.isDir;
    case IsAppBundleRole: return item.isAppBundle;
    case IsSymlinkRole: return item.isSymlink;
    case IsHiddenRole: return item.isHidden;
    case BundleIdRole: return item.bundleId;
    case BundleNameRole: return item.bundleName;
    case BundleIconRole: return item.bundleIcon;
    case MimeTypeRole: return item.mimeType;
    case IconNameRole: return item.iconName;
    case CanShowPackageContentsRole: return item.canShowPackageContents;
    default: return QVariant();
    }
}

QHash<int, QByteArray> FilesModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[NameRole] = "name";
    roles[PathRole] = "path";
    roles[SizeRole] = "sizeFormatted";
    roles[SizeBytesRole] = "sizeBytes";
    roles[ModifiedRole] = "modifiedFormatted";
    roles[ModifiedTimestampRole] = "modifiedTimestamp";
    roles[IsDirRole] = "isDir";
    roles[IsAppBundleRole] = "isAppBundle";
    roles[IsSymlinkRole] = "isSymlink";
    roles[IsHiddenRole] = "isHidden";
    roles[BundleIdRole] = "bundleId";
    roles[BundleNameRole] = "bundleName";
    roles[BundleIconRole] = "bundleIcon";
    roles[MimeTypeRole] = "mimeType";
    roles[IconNameRole] = "iconName";
    roles[CanShowPackageContentsRole] = "canShowPackageContents";
    return roles;
}

QString FilesModel::currentPath() const
{
    return m_currentPath;
}

void FilesModel::setPath(const QString &path)
{
    QString clean = QDir::cleanPath(path);
    if (!QFileInfo::exists(clean)) return;

    if (m_currentPath != clean) {
        // Record in history if navigating forward
        if (m_historyIndex < 0 || m_history.value(m_historyIndex) != clean) {
            // Truncate forward history
            if (m_historyIndex >= 0 && m_historyIndex + 1 < m_history.size()) {
                m_history = m_history.mid(0, m_historyIndex + 1);
            }
            m_history.append(clean);
            m_historyIndex = m_history.size() - 1;
            emit historyChanged();
        }

        m_currentPath = clean;
        loadDirectory(clean);
        emit currentPathChanged();
    }
}

bool FilesModel::canGoBack() const
{
    return m_historyIndex > 0;
}

bool FilesModel::canGoForward() const
{
    return m_historyIndex >= 0 && m_historyIndex + 1 < m_history.size();
}

void FilesModel::goBack()
{
    if (canGoBack()) {
        m_historyIndex--;
        QString path = m_history.at(m_historyIndex);
        m_currentPath = path;
        loadDirectory(path);
        emit historyChanged();
        emit currentPathChanged();
    }
}

void FilesModel::goForward()
{
    if (canGoForward()) {
        m_historyIndex++;
        QString path = m_history.at(m_historyIndex);
        m_currentPath = path;
        loadDirectory(path);
        emit historyChanged();
        emit currentPathChanged();
    }
}

QVariantList FilesModel::pathComponents() const
{
    QVariantList list;
    if (m_currentPath.isEmpty()) return list;

    QString home = QDir::homePath();
    if (m_currentPath == home) {
        QVariantMap map;
        map["name"] = QStringLiteral("Home");
        map["path"] = home;
        list.append(map);
        return list;
    }

    QStringList parts = m_currentPath.split('/', Qt::SkipEmptyParts);
    QString accumulated;

    QVariantMap rootMap;
    rootMap["name"] = QStringLiteral("Macintosh HD");
    rootMap["path"] = QStringLiteral("/");
    list.append(rootMap);

    for (const QString &part : parts) {
        accumulated += "/" + part;
        QVariantMap partMap;
        partMap["name"] = part;
        partMap["path"] = accumulated;
        list.append(partMap);
    }

    return list;
}

bool FilesModel::showHidden() const
{
    return m_showHidden;
}

void FilesModel::setShowHidden(bool show)
{
    if (m_showHidden != show) {
        m_showHidden = show;
        emit showHiddenChanged();
        loadDirectory(m_currentPath);
    }
}

QString FilesModel::searchFilter() const
{
    return m_searchFilter;
}

void FilesModel::setSearchFilter(const QString &filter)
{
    if (m_searchFilter != filter) {
        m_searchFilter = filter;
        emit searchFilterChanged();
        applyFilterAndSort();
    }
}

QString FilesModel::sortRole() const
{
    return m_sortRole;
}

void FilesModel::setSortRole(const QString &role)
{
    if (m_sortRole != role) {
        m_sortRole = role;
        emit sortChanged();
        applyFilterAndSort();
    }
}

int FilesModel::sortOrder() const
{
    return m_sortOrder;
}

void FilesModel::setSortOrder(int order)
{
    if (m_sortOrder != order) {
        m_sortOrder = order;
        emit sortChanged();
        applyFilterAndSort();
    }
}

int FilesModel::count() const
{
    return m_filteredItems.count();
}

void FilesModel::cdUp()
{
    QDir dir(m_currentPath);
    if (dir.cdUp()) {
        setPath(dir.absolutePath());
    }
}

void FilesModel::cdInto(const QString &name)
{
    QDir dir(m_currentPath);
    QString newPath = dir.absoluteFilePath(name);
    if (QFileInfo(newPath).isDir()) {
        setPath(newPath);
    }
}

void FilesModel::refresh()
{
    loadDirectory(m_currentPath);
}

QVariantMap FilesModel::get(int index) const
{
    if (index >= 0 && index < m_filteredItems.count()) {
        return m_filteredItems.at(index).toMap();
    }
    return QVariantMap();
}

int FilesModel::indexOfPath(const QString &path) const
{
    for (int i = 0; i < m_filteredItems.count(); ++i) {
        if (m_filteredItems.at(i).path == path) {
            return i;
        }
    }
    return -1;
}

void FilesModel::setSort(const QString &role, int order)
{
    m_sortRole = role;
    m_sortOrder = order;
    emit sortChanged();
    applyFilterAndSort();
}

void FilesModel::loadDirectory(const QString &path)
{
    m_allItems.clear();

    QDir dir(path);
    QDir::Filters filters = QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot;
    if (m_showHidden) {
        filters |= QDir::Hidden;
    }

    QFileInfoList entries = dir.entryInfoList(filters, QDir::NoSort);
    for (const QFileInfo &entry : entries) {
        FileItem item = FileItem::fromPath(entry.absoluteFilePath());
        m_allItems.append(item);
    }

    applyFilterAndSort();
}

void FilesModel::applyFilterAndSort()
{
    beginResetModel();
    m_filteredItems.clear();

    QString query = m_searchFilter.trimmed().toLower();
    for (const FileItem &item : m_allItems) {
        if (!query.isEmpty() && !item.name.toLower().contains(query)) {
            continue;
        }
        m_filteredItems.append(item);
    }

    // Sort items: folders/bundles first, then files
    std::sort(m_filteredItems.begin(), m_filteredItems.end(), [this](const FileItem &a, const FileItem &b) {
        bool aIsFolderLike = a.isDir && !a.isAppBundle;
        bool bIsFolderLike = b.isDir && !b.isAppBundle;

        if (aIsFolderLike != bIsFolderLike) {
            return aIsFolderLike; // folder first
        }

        int cmp = 0;
        if (m_sortRole == QStringLiteral("date")) {
            if (a.modifiedTimestamp < b.modifiedTimestamp) cmp = -1;
            else if (a.modifiedTimestamp > b.modifiedTimestamp) cmp = 1;
        } else if (m_sortRole == QStringLiteral("size")) {
            if (a.sizeBytes < b.sizeBytes) cmp = -1;
            else if (a.sizeBytes > b.sizeBytes) cmp = 1;
        } else if (m_sortRole == QStringLiteral("kind")) {
            cmp = a.mimeType.compare(b.mimeType, Qt::CaseInsensitive);
        } else { // "name" default
            cmp = a.name.compare(b.name, Qt::CaseInsensitive);
        }

        if (cmp == 0) {
            cmp = a.name.compare(b.name, Qt::CaseInsensitive);
        }

        return m_sortOrder == Qt::AscendingOrder ? (cmp < 0) : (cmp > 0);
    });

    endResetModel();
    emit countChanged();
}
