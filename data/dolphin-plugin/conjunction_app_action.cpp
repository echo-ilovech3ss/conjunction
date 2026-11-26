#include "conjunction_app_action.h"

#include <KFileItem>
#include <KPluginFactory>

#include <QAction>
#include <QFileInfo>
#include <QIcon>
#include <QProcess>
#include <QWidget>

ConjunctionAppAction::ConjunctionAppAction(QObject *parent, const QVariantList &)
    : KAbstractFileItemActionPlugin(parent)
{
}

QList<QAction *> ConjunctionAppAction::actions(const KFileItemListProperties &fileItemInfos,
                                               QWidget *parentWidget)
{
    QList<QAction *> result;
    const KFileItemList items = fileItemInfos.items();
    if (items.size() != 1) {
        return result;
    }

    const KFileItem &item = items.first();
    const QString localPath = item.localPath();
    if (localPath.isEmpty()) {
        return result;
    }

    QObject *actionParent = parentWidget ? static_cast<QObject *>(parentWidget) : this;

    if (item.isDir() && localPath.endsWith(QStringLiteral(".app"))
        && QFileInfo::exists(localPath + QStringLiteral("/Contents/Info.toml"))) {
        auto *openAct = new QAction(QIcon::fromTheme(QStringLiteral("system-run")),
                                    QStringLiteral("Open Application"), actionParent);
        connect(openAct, &QAction::triggered, this, [localPath]() {
            QProcess::startDetached(QStringLiteral("conj-open"), {localPath});
        });
        result.append(openAct);

        auto *contentsAct = new QAction(QIcon::fromTheme(QStringLiteral("folder-open")),
                                        QStringLiteral("Show Package Contents"), actionParent);
        connect(contentsAct, &QAction::triggered, this, [localPath]() {
            QProcess::startDetached(QStringLiteral("dolphin"),
                                    {localPath + QStringLiteral("/Contents")});
        });
        result.append(contentsAct);
        return result;
    }

    if (item.isFile() && localPath.endsWith(QStringLiteral(".cdmg"))) {
        auto *mountAct = new QAction(QIcon::fromTheme(QStringLiteral("media-optical")),
                                     QStringLiteral("Mount Disk Image"), actionParent);
        connect(mountAct, &QAction::triggered, this, [localPath]() {
            QProcess::startDetached(QStringLiteral("conj-open"), {localPath});
        });
        result.append(mountAct);

        auto *ejectAct = new QAction(QIcon::fromTheme(QStringLiteral("media-eject")),
                                     QStringLiteral("Eject Disk Image"), actionParent);
        connect(ejectAct, &QAction::triggered, this, [localPath]() {
            QProcess::startDetached(QStringLiteral("conj-open"),
                                    {QStringLiteral("--eject"), localPath});
        });
        result.append(ejectAct);
        return result;
    }

    if (item.isDir() && QFileInfo::exists(localPath + QStringLiteral("/.VolumeMeta.toml"))) {
        auto *ejectAct = new QAction(QIcon::fromTheme(QStringLiteral("media-eject")),
                                     QStringLiteral("Eject Disk Image"), actionParent);
        connect(ejectAct, &QAction::triggered, this, [localPath]() {
            QProcess::startDetached(QStringLiteral("conj-open"),
                                    {QStringLiteral("--eject"), localPath});
        });
        result.append(ejectAct);
    }

    return result;
}

K_PLUGIN_CLASS_WITH_JSON(ConjunctionAppAction, "conjunction_app_action.json")

#include "conjunction_app_action.moc"
