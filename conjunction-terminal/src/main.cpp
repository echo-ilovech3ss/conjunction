#include <QApplication>
#include <QCommandLineParser>
#include <QDir>
#include <QFileInfo>
#include <QTimer>
#include <QPixmap>
#include <QDebug>
#include <iostream>

#include <KPluginMetaData>
#include <KPluginFactory>
#include <KParts/ReadOnlyPart>

#include "terminal_window.h"
#include "terminal_session.h"
#include "theme_bridge.h"
#include "shell_escape.h"

// Forward declaration for self-tests
int runSelfTests();

int main(int argc, char *argv[])
{
    // High-DPI scaling option parsing before QApplication
    for (int i = 1; i < argc; ++i) {
        if (QString(argv[i]) == QStringLiteral("--scale") && i + 1 < argc) {
            qputenv("QT_SCALE_FACTOR", argv[i + 1]);
        }
    }

    QApplication app(argc, argv);
    QApplication::setApplicationName(QStringLiteral("conjunction-terminal"));
    QApplication::setApplicationDisplayName(QStringLiteral("Terminal"));
    QApplication::setOrganizationName(QStringLiteral("Conjunction"));
    QApplication::setDesktopFileName(QStringLiteral("conjunction-terminal"));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Conjunction Terminal - Modern Desktop Terminal Host"));
    parser.addHelpOption();
    parser.addVersionOption();

    QCommandLineOption workingDirOption(QStringList() << QStringLiteral("working-directory") << QStringLiteral("d"),
                                        QStringLiteral("Set starting directory for the terminal session"),
                                        QStringLiteral("path"),
                                        QDir::homePath());
    QCommandLineOption profileOption(QStringList() << QStringLiteral("profile") << QStringLiteral("p"),
                                     QStringLiteral("Use specified Konsole profile"),
                                     QStringLiteral("name"));
    QCommandLineOption commandOption(QStringList() << QStringLiteral("command") << QStringLiteral("e"),
                                     QStringLiteral("Execute program inside terminal (must be followed by program and arguments)"),
                                     QStringLiteral("program"));
    QCommandLineOption darkOption(QStringLiteral("dark"), QStringLiteral("Force dark mode appearance"));
    QCommandLineOption lightOption(QStringLiteral("light"), QStringLiteral("Force light mode appearance"));
    QCommandLineOption scaleOption(QStringLiteral("scale"), QStringLiteral("UI scale factor"), QStringLiteral("factor"));
    QCommandLineOption screenshotOption(QStringLiteral("screenshot"), QStringLiteral("Capture window to file and exit"), QStringLiteral("file"));
    QCommandLineOption timeoutOption(QStringLiteral("timeout"), QStringLiteral("Exit after timeout in ms"), QStringLiteral("ms"));
    QCommandLineOption testModeOption(QStringLiteral("test-mode"), QStringLiteral("Run automated terminal verification tests"));
    QCommandLineOption testTabsOption(QStringLiteral("test-tabs"), QStringLiteral("Open multiple tabs for test/screenshot"));
    QCommandLineOption testFindOption(QStringLiteral("test-find"), QStringLiteral("Open find bar for test/screenshot"));
    QCommandLineOption testDroppedOption(QStringLiteral("test-dropped-path"), QStringLiteral("Simulate dropping path into terminal"), QStringLiteral("path"));

    parser.addOption(workingDirOption);
    parser.addOption(profileOption);
    parser.addOption(commandOption);
    parser.addOption(darkOption);
    parser.addOption(lightOption);
    parser.addOption(scaleOption);
    parser.addOption(screenshotOption);
    parser.addOption(timeoutOption);
    parser.addOption(testModeOption);
    parser.addOption(testTabsOption);
    parser.addOption(testFindOption);
    parser.addOption(testDroppedOption);

    // Any positional arguments after -e/--command are captured
    QStringList rawArgs = app.arguments();
    int cmdIdx = -1;
    for (int i = 1; i < rawArgs.size(); ++i) {
        if (rawArgs[i] == QStringLiteral("--command") || rawArgs[i] == QStringLiteral("-e")) {
            cmdIdx = i;
            break;
        }
    }
    if (cmdIdx != -1 && cmdIdx + 2 < rawArgs.size()) {
        bool hasSeparator = false;
        for (int i = cmdIdx + 2; i < rawArgs.size(); ++i) {
            if (rawArgs[i] == QStringLiteral("--")) {
                hasSeparator = true;
                break;
            }
        }
        if (!hasSeparator) {
            rawArgs.insert(cmdIdx + 2, QStringLiteral("--"));
        }
    }

    parser.process(rawArgs);

    if (parser.isSet(testModeOption)) {
        return runSelfTests();
    }

    if (parser.isSet(darkOption)) {
        Conjunction::ThemeBridge::instance().setForcedDark(true);
    } else if (parser.isSet(lightOption)) {
        Conjunction::ThemeBridge::instance().setForcedLight(true);
    }

    // Diagnostic check: verify that KonsolePart plugin exists
    KPluginMetaData metaData(QStringLiteral("kf6/parts/konsolepart"));
    if (!metaData.isValid() || qEnvironmentVariableIsSet("CONJUNCTION_TEST_MISSING_KONSOLEPART")) {
        std::cerr << "conjunction-terminal: Error: KonsolePart (kf6/parts/konsolepart) is not available on this system." << std::endl;
        std::cerr << "Please install KDE Konsole / konsolepart package." << std::endl;
        return 1;
    }

    QString workingDir = parser.value(workingDirOption);
    if (!workingDir.isEmpty() && !QDir(workingDir).exists()) {
        qWarning() << "[conjunction-terminal] Specified working directory does not exist:" << workingDir << "- falling back to home";
        workingDir = QDir::homePath();
    }

    QString profile = parser.value(profileOption);

    Conjunction::TerminalWindow window;

    // Check if a specific program command was given
    if (parser.isSet(commandOption)) {
        QString prog = parser.value(commandOption);
        QStringList cmdArgs = parser.positionalArguments();
        if (!window.openProgram(prog, cmdArgs, workingDir)) {
            std::cerr << "conjunction-terminal: Failed to launch program: " << prog.toStdString() << std::endl;
            return 1;
        }
    } else {
        if (!window.openSession(workingDir, profile)) {
            std::cerr << "conjunction-terminal: Failed to initialize terminal session with KonsolePart." << std::endl;
            return 1;
        }
    }

    if (parser.isSet(testTabsOption)) {
        window.newTab(QDir::rootPath());
        window.newTab(workingDir);
    }
    if (parser.isSet(testFindOption)) {
        window.toggleFind();
    }
    if (parser.isSet(testDroppedOption)) {
        QString dropped = parser.value(testDroppedOption);
        if (window.activeSession()) {
            window.activeSession()->sendInput(Conjunction::escapeShellArg(dropped) + QStringLiteral(" "));
        }
    }

    window.show();

    // Headless screenshot capture support
    if (parser.isSet(screenshotOption)) {
        QString outPath = parser.value(screenshotOption);
        int timeoutMs = parser.isSet(timeoutOption) ? parser.value(timeoutOption).toInt() : 2500;
        if (timeoutMs <= 0) timeoutMs = 2500;

        QTimer::singleShot(timeoutMs, &window, [&window, outPath]() {
            QPixmap pix = window.grab();
            QFileInfo fi(outPath);
            QDir().mkpath(fi.dir().absolutePath());
            if (pix.save(outPath)) {
                qInfo() << "[conjunction-terminal] Screenshot successfully saved to:" << outPath;
            } else {
                qCritical() << "[conjunction-terminal] Failed to save screenshot to:" << outPath;
            }
            std::exit(0);
        });
    } else if (parser.isSet(timeoutOption)) {
        int timeoutMs = parser.value(timeoutOption).toInt();
        if (timeoutMs > 0) {
            QTimer::singleShot(timeoutMs, &app, []() { std::exit(0); });
        }
    }

    return app.exec();
}
