#pragma once

#include <QAbstractListModel>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include "file_item.h"

class FilesModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(QString currentPath READ currentPath WRITE setPath NOTIFY currentPathChanged)
    Q_PROPERTY(bool canGoBack READ canGoBack NOTIFY historyChanged)
    Q_PROPERTY(bool canGoForward READ canGoForward NOTIFY historyChanged)
    Q_PROPERTY(QVariantList pathComponents READ pathComponents NOTIFY currentPathChanged)
    Q_PROPERTY(bool showHidden READ showHidden WRITE setShowHidden NOTIFY showHiddenChanged)
    Q_PROPERTY(QString searchFilter READ searchFilter WRITE setSearchFilter NOTIFY searchFilterChanged)
    Q_PROPERTY(QString sortRole READ sortRole WRITE setSortRole NOTIFY sortChanged)
    Q_PROPERTY(int sortOrder READ sortOrder WRITE setSortOrder NOTIFY sortChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        PathRole,
        SizeRole,
        SizeBytesRole,
        ModifiedRole,
        ModifiedTimestampRole,
        IsDirRole,
        IsAppBundleRole,
        IsSymlinkRole,
        IsHiddenRole,
        BundleIdRole,
        BundleNameRole,
        BundleIconRole,
        MimeTypeRole,
        IconNameRole,
        CanShowPackageContentsRole
    };

    explicit FilesModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString currentPath() const;
    Q_INVOKABLE void setPath(const QString &path);

    bool canGoBack() const;
    bool canGoForward() const;
    QVariantList pathComponents() const;

    bool showHidden() const;
    void setShowHidden(bool show);

    QString searchFilter() const;
    void setSearchFilter(const QString &filter);

    QString sortRole() const;
    void setSortRole(const QString &role);

    int sortOrder() const;
    void setSortOrder(int order);

    int count() const;

    Q_INVOKABLE void cdUp();
    Q_INVOKABLE void cdInto(const QString &name);
    Q_INVOKABLE void goBack();
    Q_INVOKABLE void goForward();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE QVariantMap get(int index) const;
    Q_INVOKABLE int indexOfPath(const QString &path) const;
    Q_INVOKABLE void setSort(const QString &role, int order);

signals:
    void currentPathChanged();
    void historyChanged();
    void showHiddenChanged();
    void searchFilterChanged();
    void sortChanged();
    void countChanged();

private:
    void loadDirectory(const QString &path);
    void applyFilterAndSort();

    QString m_currentPath;
    QStringList m_history;
    int m_historyIndex = -1;

    QList<FileItem> m_allItems;
    QList<FileItem> m_filteredItems;

    bool m_showHidden = false;
    QString m_searchFilter;
    QString m_sortRole = QStringLiteral("name");
    int m_sortOrder = Qt::AscendingOrder;
};
