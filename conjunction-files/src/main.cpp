#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QCommandLineParser>
#include <QTimer>
#include <QDir>
#include <QDebug>
#include <QImage>

#include "files_model.h"
#include "sidebar_model.h"
#include "column_model.h"
#include "file_operations.h"
#include "quicklook_service.h"

#include <QQuickImageProvider>
#include <QIcon>
#include <QPainter>

class IconImageProvider : public QQuickImageProvider {
public:
    IconImageProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}

    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override {
        int w = requestedSize.width() > 0 ? requestedSize.width() : 48;
        int h = requestedSize.height() > 0 ? requestedSize.height() : 48;
        if (size) *size = QSize(w, h);

        QIcon icon = QIcon::fromTheme(id);
        if (!icon.isNull()) {
            QPixmap px = icon.pixmap(w, h);
            if (!px.isNull()) return px;
        }

        // Clean fallback icon drawing
        QPixmap pixmap(w, h);
        pixmap.fill(Qt::transparent);
        QPainter p(&pixmap);
        p.setRenderHint(QPainter::Antialiasing);

        if (id.contains("folder")) {
            p.setBrush(QColor("#007AFF"));
            p.setPen(Qt::NoPen);
            p.drawRoundedRect(4, 8, w - 8, h - 16, 4, 4);
        } else if (id.contains("executable") || id.contains("app")) {
            p.setBrush(QColor("#5856D6"));
            p.setPen(Qt::NoPen);
            p.drawRoundedRect(6, 6, w - 12, h - 12, 8, 8);
        } else {
            p.setBrush(QColor("#8E8E93"));
            p.setPen(Qt::NoPen);
            p.drawRoundedRect(8, 4, w - 16, h - 8, 3, 3);
        }
        return pixmap;
    }
};

int main(int argc, char *argv[])
{
    QGuiApplication::setApplicationName("conjunction-files");
    QGuiApplication::setOrganizationName("Conjunction");

    // Command line options parsing before QGuiApplication if scaling requested
    for (int i = 1; i < argc; ++i) {
        if (QString(argv[i]) == "--scale" && i + 1 < argc) {
            qputenv("QT_SCALE_FACTOR", argv[i + 1]);
        }
    }

    QGuiApplication app(argc, argv);

    QCommandLineParser parser;
    parser.setApplicationDescription("Conjunction Files - Modern Filesystem Explorer");
    parser.addHelpOption();
    parser.addVersionOption();

    QCommandLineOption pathOption("path", "Initial folder path to open", "directory", QDir::homePath());
    QCommandLineOption viewOption("view", "View mode: icon, list, or column", "mode", "icon");
    QCommandLineOption quicklookOption("quicklook", "Open Quick Look preview on target file", "file");
    QCommandLineOption getInfoOption("get-info", "Open Get Info dialog on target file", "file");
    QCommandLineOption screenshotOption("screenshot", "Capture window to PNG file and exit", "file");
    QCommandLineOption darkOption("dark", "Force dark theme");
    QCommandLineOption lightOption("light", "Force light theme");
    QCommandLineOption testModeOption("test-mode", "Run automated files acceptance self-test");
    QCommandLineOption timeoutOption("timeout", "Exit after ms", "ms");

    parser.addOption(pathOption);
    parser.addOption(viewOption);
    parser.addOption(quicklookOption);
    parser.addOption(getInfoOption);
    parser.addOption(screenshotOption);
    parser.addOption(darkOption);
    parser.addOption(lightOption);
    parser.addOption(testModeOption);
    parser.addOption(timeoutOption);
    parser.process(app);

    QString initialPath = parser.value(pathOption);
    if (!QFileInfo::exists(initialPath)) {
        initialPath = QDir::homePath();
    }

    auto *filesModel = new FilesModel(&app);
    filesModel->setPath(initialPath);

    auto *sidebarModel = new SidebarModel(&app);
    auto *columnModel = new ColumnBrowserModel(&app);
    columnModel->resetToPath(initialPath);

    auto *fileOps = new FileOperations(&app);
    auto *quickLook = new QuickLookService(&app);

    QObject::connect(fileOps, &FileOperations::directoryChanged, filesModel, [filesModel](const QString &dir) {
        if (filesModel->currentPath() == dir) {
            filesModel->refresh();
        }
    });

    qmlRegisterType<FilesModel>("Conjunction.Files", 1, 0, "FilesModel");

    QQmlApplicationEngine engine;
    engine.addImageProvider("icon", new IconImageProvider());

    // Search paths for QML modules (Conjunction.Design and Conjunction.Controls)
    QString appDir = QCoreApplication::applicationDirPath();
    engine.addImportPath(appDir + "/../share/conjunction/qml");
    engine.addImportPath(appDir + "/../../conjunction-design/qml");
    engine.addImportPath("/usr/share/conjunction/qml");
    engine.addImportPath("/usr/lib/qt6/qml");

    bool isDark = true;
    if (parser.isSet(lightOption)) isDark = false;
    else if (parser.isSet(darkOption)) isDark = true;

    engine.rootContext()->setContextProperty("FilesModel", filesModel);
    engine.rootContext()->setContextProperty("SidebarModel", sidebarModel);
    engine.rootContext()->setContextProperty("ColumnModel", columnModel);
    engine.rootContext()->setContextProperty("FileOps", fileOps);
    engine.rootContext()->setContextProperty("QuickLook", quickLook);
    engine.rootContext()->setContextProperty("initialViewMode", parser.value(viewOption));
    engine.rootContext()->setContextProperty("isDarkTheme", isDark);
    engine.rootContext()->setContextProperty("cliQuickLookTarget", parser.value(quicklookOption));
    engine.rootContext()->setContextProperty("cliGetInfoTarget", parser.value(getInfoOption));

    QString qmlFile = appDir + "/../share/conjunction/files/FilesWindow.qml";
    if (!QFile::exists(qmlFile)) {
        qmlFile = "/usr/share/conjunction/files/FilesWindow.qml";
    }
    if (!QFile::exists(qmlFile)) {
        qmlFile = appDir + "/../qml/FilesWindow.qml";
    }
    if (!QFile::exists(qmlFile)) {
        qmlFile = QDir::currentPath() + "/conjunction-files/qml/FilesWindow.qml";
    }
    if (!QFile::exists(qmlFile)) {
        qmlFile = "/mnt/c/Users/Way4U/Coding-projects/conjunction/conjunction-files/qml/FilesWindow.qml";
    }

    qInfo() << "[conjunction-files] Loading Files QML:" << qmlFile;
    engine.load(QUrl::fromLocalFile(qmlFile));

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "[conjunction-files] Failed to load QML root object from" << qmlFile;
        return 1;
    }

    auto *window = qobject_cast<QQuickWindow*>(engine.rootObjects().first());

    if (parser.isSet(screenshotOption)) {
        QString outPath = parser.value(screenshotOption);
        QTimer::singleShot(600, [window, outPath]() {
            if (window) {
                QImage img = window->grabWindow();
                if (img.save(outPath)) {
                    qInfo() << "[conjunction-files] Saved screenshot to:" << outPath << "(" << img.width() << "x" << img.height() << ")";
                } else {
                    qWarning() << "[conjunction-files] Failed to save screenshot to:" << outPath;
                }
            }
            QGuiApplication::quit();
        });
    }

    if (parser.isSet(timeoutOption)) {
        int ms = parser.value(timeoutOption).toInt();
        if (ms > 0) {
            QTimer::singleShot(ms, &app, &QGuiApplication::quit);
        }
    }

    return app.exec();
}
