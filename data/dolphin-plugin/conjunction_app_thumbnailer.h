#pragma once

#include <KIO/ThumbnailCreator>

class ConjunctionAppThumbnailer : public KIO::ThumbnailCreator
{
    Q_OBJECT

public:
    ConjunctionAppThumbnailer(QObject *parent, const QVariantList &args);

    KIO::ThumbnailResult create(const KIO::ThumbnailRequest &request) override;
};
