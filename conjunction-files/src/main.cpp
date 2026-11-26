#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QCommandLineParser>
#include <QTimer>
#include <QDir>
#include <QDebug>
#include <QImage>
#include <functional>
#include <memory>
#include "../../conjunction-design/common/overflow_audit.h"

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
    QCommandLineOption viewOption("view", "View mode: icon, list, column, or gallery", "mode", "icon");
    QCommandLineOption quicklookOption("quicklook", "Open Quick Look preview on target file", "file");
    QCommandLineOption getInfoOption("get-info", "Open Get Info dialog on target file", "file");
    QCommandLineOption screenshotOption("screenshot", "Capture window to PNG file and exit", "file");
    QCommandLineOption darkOption("dark", "Force dark theme");
    QCommandLineOption lightOption("light", "Force light theme");
    QCommandLineOption testModeOption("test-mode", "Run automated files acceptance self-test");
    QCommandLineOption timeoutOption("timeout", "Exit after ms", "ms");
    QCommandLineOption rtlOption("rtl", "Force right-to-left layout");
    QCommandLineOption fontScaleOption("font-scale", "UI typography scale", "scale", "1.0");
    QCommandLineOption widthOption("width", "Override initial window width", "px", "0");
    QCommandLineOption heightOption("height", "Override initial window height", "px", "0");
    QCommandLineOption stressModeOption("stress-mode", "Create and browse extreme-filename stress test directory");
    QCommandLineOption auditOverflowOption("audit-overflow", "Walk QML views and fail if any element or Text overflows");

    parser.addOption(pathOption);
    parser.addOption(viewOption);
    parser.addOption(quicklookOption);
    parser.addOption(getInfoOption);
    parser.addOption(screenshotOption);
    parser.addOption(darkOption);
    parser.addOption(lightOption);
    parser.addOption(testModeOption);
    parser.addOption(timeoutOption);
    parser.addOption(rtlOption);
    parser.addOption(fontScaleOption);
    parser.addOption(widthOption);
    parser.addOption(heightOption);
    parser.addOption(stressModeOption);
    parser.addOption(auditOverflowOption);
    parser.process(app);

    const bool reqRtl = parser.isSet(rtlOption) || qEnvironmentVariable("LANGUAGE").startsWith("ar") || app.isRightToLeft();
    if (reqRtl) {
        app.setLayoutDirection(Qt::RightToLeft);
    }

    QString initialPath = parser.value(pathOption);
    if (parser.isSet(stressModeOption) && !parser.isSet(pathOption)) {
        const QString stressDir = QDir::tempPath() + "/conjunction-stress-files";
        QDir().mkpath(stressDir);
        QDir().mkpath(stressDir + "/Donaudampfschifffahrtsgesellschaftskapitän_Vergleichsverzeichnis_80PlusChars");
        const QStringList files = {
            "Conjunction_UltraLong_Verification_Filename_Exceeding_Eighty_Characters_1234567890_End.txt",
            "Rindfleischetikettierungsüberwachungsaufgabenübertragungsgesetz_Document.md",
            "https%3A%2F%2Fconjunction.example.org%2Fvery%2Flong%2Funbroken%2Fresource%2Fidentifier.log"
        };
        for (const QString &fn : files) {
            QFile sf(stressDir + "/" + fn);
            if (sf.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
                sf.write("Conjunction overflow verification stress fixture.\n");
            }
        }
        initialPath = stressDir;
    }
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

    // Search paths for QML modules (prepend compiled .qsb dir LAST so it searches first)
    QString appDir = QCoreApplication::applicationDirPath();
    engine.addImportPath("/usr/lib/qt6/qml");
    engine.addImportPath("/usr/lib64/qt6/qml");
    engine.addImportPath("/work/conjunction-design/qml");
    engine.addImportPath(appDir + "/../../conjunction-design/qml");
    auto addCompiledImportPath = [&](const QString &p) {
        if (QFile::exists(p + "/Conjunction/Design/shaders/liquid_glass.frag.qsb")) {
            engine.addImportPath(p);
        }
    };
    addCompiledImportPath("/tmp/build-design/qml");
    addCompiledImportPath("/usr/share/conjunction/qml");
    addCompiledImportPath(appDir + "/../share/conjunction/qml");

    bool isDark = false;
    if (parser.isSet(lightOption)) isDark = false;
    else if (parser.isSet(darkOption)) isDark = true;

    engine.rootContext()->setContextProperty("FilesModel", filesModel);
    engine.rootContext()->setContextProperty("SidebarModel", sidebarModel);
    engine.rootContext()->setContextProperty("ColumnModel", columnModel);
    engine.rootContext()->setContextProperty("FileOps", fileOps);
    engine.rootContext()->setContextProperty("QuickLook", quickLook);
    engine.rootContext()->setContextProperty("initialViewMode", parser.value(viewOption) == "all" ? QString("icon") : parser.value(viewOption));
    engine.rootContext()->setContextProperty("isDarkTheme", isDark);
    engine.rootContext()->setContextProperty("cliQuickLookTarget", parser.value(quicklookOption));
    engine.rootContext()->setContextProperty("cliGetInfoTarget", parser.value(getInfoOption));
    engine.rootContext()->setContextProperty("initialRtl", reqRtl);
    engine.rootContext()->setContextProperty("initialFontScale", parser.value(fontScaleOption).toDouble());
    engine.rootContext()->setContextProperty("initialStressMode", parser.isSet(stressModeOption));
    engine.rootContext()->setContextProperty("initialWidth", parser.value(widthOption).toInt());
    engine.rootContext()->setContextProperty("initialHeight", parser.value(heightOption).toInt());

    QString qmlFile = appDir + "/../share/conjunction/files/FilesWindow.qml";
    if (!QFile::exists(qmlFile)) qmlFile = "/usr/share/conjunction/files/FilesWindow.qml";
    if (!QFile::exists(qmlFile)) qmlFile = appDir + "/../qml/FilesWindow.qml";
    if (!QFile::exists(qmlFile)) qmlFile = QDir::currentPath() + "/conjunction-files/qml/FilesWindow.qml";
    if (!QFile::exists(qmlFile)) qmlFile = "/work/conjunction-files/qml/FilesWindow.qml";

    qInfo() << "[conjunction-files] Loading Files QML:" << qmlFile;
    engine.load(QUrl::fromLocalFile(qmlFile));

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "[conjunction-files] Failed to load QML root object from" << qmlFile;
        return 1;
    }

    auto *window = qobject_cast<QQuickWindow*>(engine.rootObjects().first());

    if (parser.isSet(auditOverflowOption)) {
        const QString reqView = parser.value(viewOption);
        QStringList views = (reqView == QLatin1String("all"))
            ? QStringList{"icon", "list", "column", "gallery"}
            : QStringList{reqView};
        auto failures = std::make_shared<int>(0);
        auto runNext = std::make_shared<std::function<void(int)>>();
        const QString outPath = parser.value(screenshotOption);
        *runNext = [window, views, failures, runNext, outPath](int idx) {
            if (idx >= views.size()) {
                if (!outPath.isEmpty() && window) {
                    QImage img = window->grabWindow();
                    QDir().mkpath(QFileInfo(outPath).absolutePath());
                    img.save(outPath);
                }
                fprintf(stderr, "FILES_OVERFLOW_AUDIT views=%d failures=%d\n",
                        static_cast<int>(views.size()), *failures);
                QCoreApplication::exit(*failures == 0 ? 0 : 2);
                return;
            }
            const QString v = views.at(idx);
            if (window) QMetaObject::invokeMethod(window, "setViewModeByName", Q_ARG(QVariant, v));
            QTimer::singleShot(250, [window, v, idx, views, failures, runNext]() {
                if (window) {
                    const auto findings = Conjunction::OverflowAudit::auditWindow(window);
                    if (findings.isEmpty()) {
                        fprintf(stderr, "[OVERFLOW PASS] filesView=%s\n", qPrintable(v));
                    } else {
                        (*failures) += findings.size();
                        fprintf(stderr, "[OVERFLOW FAIL] filesView=%s findings=%d\n", qPrintable(v), static_cast<int>(findings.size()));
                        for (const auto &f : findings) {
                            fprintf(stderr, "  - %s | %s | %s\n", qPrintable(f.kind), qPrintable(f.itemDesc), qPrintable(f.detail));
                        }
                    }
                }
                (*runNext)(idx + 1);
            });
        };
        QTimer::singleShot(300, [runNext]() { (*runNext)(0); });
    } else if (parser.isSet(screenshotOption)) {
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
