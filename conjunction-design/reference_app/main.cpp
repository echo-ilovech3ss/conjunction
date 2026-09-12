#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusArgument>
#include <QDBusContext>
#include <QFile>
#include <QDir>
#include <QDateTime>
#include <QDebug>
#include <QTimer>

class ReferenceAppDBusMenu : public QObject, protected QDBusContext {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "com.canonical.dbusmenu")

public:
    explicit ReferenceAppDBusMenu(QObject *parent = nullptr) : QObject(parent) {}

public Q_SLOTS:
    Q_SCRIPTABLE QVariantList GetLayout(int parentId, int recursionDepth, const QStringList &propertyNames) {
        Q_UNUSED(parentId);
        Q_UNUSED(recursionDepth);
        Q_UNUSED(propertyNames);

        // Format: (uint revision, (int id, map props, list children))
        QVariantList reply;
        reply.append(1u); // revision

        QVariantMap rootProps;
        QVariantList rootChildren;

        // File Menu
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
        rootChildren.append(fileMenu);

        // Edit Menu
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
        rootChildren.append(editMenu);

        // View Menu
        QVariantMap viewMenu;
        viewMenu["id"] = 30;
        viewMenu["label"] = "View";
        rootChildren.append(viewMenu);

        // Window Menu
        QVariantMap windowMenu;
        windowMenu["id"] = 40;
        windowMenu["label"] = "Window";
        rootChildren.append(windowMenu);

        // Help Menu
        QVariantMap helpMenu;
        helpMenu["id"] = 50;
        helpMenu["label"] = "Help";
        rootChildren.append(helpMenu);

        QVariantMap rootItem;
        rootItem["id"] = 0;
        rootItem["children"] = rootChildren;

        reply.append(rootItem);
        return reply;
    }

    Q_SCRIPTABLE void Event(int id, const QString &eventId, const QDBusVariant &data, uint timestamp) {
        Q_UNUSED(data);
        Q_UNUSED(timestamp);
        qInfo() << "[ReferenceApp] Menu event received: id=" << id << "event=" << eventId;
        if (id == 12 && eventId == "clicked") {
            writeMarkerFile("global_menu");
        }
    }

    void writeMarkerFile(const QString &source) {
        QFile file("/tmp/conjunction-marker.txt");
        if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QString content = QString("Conjunction Test Marker verified via %1 at %2\n")
                                  .arg(source)
                                  .arg(QDateTime::currentDateTime().toString(Qt::ISODate));
            file.write(content.toUtf8());
            file.close();
            qInfo() << "[ReferenceApp] Test marker file written successfully via" << source;
            Q_EMIT markerCreated(source);
        }
    }

Q_SIGNALS:
    void markerCreated(const QString &source);
};

class ReferenceBridge : public QObject {
    Q_OBJECT
public:
    explicit ReferenceBridge(ReferenceAppDBusMenu *menu, QObject *parent = nullptr)
        : QObject(parent), m_menu(menu) {}

    Q_INVOKABLE void createTestMarker(const QString &source) {
        m_menu->writeMarkerFile(source);
    }

private:
    ReferenceAppDBusMenu *m_menu;
};

int main(int argc, char *argv[])
{
    QGuiApplication::setApplicationName("conjunction-reference-app");
    QGuiApplication::setOrganizationName("Conjunction");

    QGuiApplication app(argc, argv);

    auto *dbusMenu = new ReferenceAppDBusMenu(&app);
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (bus.isConnected()) {
        bus.registerObject("/MenuBar", dbusMenu, QDBusConnection::ExportScriptableContents);
    }

    auto *bridge = new ReferenceBridge(dbusMenu, &app);

    QQmlApplicationEngine engine;
    QString appDir = QCoreApplication::applicationDirPath();
    engine.addImportPath(appDir + "/../share/conjunction/qml");
    engine.addImportPath(appDir + "/../../qml");
    engine.addImportPath("/usr/share/conjunction/qml");
    engine.addImportPath("/usr/lib/qt6/qml");

    engine.rootContext()->setContextProperty("ReferenceBridge", bridge);

    if (app.arguments().contains("--create-marker")) {
        dbusMenu->writeMarkerFile("cli_in_window");
    }

    QStringList candidates = {
        appDir + "/../share/conjunction/reference/ReferenceWindow.qml",
        "/usr/share/conjunction/reference/ReferenceWindow.qml",
        "/usr/local/share/conjunction/reference/ReferenceWindow.qml",
        "/tmp/conjunction-design/reference_app/ReferenceWindow.qml",
        QDir::currentPath() + "/conjunction-design/reference_app/ReferenceWindow.qml",
        "/mnt/c/Users/Way4U/Coding-projects/conjunction/conjunction-design/reference_app/ReferenceWindow.qml"
    };

    QString qmlPath;
    for (const auto &p : candidates) {
        if (QFile::exists(p)) {
            qmlPath = p;
            break;
        }
    }

    if (!qmlPath.isEmpty()) {
        engine.load(QUrl::fromLocalFile(qmlPath));
    }

    QQuickWindow *window = nullptr;
    if (!engine.rootObjects().isEmpty()) {
        window = qobject_cast<QQuickWindow*>(engine.rootObjects().first());
    }
    if (window) {
        uint winId = window->winId();
        if (winId == 0) winId = static_cast<uint>(app.applicationPid());

        // Register window with com.canonical.AppMenu.Registrar
        QDBusMessage regMsg = QDBusMessage::createMethodCall(
            "com.canonical.AppMenu.Registrar",
            "/com/canonical/AppMenu/Registrar",
            "com.canonical.AppMenu.Registrar",
            "RegisterWindow"
        );
        regMsg << winId << QVariant::fromValue(QDBusObjectPath("/MenuBar"));
        bus.send(regMsg);

        // Announce window to Conjunction Shell WindowManager
        QDBusMessage actMsg = QDBusMessage::createMethodCall(
            "org.conjunction.Shell",
            "/org/conjunction/Shell/WindowManager",
            "org.conjunction.Shell.WindowManager",
            "WindowActivated"
        );
        actMsg << QString::number(winId)
               << QString("Desktop Reference")
               << QString("dev.conjunction.reference")
               << static_cast<uint>(app.applicationPid())
               << false;
        bus.send(actMsg);
    }

    // Check if CLI instructed to trigger marker directly or exit
    if (app.arguments().contains("--create-marker")) {
        dbusMenu->writeMarkerFile("cli_in_window");
    }

    if (app.arguments().contains("--timeout")) {
        int idx = app.arguments().indexOf("--timeout");
        if (idx + 1 < app.arguments().size()) {
            int ms = app.arguments().at(idx + 1).toInt();
            QTimer::singleShot(ms, &app, &QGuiApplication::quit);
        }
    }

    return app.exec();
}

#include "main.moc"
