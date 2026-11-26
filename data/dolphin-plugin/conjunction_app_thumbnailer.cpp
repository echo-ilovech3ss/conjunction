#include "conjunction_app_thumbnailer.h"

#include <KPluginFactory>

#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QRegularExpression>

ConjunctionAppThumbnailer::ConjunctionAppThumbnailer(QObject *parent, const QVariantList &args)
    : KIO::ThumbnailCreator(parent, args)
{
}

KIO::ThumbnailResult ConjunctionAppThumbnailer::create(const KIO::ThumbnailRequest &request)
{
    const QString bundleDir = request.url().toLocalFile();
    if (bundleDir.isEmpty() || !bundleDir.endsWith(QStringLiteral(".app"))) {
        return KIO::ThumbnailResult::fail();
    }

    const QString infoPath = bundleDir + QStringLiteral("/Contents/Info.toml");
    if (!QFileInfo::exists(infoPath)) {
        return KIO::ThumbnailResult::fail();
    }

    QString iconRel;
    QFile f(infoPath);
    if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QString content = QString::fromUtf8(f.readAll());
        QRegularExpression rx(QStringLiteral(R"(\bicon\s*=\s*["']([^"']+)["'])"));
        const auto match = rx.match(content);
        if (match.hasMatch()) {
            iconRel = match.captured(1);
        }
    }

    const QString canonBundle = QFileInfo(bundleDir).canonicalFilePath();
    QStringList candidates;
    if (!iconRel.isEmpty() && !iconRel.contains(QStringLiteral("..")) && !iconRel.startsWith(QLatin1Char('/'))) {
        candidates << (bundleDir + QLatin1Char('/') + iconRel)
                   << (bundleDir + QStringLiteral("/Contents/Resources/") + iconRel)
                   << (bundleDir + QStringLiteral("/Contents/Icons/") + iconRel);
    }
    candidates << (bundleDir + QStringLiteral("/Contents/Resources/icon.svg"))
               << (bundleDir + QStringLiteral("/Contents/Resources/icon.png"))
               << (bundleDir + QStringLiteral("/Contents/Resources/AppIcon.svg"))
               << (bundleDir + QStringLiteral("/Contents/Resources/AppIcon.png"));

    for (const QString &cand : std::as_const(candidates)) {
        const QFileInfo fi(cand);
        if (!fi.exists() || !fi.isFile()) {
            continue;
        }
        const QString canonTarget = fi.canonicalFilePath();
        if (!canonTarget.startsWith(canonBundle + QLatin1Char('/'))) {
            continue;
        }
        QImageReader reader(canonTarget);
        reader.setScaledSize(request.targetSize());
        QImage img = reader.read();
        if (!img.isNull()) {
            return KIO::ThumbnailResult::pass(img);
        }
    }

    return KIO::ThumbnailResult::fail();
}

K_PLUGIN_CLASS_WITH_JSON(ConjunctionAppThumbnailer, "conjunction_app_thumbnailer.json")

#include "conjunction_app_thumbnailer.moc"
