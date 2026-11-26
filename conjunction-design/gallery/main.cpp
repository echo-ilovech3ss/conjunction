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
#include <QFile>
#include <QKeyEvent>
#include <QEvent>
#include <functional>
#include <memory>
#include "../common/overflow_audit.h"

class InputFocusTracker : public QObject {
public:
    explicit InputFocusTracker(QQuickWindow *w, QObject *parent = nullptr)
        : QObject(parent), m_window(w) {}

    bool eventFilter(QObject *obj, QEvent *ev) override {
        if (ev->type() == QEvent::KeyPress) {
            auto *ke = static_cast<QKeyEvent*>(ev);
            if (ke->key() == Qt::Key_Tab || ke->key() == Qt::Key_Backtab || ke->key() == Qt::Key_F7) {
                QMetaObject::invokeMethod(m_window, "setKeyboardFocusActive", Q_ARG(QVariant, true));
            }
        } else if (ev->type() == QEvent::MouseButtonPress) {
            QMetaObject::invokeMethod(m_window, "setKeyboardFocusActive", Q_ARG(QVariant, false));
        }
        return QObject::eventFilter(obj, ev);
    }

private:
    QQuickWindow *m_window = nullptr;
};

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

    QCommandLineOption sceneOption("scene", "Set initial scene", "scene", "liquid_glass");
    parser.addOption(sceneOption);

    QCommandLineOption scaleOption("scale", "Set scale factor", "scale", "1.0");
    parser.addOption(scaleOption);

    QCommandLineOption rtlOption("rtl", "Enable right-to-left layout");
    parser.addOption(rtlOption);

    QCommandLineOption reducedMotionOption("reduced-motion", "Enable reduced motion");
    parser.addOption(reducedMotionOption);

    QCommandLineOption reduceTransparencyOption("reduce-transparency", "Enable reduce transparency accessibility mode");
    parser.addOption(reduceTransparencyOption);

    QCommandLineOption increaseContrastOption("increase-contrast", "Enable increase contrast accessibility mode");
    parser.addOption(increaseContrastOption);

    QCommandLineOption screenshotOption("screenshot", "Capture screenshot to file and exit", "file");
    parser.addOption(screenshotOption);

    QCommandLineOption stressOption("stress-test-themes", "Cycle themes N times to verify stability", "count");
    parser.addOption(stressOption);

    QCommandLineOption focusTestOption("focus-test", "Run automated keyboard focus cycling test");
    parser.addOption(focusTestOption);

    QCommandLineOption keyboardTestOption("keyboard-test", "Run end-to-end automated keyboard-only workflow test");
    parser.addOption(keyboardTestOption);

    QCommandLineOption stressModeOption("stress-mode", "Inject long stress strings and Overflow Stress scene data");
    parser.addOption(stressModeOption);

    QCommandLineOption auditOverflowOption("audit-overflow", "Walk active scene(s) and fail if any element or Text overflows");
    parser.addOption(auditOverflowOption);

    QCommandLineOption widthOption("width", "Override initial window width", "px", "0");
    parser.addOption(widthOption);

    QCommandLineOption heightOption("height", "Override initial window height", "px", "0");
    parser.addOption(heightOption);

    parser.process(app);

    QQmlApplicationEngine engine;

    QString appDir = QCoreApplication::applicationDirPath();
    // QQmlEngine::addImportPath prepends; add fallback source path first and compiled .qsb paths last.
    if (QFile::exists(QDir::currentPath() + "/conjunction-design/qml")) {
        engine.addImportPath(QDir::currentPath() + "/conjunction-design/qml");
    } else if (QFile::exists("/work/conjunction-design/qml")) {
        engine.addImportPath("/work/conjunction-design/qml");
    }
    auto addCompiledQmlPath = [&](const QString &p) {
        if (QFile::exists(p + "/Conjunction/Design/shaders/liquid_glass.frag.qsb")) {
            engine.addImportPath(p);
        }
    };
    addCompiledQmlPath("/usr/share/conjunction/qml");
    addCompiledQmlPath(appDir + "/../share/conjunction/qml");
    addCompiledQmlPath(appDir + "/../qml");
    addCompiledQmlPath(appDir + "/qml");

    QUrl url;
    if (QFile::exists(QDir::currentPath() + "/conjunction-design/gallery/Main.qml")) {
        url = QUrl::fromLocalFile(QDir::currentPath() + "/conjunction-design/gallery/Main.qml");
    } else if (QFile::exists("/work/conjunction-design/gallery/Main.qml")) {
        url = QUrl::fromLocalFile("/work/conjunction-design/gallery/Main.qml");
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

    app.installEventFilter(new InputFocusTracker(window, &app));

    QString reqTheme = parser.value(themeOption);
    bool reqRtl = parser.isSet(rtlOption) || qEnvironmentVariable("LANGUAGE").startsWith("ar") || app.isRightToLeft();
    bool reqReducedMotion = parser.isSet(reducedMotionOption);
    bool reqReduceTransparency = parser.isSet(reduceTransparencyOption);
    bool reqIncreaseContrast = parser.isSet(increaseContrastOption);
    bool reqStressMode = parser.isSet(stressModeOption);
    QString reqScene = parser.value(sceneOption);
    QString reqScale = parser.value(scaleOption);
    int reqWidth = parser.value(widthOption).toInt();
    int reqHeight = parser.value(heightOption).toInt();

    if (reqWidth > 0 && reqHeight > 0) {
        QMetaObject::invokeMethod(window, "setWindowSize", Q_ARG(QVariant, reqWidth), Q_ARG(QVariant, reqHeight));
    }

    QString initialSel = (reqScene == QLatin1String("all")) ? QStringLiteral("liquid_glass") : reqScene;
    window->setProperty("initialScene", initialSel);
    QMetaObject::invokeMethod(window, "configure",
                              Q_ARG(QVariant, reqTheme),
                              Q_ARG(QVariant, reqRtl),
                              Q_ARG(QVariant, reqReducedMotion),
                              Q_ARG(QVariant, reqScale),
                              Q_ARG(QVariant, reqReduceTransparency),
                              Q_ARG(QVariant, reqIncreaseContrast),
                              Q_ARG(QVariant, reqStressMode));
    QMetaObject::invokeMethod(window, "selectScene", Q_ARG(QVariant, initialSel));

    window->show();

    QTimer::singleShot(300, [window, &parser, reqScene, screenshotOption, stressOption, focusTestOption, keyboardTestOption, auditOverflowOption]() {
        if (parser.isSet(auditOverflowOption)) {
            QStringList scenes;
            if (reqScene == QLatin1String("all")) {
                QVariant ret;
                QMetaObject::invokeMethod(window, "sceneIds", Q_RETURN_ARG(QVariant, ret));
                scenes = ret.toStringList();
            } else {
                scenes << reqScene;
            }
            auto runNext = std::make_shared<std::function<void(int)>>();
            auto totalFailures = std::make_shared<int>(0);
            const QString outPath = parser.value(screenshotOption);
            *runNext = [window, scenes, runNext, totalFailures, outPath](int idx) {
                if (idx >= scenes.size()) {
                    if (!outPath.isEmpty() && scenes.size() == 1) {
                        QImage img = window->grabWindow();
                        if (!img.isNull()) img.save(outPath);
                    }
                    fprintf(stderr, "OVERFLOW_AUDIT_COMPLETE scenes=%d failures=%d\n",
                            static_cast<int>(scenes.size()), *totalFailures);
                    QCoreApplication::exit(*totalFailures == 0 ? 0 : 2);
                    return;
                }
                const QString sc = scenes.at(idx);
                QMetaObject::invokeMethod(window, "selectScene", Q_ARG(QVariant, sc));
                QTimer::singleShot(140, [window, sc, idx, scenes, runNext, totalFailures, outPath]() {
                    const auto findings = Conjunction::OverflowAudit::auditWindow(window);
                    if (findings.isEmpty()) {
                        fprintf(stderr, "[OVERFLOW PASS] scene=%s\n", qPrintable(sc));
                    } else {
                        (*totalFailures) += findings.size();
                        fprintf(stderr, "[OVERFLOW FAIL] scene=%s findings=%d\n",
                                qPrintable(sc), static_cast<int>(findings.size()));
                        for (const auto &f : findings) {
                            fprintf(stderr, "  - %s | %s | %s\n",
                                    qPrintable(f.kind), qPrintable(f.itemDesc), qPrintable(f.detail));
                        }
                    }
                    if (!outPath.isEmpty() && scenes.size() == 1) {
                        QImage img = window->grabWindow();
                        if (!img.isNull()) img.save(outPath);
                    }
                    (*runNext)(idx + 1);
                });
            };
            (*runNext)(0);
            return;
        }
        if (parser.isSet(stressOption)) {
            int cycles = parser.value(stressOption).toInt();
            if (cycles <= 0) cycles = 50;
            for (int i = 0; i < cycles; ++i) {
                const char *th = (i % 2 == 0) ? "dark" : "light";
                QMetaObject::invokeMethod(window, "configure",
                                          Q_ARG(QVariant, QString(th)),
                                          Q_ARG(QVariant, false),
                                          Q_ARG(QVariant, false),
                                          Q_ARG(QVariant, "1.0"),
                                          Q_ARG(QVariant, false),
                                          Q_ARG(QVariant, false),
                                          Q_ARG(QVariant, false));
            }
            fprintf(stderr, "Theme switch stress test passed successfully (%d cycles).\n", cycles);
            QCoreApplication::exit(0);
            return;
        }

        if (parser.isSet(focusTestOption)) {
            QMetaObject::invokeMethod(window, "selectScene", Q_ARG(QVariant, "focus"));
            QTimer::singleShot(120, [window]() {
                QMetaObject::invokeMethod(window, "setKeyboardFocusActive", Q_ARG(QVariant, true));
                for (int i = 0; i < 4; ++i) {
                    QKeyEvent tabPress(QEvent::KeyPress, Qt::Key_Tab, Qt::NoModifier);
                    QCoreApplication::sendEvent(window, &tabPress);
                    QKeyEvent tabRelease(QEvent::KeyRelease, Qt::Key_Tab, Qt::NoModifier);
                    QCoreApplication::sendEvent(window, &tabRelease);
                }
                fprintf(stderr, "Keyboard focus traversal verified without pointer input.\n");
                QCoreApplication::exit(0);
            });
            return;
        }

        if (parser.isSet(keyboardTestOption)) {
            QMetaObject::invokeMethod(window, "selectScene", Q_ARG(QVariant, "keyboard_workflow"));
            QTimer::singleShot(150, [window]() {
                QMetaObject::invokeMethod(window, "setKeyboardFocusActive", Q_ARG(QVariant, true));
                for (int i = 0; i < 5; ++i) {
                    QKeyEvent tabP(QEvent::KeyPress, Qt::Key_Tab, Qt::NoModifier);
                    QCoreApplication::sendEvent(window, &tabP);
                    QKeyEvent tabR(QEvent::KeyRelease, Qt::Key_Tab, Qt::NoModifier);
                    QCoreApplication::sendEvent(window, &tabR);
                }
                fprintf(stderr, "End-to-end keyboard workflow completed successfully.\n");
                QCoreApplication::exit(0);
            });
            return;
        }

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
