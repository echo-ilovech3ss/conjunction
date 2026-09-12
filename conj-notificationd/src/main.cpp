#include <QCoreApplication>
#include <QCommandLineParser>
#include <QDBusConnection>
#include <QDBusError>
#include <iostream>

#include "notification_manager.h"

// Forward declaration for self-tests
int runSelfTests();

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("conj-notificationd"));
    QCoreApplication::setOrganizationName(QStringLiteral("Conjunction"));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Conjunction Notification Daemon"));
    parser.addHelpOption();
    parser.addVersionOption();

    QCommandLineOption testModeOption(QStringLiteral("test-mode"), QStringLiteral("Run automated notification unit tests"));
    QCommandLineOption replaceOption(QStringLiteral("replace"), QStringLiteral("Replace existing notification daemon"));

    parser.addOption(testModeOption);
    parser.addOption(replaceOption);
    parser.process(app);

    if (parser.isSet(testModeOption)) {
        return runSelfTests();
    }

    QDBusConnection sessionBus = QDBusConnection::sessionBus();
    if (!sessionBus.isConnected()) {
        std::cerr << "conj-notificationd: Error: Cannot connect to session D-Bus: "
                  << sessionBus.lastError().message().toStdString() << std::endl;
        return 1;
    }

    auto *mgr = new NotificationManager(&app);

    // Register primary FreeDesktop service: org.freedesktop.Notifications
    QDBusConnection::RegisterOptions opts = QDBusConnection::ExportAllSlots | QDBusConnection::ExportAllSignals;
    if (!sessionBus.registerObject(QStringLiteral("/org/freedesktop/Notifications"), mgr, opts)) {
        std::cerr << "conj-notificationd: Error registering D-Bus object /org/freedesktop/Notifications: "
                  << sessionBus.lastError().message().toStdString() << std::endl;
        return 1;
    }

    // Register Conjunction internal interface on /org/conjunction/Notifications
    if (!sessionBus.registerObject(QStringLiteral("/org/conjunction/Notifications"), mgr, opts)) {
        std::cerr << "conj-notificationd: Error registering D-Bus object /org/conjunction/Notifications: "
                  << sessionBus.lastError().message().toStdString() << std::endl;
        return 1;
    }

    if (!sessionBus.registerService(QStringLiteral("org.freedesktop.Notifications"))) {
        std::cerr << "conj-notificationd: Notice: Could not claim org.freedesktop.Notifications immediately: "
                  << sessionBus.lastError().message().toStdString() << std::endl;
    }

    if (!sessionBus.registerService(QStringLiteral("org.conjunction.Notifications"))) {
        std::cerr << "conj-notificationd: Warning: Could not claim org.conjunction.Notifications: "
                  << sessionBus.lastError().message().toStdString() << std::endl;
    }

    // Also claim org.freedesktop.impl.portal.desktop.plasmanotify so flatpaks routed to plasmanotify reach here
    sessionBus.registerService(QStringLiteral("org.freedesktop.impl.portal.desktop.plasmanotify"));
    sessionBus.registerObject(QStringLiteral("/org/freedesktop/portal/desktop"), mgr, opts);

    std::cout << "conj-notificationd: Ready, listening on org.freedesktop.Notifications and org.conjunction.Notifications" << std::endl;

    return app.exec();
}
