#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QCommandLineParser>
#include <QTimer>
#include <QDir>
#include <QFile>
#include <QDebug>
#include <QImage>

#include "window_manager.h"
#include "menu_registrar.h"
#include "shell_state.h"

int main(int argc, char *argv[])
{
    QGuiApplication::setApplicationName("conj-shelld");
    QGuiApplication::setOrganizationName("Conjunction");

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
    QCommandLineOption reduceTransparencyOption("reduce-transparency", "Enable reduce transparency accessibility mode");
    QCommandLineOption increaseContrastOption("increase-contrast", "Enable increase contrast accessibility mode");
    QCommandLineOption notchOption("notch", "Enable 39 pt notched display menu bar height");
    QCommandLineOption testModeOption("test-mode", "Run automated shell acceptance self-test");
    QCommandLineOption scaleOption("scale", "UI scale factor (e.g. 1.5, 2.0)", "factor");
    QCommandLineOption timeoutOption("timeout", "Exit after ms", "ms");
    QCommandLineOption spotlightOption("spotlight", "Show Quick Search overlay with query", "query");
    QCommandLineOption appLauncherOption("app-launcher", "Show App Launcher overlay");
    QCommandLineOption appSwitcherOption("app-switcher", "Show App Switcher HUD overlay");
    QCommandLineOption quickNoteOption("quick-note", "Show Quick Note overlay");
    QCommandLineOption controlCenterOption("control-center", "Show Control Center drawer");
    QCommandLineOption overviewOption("overview", "Show Mission Control / Overview overlay");
    QCommandLineOption magnifyOption("magnify", "Enable dock magnification test");
    QCommandLineOption notifBannerOption("notification-banner", "Show simulated notification banner");
    QCommandLineOption notifCenterOption("notification-center", "Show notification center drawer");
    QCommandLineOption compositeOption("composite", "Force single-window composite shell view");
    QCommandLineOption layerShellOption("layer-shell", "Force Wayland LayerShell multi-window mode");

    parser.addOption(screenshotOption);
    parser.addOption(darkOption);
    parser.addOption(lightOption);
    parser.addOption(rtlOption);
    parser.addOption(reducedMotionOption);
    parser.addOption(reduceTransparencyOption);
    parser.addOption(increaseContrastOption);
    parser.addOption(notchOption);
    parser.addOption(testModeOption);
    parser.addOption(scaleOption);
    parser.addOption(timeoutOption);
    parser.addOption(spotlightOption);
    parser.addOption(appLauncherOption);
    parser.addOption(appSwitcherOption);
    parser.addOption(quickNoteOption);
    parser.addOption(controlCenterOption);
    parser.addOption(overviewOption);
    parser.addOption(magnifyOption);
    parser.addOption(notifBannerOption);
    parser.addOption(notifCenterOption);
    parser.addOption(compositeOption);
    parser.addOption(layerShellOption);
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

    const bool useLayerShell =
#ifdef HAVE_LAYERSHELLQT
        (parser.isSet(layerShellOption) ||
         (app.platformName().contains("wayland") && !parser.isSet(screenshotOption) && !parser.isSet(compositeOption)));
#else
        false;
#endif
    shellState->setLayerShellMode(useLayerShell);

    if (parser.isSet(darkOption)) {
        shellState->setIsDark(true);
    } else if (parser.isSet(lightOption)) {
        shellState->setIsDark(false);
    }
    if (parser.isSet(reducedMotionOption)) {
        shellState->setReducedMotion(true);
    }
    if (parser.isSet(reduceTransparencyOption)) {
        shellState->setReduceTransparency(true);
    }
    if (parser.isSet(increaseContrastOption)) {
        shellState->setIncreaseContrast(true);
    }
    if (parser.isSet(notchOption)) {
        shellState->setNotchBar(true);
    }
    if (parser.isSet(spotlightOption)) {
        shellState->setSpotlightVisible(true);
        QString q = parser.value(spotlightOption);
        shellState->setSearchQuery(!q.isEmpty() ? q : "Terminal");
    }
    if (parser.isSet(appLauncherOption)) {
        shellState->setAppLauncherVisible(true);
    }
    if (parser.isSet(appSwitcherOption)) {
        shellState->showAppSwitcher(false);
    }
    if (parser.isSet(quickNoteOption)) {
        shellState->setQuickNoteVisible(true);
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
    if (parser.isSet(notifBannerOption)) {
        shellState->simulateNotification(1, "Conjunction Update", "Desktop shell Liquid Glass build is ready.", "Utilities");
    }
    if (parser.isSet(notifCenterOption)) {
        shellState->simulateNotification(1, "Build Succeeded", "All integration modules built on Fedora 45.", "Terminal");
        shellState->simulateNotification(2, "Files", "Mounted TestImage.cdmg in Volumes.", "Files");
        shellState->setNotificationCenterVisible(true);
    }

    QQmlApplicationEngine engine;

    QString appDir = QCoreApplication::applicationDirPath();
    auto addCompiledImportPath = [&](const QString &p) {
        if (QFile::exists(p + "/Conjunction/Design/shaders/liquid_glass.frag.qsb")) {
            engine.addImportPath(p);
        }
    };
    addCompiledImportPath(appDir + "/../share/conjunction/qml");
    addCompiledImportPath("/usr/share/conjunction/qml");
    addCompiledImportPath("/tmp/build-design/qml");
    engine.addImportPath(appDir + "/../../conjunction-design/qml");
    engine.addImportPath("/work/conjunction-design/qml");
    engine.addImportPath("/usr/lib64/qt6/qml");
    engine.addImportPath("/usr/lib/qt6/qml");

    engine.rootContext()->setContextProperty("ShellState", shellState);
    engine.rootContext()->setContextProperty("isReducedMotion", parser.isSet(reducedMotionOption));

    QStringList candidates = {
        appDir + "/../share/conjunction/shell/ShellWindow.qml",
        "/usr/share/conjunction/shell/ShellWindow.qml",
        appDir + "/../qml/ShellWindow.qml",
        QDir::currentPath() + "/conj-shelld/qml/ShellWindow.qml",
        "/work/conj-shelld/qml/ShellWindow.qml"
    };
    QString qmlFile;
    for (const QString &cand : candidates) {
        if (QFile::exists(cand)) {
            qmlFile = cand;
            break;
        }
    }

    qInfo() << "[conj-shelld] Loading Shell QML:" << qmlFile << "(layerShell=" << useLayerShell << ")";
    engine.load(QUrl::fromLocalFile(qmlFile));

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "[conj-shelld] Failed to load QML root object from" << qmlFile;
        return 1;
    }

    auto *window = qobject_cast<QQuickWindow*>(engine.rootObjects().first());

    if (parser.isSet(testModeOption)) {
        qInfo() << "[conj-shelld] Running automated shell test mode...";
        shellState->simulateWindow("1001", "Documents — Files", "org.conjunction.files", true);
        shellState->simulateWindow("1002", "Conjunction Terminal — zsh", "org.conjunction.terminal", false);
        shellState->simulateMinimizedWindow("1003", "System Settings — Appearance", "org.conjunction.settings");

        QVariantList sampleMenu;
        QVariantMap fileMenu;
        fileMenu["id"] = 10;
        fileMenu["label"] = "File";
        QVariantList fileChildren;
        QVariantMap newAction;
        newAction["id"] = 11;
        newAction["label"] = "New Window";
        newAction["shortcut"] = "⌘N";
        newAction["enabled"] = true;
        fileChildren.append(newAction);
        QVariantMap openAction;
        openAction["id"] = 12;
        openAction["label"] = "Open Location...";
        openAction["shortcut"] = "⌘L";
        openAction["enabled"] = true;
        fileChildren.append(openAction);
        fileMenu["children"] = fileChildren;
        sampleMenu.append(fileMenu);

        for (const auto &lbl : QStringList{"Edit", "View", "Go", "Window", "Help"}) {
            QVariantMap m;
            m["id"] = 20 + sampleMenu.size() * 10;
            m["label"] = lbl;
            m["children"] = QVariantList();
            sampleMenu.append(m);
        }
        shellState->simulateGlobalMenu(sampleMenu);
    }

    if (parser.isSet(screenshotOption)) {
        QString outPath = parser.value(screenshotOption);
        int delay = parser.isSet(timeoutOption) ? parser.value(timeoutOption).toInt() : 650;
        QTimer::singleShot(delay, [window, outPath]() {
            if (window) {
                QImage img = window->grabWindow();
                QDir().mkpath(QFileInfo(outPath).absolutePath());
                if (img.save(outPath)) {
                    qInfo() << "[conj-shelld] Saved screenshot to:" << outPath << "(" << img.width() << "x" << img.height() << ")";
                } else {
                    qWarning() << "[conj-shelld] Failed to save screenshot to:" << outPath;
                }
            }
            std::exit(0);
        });
    } else if (parser.isSet(timeoutOption)) {
        int ms = parser.value(timeoutOption).toInt();
        if (ms > 0) {
            QTimer::singleShot(ms, []() {
                std::exit(0);
            });
        }
    }

    return app.exec();
}
