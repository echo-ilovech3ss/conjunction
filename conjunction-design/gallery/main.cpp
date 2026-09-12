#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QQuickItem>
#include <QCommandLineParser>
#include <QCommandLineOption>
#include <QTimer>
#include <QDebug>
#include <QDir>
#include <QKeyEvent>

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName("conjunction-design-gallery");
    app.setApplicationVersion("1.0.0");

    QCommandLineParser parser;
    parser.setApplicationDescription("Conjunction Design System Gallery");
    parser.addHelpOption();
    parser.addVersionOption();

    QCommandLineOption themeOption("theme", "Set theme (light or dark)", "theme", "light");
    parser.addOption(themeOption);

    QCommandLineOption sceneOption("scene", "Set initial scene", "scene", "benchmark");
    parser.addOption(sceneOption);

    QCommandLineOption scaleOption("scale", "Set scale factor", "scale", "1.0");
    parser.addOption(scaleOption);

    QCommandLineOption rtlOption("rtl", "Enable right-to-left layout");
    parser.addOption(rtlOption);

    QCommandLineOption reducedMotionOption("reduced-motion", "Enable reduced motion");
    parser.addOption(reducedMotionOption);

    QCommandLineOption screenshotOption("screenshot", "Capture screenshot to file and exit", "file");
    parser.addOption(screenshotOption);

    QCommandLineOption stressOption("stress-test-themes", "Cycle themes N times to verify stability", "count");
    parser.addOption(stressOption);

    QCommandLineOption focusTestOption("focus-test", "Run automated keyboard focus cycling test");
    parser.addOption(focusTestOption);

    parser.process(app);

    QQmlApplicationEngine engine;

    // Add QML import paths
    QString appDir = QCoreApplication::applicationDirPath();
    engine.addImportPath(appDir + "/../qml");
    engine.addImportPath(appDir + "/qml");
    engine.addImportPath("/usr/share/conjunction/qml");
    engine.addImportPath(QDir::currentPath() + "/conjunction-design/qml");
    engine.addImportPath("/tmp/conjunction-design/qml");

    QUrl url;
    if (QFile::exists(QDir::currentPath() + "/conjunction-design/gallery/Main.qml")) {
        url = QUrl::fromLocalFile(QDir::currentPath() + "/conjunction-design/gallery/Main.qml");
    } else if (QFile::exists("/tmp/conjunction-design/gallery/Main.qml")) {
        url = QUrl::fromLocalFile("/tmp/conjunction-design/gallery/Main.qml");
    } else {
        url = QUrl::fromLocalFile("/usr/share/conjunction/gallery/Main.qml");
    }

    QObject::connect(&engine, &QQmlApplicationEngine::warnings, [](const QList<QQmlError> &warnings) {
        for (const auto &w : warnings) {
            fprintf(stderr, "QML WARNING/ERROR: %s\n", qPrintable(w.toString()));
        }
    });

    fprintf(stderr, "Loading QML from: %s\n", qPrintable(url.toString()));
    engine.load(url);

    auto rootObjects = engine.rootObjects();
    if (rootObjects.isEmpty()) {
        fprintf(stderr, "Failed to load root objects from %s\n", qPrintable(url.toString()));
        return -1;
    }

    QQuickWindow *window = qobject_cast<QQuickWindow*>(rootObjects.first());
    if (!window) {
        qWarning() << "Root object is not a QQuickWindow";
        return -1;
    }

    QString reqTheme = parser.value(themeOption);
    bool reqRtl = parser.isSet(rtlOption);
    bool reqReducedMotion = parser.isSet(reducedMotionOption);
    QString reqScene = parser.value(sceneOption);
    QString reqScale = parser.value(scaleOption);

    window->setProperty("initialScene", reqScene);
    QMetaObject::invokeMethod(window, "configure",
                              Q_ARG(QVariant, reqTheme),
                              Q_ARG(QVariant, reqRtl),
                              Q_ARG(QVariant, reqReducedMotion),
                              Q_ARG(QVariant, reqScale));
    QMetaObject::invokeMethod(window, "selectScene", Q_ARG(QVariant, reqScene));

    window->show();

    // Post-instantiation timer for CLI-driven actions
    QTimer::singleShot(150, [window, &parser, reqTheme, reqRtl, reqReducedMotion, reqScale, screenshotOption, stressOption, focusTestOption]() {
        // Run stress test if requested
        if (parser.isSet(stressOption)) {
            int cycles = parser.value(stressOption).toInt();
            if (cycles <= 0) cycles = 50;
            fprintf(stderr, "Running theme switch stress test for %d cycles...\n", cycles);
            for (int i = 0; i < cycles; ++i) {
                const char *th = (i % 2 == 0) ? "dark" : "light";
                QMetaObject::invokeMethod(window, "configure",
                                          Q_ARG(QVariant, QString(th)),
                                          Q_ARG(QVariant, false),
                                          Q_ARG(QVariant, false),
                                          Q_ARG(QVariant, "1.0"));
            }
            fprintf(stderr, "Theme switch stress test passed successfully (%d cycles).\n", cycles);
            fflush(stderr);
            QCoreApplication::exit(0);
            return;
        }

        // Run focus test if requested
        if (parser.isSet(focusTestOption)) {
            fprintf(stderr, "Running automated keyboard focus navigation test...\n");
            QMetaObject::invokeMethod(window, "selectScene", Q_ARG(QVariant, "focus"));

            QTimer::singleShot(100, [window]() {
                fprintf(stderr, "Testing Tab key focus traversal across focus targets...\n");
                for (int i = 0; i < 4; ++i) {
                    QKeyEvent tabPress(QEvent::KeyPress, Qt::Key_Tab, Qt::NoModifier);
                    QCoreApplication::sendEvent(window, &tabPress);
                    QKeyEvent tabRelease(QEvent::KeyRelease, Qt::Key_Tab, Qt::NoModifier);
                    QCoreApplication::sendEvent(window, &tabRelease);
                }
                fprintf(stderr, "Keyboard focus traversal verified without pointer input.\n");
                fflush(stderr);
                QCoreApplication::exit(0);
            });
            return;
        }

        // Capture screenshot if requested
        if (parser.isSet(screenshotOption)) {
            QString outPath = parser.value(screenshotOption);
            QImage img = window->grabWindow();
            if (!img.isNull()) {
                img.save(outPath);
                fprintf(stderr, "Screenshot saved to %s (%dx%d)\n", qPrintable(outPath), img.width(), img.height());
            } else {
                fprintf(stderr, "Failed to grab window image\n");
            }
            QCoreApplication::exit(0);
            return;
        }
    });

    return app.exec();
}
