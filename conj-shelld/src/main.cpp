#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QCommandLineParser>
#include <QTimer>
#include <QDir>
#include <QDebug>
#include <QImage>

#include "window_manager.h"
#include "menu_registrar.h"
#include "shell_state.h"

int main(int argc, char *argv[])
{
    // High-DPI support
    QGuiApplication::setApplicationName("conj-shelld");
    QGuiApplication::setOrganizationName("Conjunction");

    // Command line options parsing before QGuiApplication if scaling requested
    for (int i = 1; i < argc; ++i) {
        if (QString(argv[i]) == "--scale" && i + 1 < argc) {
            qputenv("QT_SCALE_FACTOR", argv[i + 1]);
        }
    }

    QGuiApplication app(argc, argv);

    QCommandLineParser parser;
    parser.setApplicationDescription("Conjunction Desktop Shell Daemon");
    parser.addHelpOption();
    parser.addVersionOption();

    QCommandLineOption screenshotOption("screenshot", "Capture window to PNG file and exit", "file");
    QCommandLineOption darkOption("dark", "Force dark theme");
    QCommandLineOption lightOption("light", "Force light theme");
    QCommandLineOption rtlOption("rtl", "Force right-to-left layout");
    QCommandLineOption reducedMotionOption("reduced-motion", "Enable reduced motion");
    QCommandLineOption testModeOption("test-mode", "Run automated shell acceptance self-test");
    QCommandLineOption scaleOption("scale", "UI scale factor (e.g. 1.5, 2.0)", "factor");
    QCommandLineOption timeoutOption("timeout", "Exit after ms", "ms");
    QCommandLineOption spotlightOption("spotlight", "Show Spotlight search overlay with query", "query");
    QCommandLineOption controlCenterOption("control-center", "Show Control Center drawer");
    QCommandLineOption overviewOption("overview", "Show Mission Control / Overview overlay");
    QCommandLineOption magnifyOption("magnify", "Enable dock magnification test");

    parser.addOption(screenshotOption);
    parser.addOption(darkOption);
    parser.addOption(lightOption);
    parser.addOption(rtlOption);
    parser.addOption(reducedMotionOption);
    parser.addOption(testModeOption);
    parser.addOption(scaleOption);
    parser.addOption(timeoutOption);
    parser.addOption(spotlightOption);
    parser.addOption(controlCenterOption);
    parser.addOption(overviewOption);
    parser.addOption(magnifyOption);
    parser.process(app);

    if (parser.isSet(rtlOption)) {
        app.setLayoutDirection(Qt::RightToLeft);
    }

    auto *winMgr = new WindowManager(&app);
    winMgr->initDBus();

    auto *menuReg = new MenuRegistrar(&app);
    menuReg->initDBus();

    auto *shellState = new ShellState(winMgr, menuReg, &app);
    shellState->initDBus();

    if (parser.isSet(darkOption)) {
        shellState->setIsDark(true);
    } else if (parser.isSet(lightOption)) {
        shellState->setIsDark(false);
    }

    if (parser.isSet(spotlightOption)) {
        shellState->setSpotlightVisible(true);
        QString q = parser.value(spotlightOption);
        shellState->setSearchQuery(!q.isEmpty() ? q : "Fire");
    }
    if (parser.isSet(controlCenterOption)) {
        shellState->setControlCenterVisible(true);
    }
    if (parser.isSet(overviewOption)) {
        shellState->setOverviewActive(true);
    }
    if (parser.isSet(magnifyOption)) {
        shellState->setDockMagnification(true);
    }

    QQmlApplicationEngine engine;

    // Search paths for QML modules (Conjunction.Design and Conjunction.Controls)
    QString appDir = QCoreApplication::applicationDirPath();
    engine.addImportPath(appDir + "/../share/conjunction/qml");
    engine.addImportPath(appDir + "/../../conjunction-design/qml");
    engine.addImportPath("/usr/share/conjunction/qml");
    engine.addImportPath("/usr/lib/qt6/qml");

    engine.rootContext()->setContextProperty("ShellState", shellState);
    engine.rootContext()->setContextProperty("isReducedMotion", parser.isSet(reducedMotionOption));

    QString qmlFile = appDir + "/../share/conjunction/shell/ShellWindow.qml";
    if (!QFile::exists(qmlFile)) {
        qmlFile = "/usr/share/conjunction/shell/ShellWindow.qml";
    }
    if (!QFile::exists(qmlFile)) {
        qmlFile = appDir + "/../qml/ShellWindow.qml";
    }
    if (!QFile::exists(qmlFile)) {
        qmlFile = QDir::currentPath() + "/conj-shelld/qml/ShellWindow.qml";
    }
    if (!QFile::exists(qmlFile)) {
        qmlFile = "/mnt/c/Users/Way4U/Coding-projects/conjunction/conj-shelld/qml/ShellWindow.qml";
    }

    qInfo() << "[conj-shelld] Loading Shell QML:" << qmlFile;
    engine.load(QUrl::fromLocalFile(qmlFile));

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "[conj-shelld] Failed to load QML root object from" << qmlFile;
        return 1;
    }

    auto *window = qobject_cast<QQuickWindow*>(engine.rootObjects().first());

    if (parser.isSet(testModeOption)) {
        qInfo() << "[conj-shelld] Running automated shell test mode...";
        // Simulate reference app window with global menu
        shellState->simulateWindow("1001", "Desktop Reference", "dev.conjunction.reference", true);

        QVariantList sampleMenu;
        QVariantMap fileMenu;
        fileMenu["id"] = 10;
        fileMenu["label"] = "File";
        QVariantList fileChildren;
        QVariantMap newAction;
        newAction["id"] = 11;
        newAction["label"] = "New Window";
        newAction["enabled"] = true;
        fileChildren.append(newAction);
        QVariantMap markerAction;
        markerAction["id"] = 12;
        markerAction["label"] = "Create Test Marker";
        markerAction["enabled"] = true;
        fileChildren.append(markerAction);
        fileMenu["children"] = fileChildren;
        sampleMenu.append(fileMenu);

        QVariantMap editMenu;
        editMenu["id"] = 20;
        editMenu["label"] = "Edit";
        QVariantList editChildren;
        QVariantMap undoAction;
        undoAction["id"] = 21;
        undoAction["label"] = "Undo";
        undoAction["enabled"] = false;
        editChildren.append(undoAction);
        editMenu["children"] = editChildren;
        sampleMenu.append(editMenu);

        QVariantMap viewMenu;
        viewMenu["id"] = 30;
        viewMenu["label"] = "View";
        sampleMenu.append(viewMenu);

        QVariantMap windowMenu;
        windowMenu["id"] = 40;
        windowMenu["label"] = "Window";
        sampleMenu.append(windowMenu);

        QVariantMap helpMenu;
        helpMenu["id"] = 50;
        helpMenu["label"] = "Help";
        sampleMenu.append(helpMenu);

        shellState->simulateGlobalMenu(sampleMenu);

        // Add another window (Firefox)
        shellState->simulateWindow("1002", "Mozilla Firefox", "org.mozilla.firefox", false);
    }

    if (parser.isSet(screenshotOption)) {
        QString outPath = parser.value(screenshotOption);
        QTimer::singleShot(400, [window, outPath]() {
            if (window) {
                QImage img = window->grabWindow();
                if (img.save(outPath)) {
                    qInfo() << "[conj-shelld] Saved screenshot to:" << outPath << "(" << img.width() << "x" << img.height() << ")";
                } else {
                    qWarning() << "[conj-shelld] Failed to save screenshot to:" << outPath;
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
