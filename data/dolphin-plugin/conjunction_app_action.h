#pragma once

#include <KAbstractFileItemActionPlugin>
#include <KFileItemListProperties>

class QAction;
class QWidget;

class ConjunctionAppAction : public KAbstractFileItemActionPlugin
{
    Q_OBJECT

public:
    ConjunctionAppAction(QObject *parent, const QVariantList &args);

    QList<QAction *> actions(const KFileItemListProperties &fileItemInfos,
                             QWidget *parentWidget) override;
};
