#pragma once

#include <QAbstractListModel>
#include <QString>
#include <QList>
#include <QVariantMap>

struct SidebarItem {
    QString name;
    QString path;
    QString iconName;
    QString section; // "Favorites" or "Locations"
    bool isTrash = false;
};

class SidebarModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        PathRole,
        IconNameRole,
        SectionRole,
        IsTrashRole
    };

    explicit SidebarModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;
    Q_INVOKABLE QVariantMap get(int index) const;
    Q_INVOKABLE int indexOfPath(const QString &path) const;
    Q_INVOKABLE void refresh();

signals:
    void countChanged();

private:
    void populate();
    QList<SidebarItem> m_items;
};
