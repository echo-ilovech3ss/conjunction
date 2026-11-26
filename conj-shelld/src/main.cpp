#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QQuickImageProvider>
#include <QIcon>
#include "../../conjunction-design/common/overflow_audit.h"
#include <QCommandLineParser>
#include <QTimer>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QPainter>
#include <QFont>
#include <QDebug>
#include <QImage>

#include "window_manager.h"
#include "menu_registrar.h"
#include "shell_state.h"

class ThemeIconProvider : public QQuickImageProvider {
public:
    ThemeIconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}
    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override {
        const int target = (requestedSize.isValid() && requestedSize.width() > 0) ? requestedSize.width() : 64;
        QString key = QUrl::fromPercentEncoding(id.toUtf8());
        const int q = key.indexOf('?');
        if (q >= 0) key = key.left(q);
        QIcon ic = QIcon::fromTheme(key);
        if (ic.isNull() && key.contains('/')) {
            ic = QIcon::fromTheme(QFileInfo(key).completeBaseName());
        }
        QPixmap pm = ic.isNull() ? QPixmap() : ic.pixmap(target, target);
        if (pm.isNull()) {
            // Crisp clean-room glyph fallback for missing XDG desktop icons in minimal environments
            pm = QPixmap(target, target);
            pm.fill(Qt::transparent);
            QPainter painter(&pm);
            painter.setRenderHint(QPainter::Antialiasing);
            painter.setPen(QPen(Qt::white, qMax(1.5, target * 0.08), Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
            const qreal m = target * 0.16;
            const QRectF r(m, m, target - 2 * m, target - 2 * m);
            if (key.contains("terminal") || key.contains("konsole")) {
                painter.setBrush(QColor(30, 32, 36, 220));
                painter.drawRoundedRect(r, target * 0.16, target * 0.16);
                painter.drawLine(QPointF(target * 0.30, target * 0.40), QPointF(target * 0.44, target * 0.50));
                painter.drawLine(QPointF(target * 0.44, target * 0.50), QPointF(target * 0.30, target * 0.60));
                painter.drawLine(QPointF(target * 0.49, target * 0.60), QPointF(target * 0.68, target * 0.60));
            } else if (key.contains("preferences") || key.contains("settings") || key.contains("system")) {
                painter.setBrush(QColor(96, 102, 112, 220));
                painter.drawRoundedRect(r, target * 0.22, target * 0.22);
                painter.drawEllipse(QPointF(target * 0.5, target * 0.5), target * 0.19, target * 0.19);
                painter.drawEllipse(QPointF(target * 0.5, target * 0.5), target * 0.07, target * 0.07);
            } else {
                painter.setBrush(QColor(68, 128, 220, 210));
                painter.drawRoundedRect(r, target * 0.18, target * 0.18);
                QString mono = key.left(2).toUpper();
                QFont f = painter.font();
                f.setBold(true);
                f.setPixelSize(qMax(10, int(target * 0.32)));
                painter.setFont(f);
                painter.setPen(Qt::white);
                painter.drawText(r, Qt::AlignCenter, mono);
            }
        }
        if (size) *size = pm.size();
        return pm;
    }
};

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
    QCommandLineOption stressModeOption("stress-mode", "Populate shell with long stress strings for overflow testing");
    QCommandLineOption auditOverflowOption("audit-overflow", "Run automated QML overflow check on visible shell window(s)");
    QCommandLineOption widthOption("width", "Override composite window width", "px", "0");
    QCommandLineOption heightOption("height", "Override composite window height", "px", "0");
    QCommandLineOption fontScaleOption("font-scale", "Override UI typography scale factor", "scale", "1.0");

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
    parser.addOption(stressModeOption);
    parser.addOption(auditOverflowOption);
    parser.addOption(widthOption);
    parser.addOption(heightOption);
    parser.addOption(fontScaleOption);
    parser.process(app);

    if (parser.isSet(rtlOption) || qEnvironmentVariable("LANGUAGE").startsWith("ar") || app.isRightToLeft()) {
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
    engine.addImageProvider(QStringLiteral("icon"), new ThemeIconProvider());
    engine.rootContext()->setContextProperty("initialRtl", parser.isSet(rtlOption) || qEnvironmentVariable("LANGUAGE").startsWith("ar") || app.isRightToLeft());
    engine.rootContext()->setContextProperty("initialFontScale", parser.value(fontScaleOption).toDouble());
    engine.rootContext()->setContextProperty("initialCompositeWidth", parser.value(widthOption).toInt());
    engine.rootContext()->setContextProperty("initialCompositeHeight", parser.value(heightOption).toInt());

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

    QQuickWindow *window = qobject_cast<QQuickWindow*>(engine.rootObjects().first());
    if (!window) {
        window = engine.rootObjects().first()->findChild<QQuickWindow*>();
    }
    if (!window) {
        for (QWindow *w : QGuiApplication::topLevelWindows()) {
            if (auto *qw = qobject_cast<QQuickWindow*>(w)) {
                if (qw->isVisible()) { window = qw; break; }
            }
        }
    }

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

    if (parser.isSet(stressModeOption)) {
        const QString longApp = QStringLiteral("Conjunction Enterprise Workstation Browser — Donaudampfschifffahrtsgesellschaftskapitän — Ultra-Long Application Title");
        const QString compound = QStringLiteral("Rindfleischetikettierungsüberwachungsaufgabenübertragungsgesetz");
        const QString longUrl = QStringLiteral("https://conjunction.example.org/workstation/api/v2/bundles/org.conjunction.desktop/verification/long-unbroken-url");
        shellState->simulateWindow("1001", longApp, "org.conjunction.files", true);
        shellState->simulateWindow("1002", compound + " — zsh", "org.conjunction.terminal", false);
        shellState->simulateMinimizedWindow("1003", longUrl, "org.conjunction.settings");
        shellState->simulateNotification(101, longApp, compound + ": " + longUrl, "Utilities");
        shellState->simulateNotification(102, compound, longUrl + " " + longApp, "Files");
        if (parser.isSet(spotlightOption) && parser.value(spotlightOption).isEmpty()) {
            shellState->setSearchQuery(longApp);
        }
        QVariantList stressMenu;
        for (const QString &lbl : QStringList{longApp, compound, "View", "Window", "Help"}) {
            QVariantMap m;
            m["id"] = 200 + stressMenu.size();
            m["label"] = lbl;
            QVariantList ch;
            QVariantMap item;
            item["id"] = 300 + stressMenu.size();
            item["label"] = longApp;
            item["shortcut"] = "Ctrl+Shift+Alt+F12";
            item["enabled"] = true;
            ch.append(item);
            QVariantMap item2;
            item2["id"] = 310 + stressMenu.size();
            item2["label"] = longUrl;
            item2["shortcut"] = "⌘O";
            item2["enabled"] = true;
            ch.append(item2);
            m["children"] = ch;
            stressMenu.append(m);
        }
        shellState->simulateGlobalMenu(stressMenu);
    }

    if (parser.isSet(auditOverflowOption) || parser.isSet(screenshotOption)) {
        QString outPath = parser.value(screenshotOption);
        bool doAudit = parser.isSet(auditOverflowOption);
        int delay = parser.isSet(timeoutOption) ? parser.value(timeoutOption).toInt() : 650;
        QTimer::singleShot(delay, [window, outPath, doAudit]() {
            int failures = 0;
            if (doAudit) {
                for (QWindow *w : QGuiApplication::topLevelWindows()) {
                    if (auto *qw = qobject_cast<QQuickWindow*>(w)) {
                        if (!qw->isVisible()) continue;
                        const auto findings = Conjunction::OverflowAudit::auditWindow(qw);
                        if (findings.isEmpty()) {
                            fprintf(stderr, "[OVERFLOW PASS] shellWindow=%s\n", qPrintable(qw->title()));
                        } else {
                            failures += findings.size();
                            fprintf(stderr, "[OVERFLOW FAIL] shellWindow=%s findings=%d\n", qPrintable(qw->title()), static_cast<int>(findings.size()));
                            for (const auto &f : findings) {
                                fprintf(stderr, "  - %s | %s | %s\n", qPrintable(f.kind), qPrintable(f.itemDesc), qPrintable(f.detail));
                            }
                        }
                    }
                }
            }
            if (!outPath.isEmpty() && window) {
                QImage img = window->grabWindow();
                QDir().mkpath(QFileInfo(outPath).absolutePath());
                if (img.save(outPath)) {
                    qInfo() << "[conj-shelld] Saved screenshot to:" << outPath << "(" << img.width() << "x" << img.height() << ")";
                } else {
                    qWarning() << "[conj-shelld] Failed to save screenshot to:" << outPath;
                }
            }
            QCoreApplication::exit(failures == 0 ? 0 : 2);
        });
    } else if (parser.isSet(timeoutOption)) {
        int ms = parser.value(timeoutOption).toInt();
        if (ms > 0) {
            QTimer::singleShot(ms, []() {
                QCoreApplication::exit(0);
            });
        }
    }

    return app.exec();
}
