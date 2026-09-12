#include "sidebar_model.h"
#include <QDir>
#include <QStandardPaths>

SidebarModel::SidebarModel(QObject *parent)
    : QAbstractListModel(parent)
{
    populate();
}

int SidebarModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_items.count();
}

QVariant SidebarModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.count())
        return QVariant();

    const SidebarItem &item = m_items.at(index.row());
    switch (role) {
    case NameRole: return item.name;
    case PathRole: return item.path;
    case IconNameRole: return item.iconName;
    case SectionRole: return item.section;
    case IsTrashRole: return item.isTrash;
    default: return QVariant();
    }
}

QHash<int, QByteArray> SidebarModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[NameRole] = "name";
    roles[PathRole] = "path";
    roles[IconNameRole] = "iconName";
    roles[SectionRole] = "section";
    roles[IsTrashRole] = "isTrash";
    return roles;
}

int SidebarModel::count() const
{
    return m_items.count();
}

QVariantMap SidebarModel::get(int index) const
{
    if (index >= 0 && index < m_items.count()) {
        const SidebarItem &item = m_items.at(index);
        QVariantMap map;
        map["name"] = item.name;
        map["path"] = item.path;
        map["iconName"] = item.iconName;
        map["section"] = item.section;
        map["isTrash"] = item.isTrash;
        return map;
    }
    return QVariantMap();
}

int SidebarModel::indexOfPath(const QString &path) const
{
    for (int i = 0; i < m_items.count(); ++i) {
        if (m_items.at(i).path == path) {
            return i;
        }
    }
    return -1;
}

void SidebarModel::refresh()
{
    beginResetModel();
    populate();
    endResetModel();
    emit countChanged();
}

void SidebarModel::populate()
{
    m_items.clear();

    QString home = QDir::homePath();
    QString desktop = QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);
    QString documents = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    QString downloads = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);

    // Applications folder
    QString appsPath = QStringLiteral("/Applications");
    if (!QDir(appsPath).exists()) {
        appsPath = home + QStringLiteral("/Applications");
        QDir().mkpath(appsPath);
    }

    // Standard Trash
    QString trashPath = home + QStringLiteral("/.local/share/Trash/files");
    QDir().mkpath(trashPath);

    // Favorites section
    m_items.append({QStringLiteral("Home"), home, QStringLiteral("user-home"), QStringLiteral("Favorites"), false});
    if (QDir(desktop).exists())
        m_items.append({QStringLiteral("Desktop"), desktop, QStringLiteral("user-desktop"), QStringLiteral("Favorites"), false});
    if (QDir(documents).exists())
        m_items.append({QStringLiteral("Documents"), documents, QStringLiteral("folder-documents"), QStringLiteral("Favorites"), false});
    if (QDir(downloads).exists())
        m_items.append({QStringLiteral("Downloads"), downloads, QStringLiteral("folder-download"), QStringLiteral("Favorites"), false});
    m_items.append({QStringLiteral("Applications"), appsPath, QStringLiteral("applications-other"), QStringLiteral("Favorites"), false});
    m_items.append({QStringLiteral("Trash"), trashPath, QStringLiteral("user-trash"), QStringLiteral("Favorites"), true});

    // Locations section
    m_items.append({QStringLiteral("Macintosh HD"), QStringLiteral("/"), QStringLiteral("drive-harddisk"), QStringLiteral("Locations"), false});

    // Removable media if mounted
    QString mediaRun = QStringLiteral("/run/media/") + qgetenv("USER");
    if (QDir(mediaRun).exists()) {
        QFileInfoList mounts = QDir(mediaRun).entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QFileInfo &m : mounts) {
            m_items.append({m.fileName(), m.absoluteFilePath(), QStringLiteral("media-removable"), QStringLiteral("Locations"), false});
        }
    }
}
