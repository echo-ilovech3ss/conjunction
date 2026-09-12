#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QCommandLineParser>
#include <QIcon>
#include <QQuickImageProvider>
#include <QPainter>
#include <QTimer>
#include <QDir>
#include <QDebug>

#include "settings_manager.h"
#include "system_info.h"
#include "network_backend.h"
#include "bluetooth_backend.h"
#include "display_backend.h"
#include "audio_backend.h"

class IconImageProvider : public QQuickImageProvider {
public:
    IconImageProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}

    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override {
        int width = requestedSize.width() > 0 ? requestedSize.width() : 64;
        int height = requestedSize.height() > 0 ? requestedSize.height() : 64;
        if (size) *size = QSize(width, height);

        QIcon icon = QIcon::fromTheme(id);
        if (!icon.isNull()) {
            QPixmap pix = icon.pixmap(width, height);
            if (!pix.isNull()) return pix;
        }

        // Draw graceful fallback icon
        QPixmap pix(width, height);
        pix.fill(Qt::transparent);
        QPainter painter(&pix);
        painter.setRenderHint(QPainter::Antialiasing);

        QColor baseColor(52, 120, 246);
        if (id.contains("theme") || id.contains("appearance")) baseColor = QColor(142, 68, 173);
        else if (id.contains("desktop") || id.contains("dock")) baseColor = QColor(41, 128, 185);
        else if (id.contains("display") || id.contains("screen")) baseColor = QColor(39, 174, 96);
        else if (id.contains("sound") || id.contains("audio")) baseColor = QColor(230, 126, 34);
        else if (id.contains("network") || id.contains("wireless")) baseColor = QColor(22, 160, 133);
        else if (id.contains("bluetooth")) baseColor = QColor(41, 128, 185);
        else if (id.contains("about") || id.contains("help")) baseColor = QColor(127, 140, 141);

        qreal radius = qMax(4.0, width * 0.22);
        painter.setBrush(baseColor);
        painter.setPen(Qt::NoPen);
        painter.drawRoundedRect(1, 1, width - 2, height - 2, radius, radius);

        painter.setPen(Qt::white);
        QFont f = painter.font();
        f.setBold(true);
        f.setPixelSize(qMax(8, (int)(height * 0.45)));
        painter.setFont(f);
        painter.drawText(QRect(0, 0, width, height), Qt::AlignCenter, id.left(2).toUpper());

        return pix;
    }
};

int main(int argc, char *argv[])
{
    QGuiApplication::setApplicationName("conjunction-settings");
    QGuiApplication::setOrganizationName("Conjunction");

    if (QIcon::themeName().isEmpty() || QIcon::themeName() == "hicolor") {
        QIcon::setThemeName("breeze-dark");
    }

    for (int i = 1; i < argc; ++i) {
        if (QString(argv[i]) == "--scale" && i + 1 < argc) {
            qputenv("QT_SCALE_FACTOR", argv[i + 1]);
        }
    }

    QGuiApplication app(argc, argv);

    QCommandLineParser parser;
    parser.setApplicationDescription("Conjunction System Settings");
    parser.addHelpOption();
    parser.addVersionOption();

    QCommandLineOption pageOption("page", "Navigate directly to setting page", "id");
    QCommandLineOption settingOption("setting", "Navigate directly to individual setting ID", "id");
    QCommandLineOption urlOption("url", "Settings URI (settings://<page>?setting=<id>)", "uri");
    QCommandLineOption searchOption("search", "Pre-fill search query", "query");
    QCommandLineOption darkOption("dark", "Force dark theme");
    QCommandLineOption lightOption("light", "Force light theme");
    QCommandLineOption scaleOption("scale", "UI scale factor", "factor");
    QCommandLineOption screenshotOption("screenshot", "Capture window to PNG file and exit", "file");
    QCommandLineOption timeoutOption("timeout", "Exit after ms", "ms");

    parser.addOption(pageOption);
    parser.addOption(settingOption);
    parser.addOption(urlOption);
    parser.addOption(searchOption);
    parser.addOption(darkOption);
    parser.addOption(lightOption);
    parser.addOption(scaleOption);
    parser.addOption(screenshotOption);
    parser.addOption(timeoutOption);
    parser.process(app);

    auto *settingsMgr = new SettingsManager(&app);
    auto *systemInfo = new SystemInfo(&app);
    auto *networkBackend = new NetworkBackend(&app);
    auto *bluetoothBackend = new BluetoothBackend(&app);
    auto *displayBackend = new DisplayBackend(&app);
    auto *audioBackend = new AudioBackend(&app);

    if (parser.isSet(darkOption)) {
        settingsMgr->setAppearanceMode("dark");
    } else if (parser.isSet(lightOption)) {
        settingsMgr->setAppearanceMode("light");
    }

    // Handle deep links and search
    if (parser.isSet(searchOption)) {
        settingsMgr->setSearchQuery(parser.value(searchOption));
    } else if (parser.isSet(urlOption)) {
        settingsMgr->handleUrl(parser.value(urlOption));
    } else if (parser.isSet(pageOption) || parser.isSet(settingOption)) {
        QString page = parser.value(pageOption);
        QString setting = parser.value(settingOption);
        if (page.isEmpty() && !setting.isEmpty()) {
            if (setting.startsWith("appearance.")) page = "appearance";
            else if (setting.startsWith("dock.") || setting.startsWith("desktop.")) page = "dock";
            else if (setting.startsWith("displays.")) page = "displays";
            else if (setting.startsWith("sound.")) page = "sound";
            else if (setting.startsWith("network.")) page = "network";
            else if (setting.startsWith("bluetooth.")) page = "bluetooth";
            else page = "about";
        }
        settingsMgr->navigateTo(!page.isEmpty() ? page : "about", setting);
    }

    QQmlApplicationEngine engine;
    engine.addImageProvider("icon", new IconImageProvider());

    QString appDir = QCoreApplication::applicationDirPath();
    engine.addImportPath(appDir + "/../share/conjunction/qml");
    engine.addImportPath(appDir + "/../../conjunction-design/qml");
    engine.addImportPath("/usr/share/conjunction/qml");
    engine.addImportPath("/usr/lib/qt6/qml");

    engine.rootContext()->setContextProperty("SettingsManager", settingsMgr);
    engine.rootContext()->setContextProperty("SystemInfo", systemInfo);
    engine.rootContext()->setContextProperty("NetworkBackend", networkBackend);
    engine.rootContext()->setContextProperty("BluetoothBackend", bluetoothBackend);
    engine.rootContext()->setContextProperty("DisplayBackend", displayBackend);
    engine.rootContext()->setContextProperty("AudioBackend", audioBackend);

    QString qmlFile = appDir + "/../share/conjunction/settings/SettingsWindow.qml";
    if (!QFile::exists(qmlFile)) qmlFile = "/usr/share/conjunction/settings/SettingsWindow.qml";
    if (!QFile::exists(qmlFile)) qmlFile = appDir + "/../qml/SettingsWindow.qml";
    if (!QFile::exists(qmlFile)) qmlFile = QDir::currentPath() + "/conjunction-settings/qml/SettingsWindow.qml";
    if (!QFile::exists(qmlFile)) qmlFile = "/mnt/c/Users/Way4U/Coding-projects/conjunction/conjunction-settings/qml/SettingsWindow.qml";

    qInfo() << "[conjunction-settings] Loading Settings QML:" << qmlFile;
    engine.load(QUrl::fromLocalFile(qmlFile));

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "[conjunction-settings] Failed to load QML root object from" << qmlFile;
        return 1;
    }

    auto *window = qobject_cast<QQuickWindow*>(engine.rootObjects().first());

    // Screenshot capture automation
    if (parser.isSet(screenshotOption)) {
        QString outPath = parser.value(screenshotOption);
        int delay = parser.isSet(timeoutOption) ? parser.value(timeoutOption).toInt() : 1200;

        QTimer::singleShot(delay, [window, outPath]() {
            if (window) {
                QImage img = window->grabWindow();
                QDir().mkpath(QFileInfo(outPath).absolutePath());
                if (img.save(outPath)) {
                    qInfo() << "[conjunction-settings] Screenshot saved to:" << outPath;
                } else {
                    qWarning() << "[conjunction-settings] Failed to save screenshot to:" << outPath;
                }
            }
            QCoreApplication::exit(0);
        });
    } else if (parser.isSet(timeoutOption)) {
        int timeoutMs = parser.value(timeoutOption).toInt();
        QTimer::singleShot(timeoutMs, []() {
            QCoreApplication::exit(0);
        });
    }

    return app.exec();
}
