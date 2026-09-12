#include <iostream>
#include <cassert>
#include <QCoreApplication>
#include <QJsonObject>
#include <QJsonDocument>
#include <QJsonArray>
#include <QStandardPaths>
#include <QDir>
#include <QFile>

#include "../src/notification_manager.h"

int runSelfTests()
{
    int passed = 0;
    int failed = 0;

    auto test = [&](const char *name, bool condition) {
        if (condition) {
            std::cout << "  [PASS] " << name << std::endl;
            passed++;
        } else {
            std::cerr << "  [FAIL] " << name << std::endl;
            failed++;
        }
    };

    std::cout << "\n=== Running Conjunction Notification Daemon Unit Tests ===" << std::endl;

    NotificationManager mgr;

    // 1. Capabilities
    QStringList caps = mgr.GetCapabilities();
    test("capabilities: contains actions", caps.contains(QStringLiteral("actions")));
    test("capabilities: contains body", caps.contains(QStringLiteral("body")));
    test("capabilities: contains body-markup", caps.contains(QStringLiteral("body-markup")));
    test("capabilities: contains persistence", caps.contains(QStringLiteral("persistence")));

    // 2. Server info
    QString vendor, version, spec;
    QString name = mgr.GetServerInformation(vendor, version, spec);
    test("server_info: name is Conjunction Notification Daemon", name.contains(QStringLiteral("Conjunction")));
    test("server_info: vendor is Conjunction", vendor == QStringLiteral("Conjunction"));

    // 3. Markup sanitization
    QString malicious = QStringLiteral("<script>alert('pwned')</script>Hello <b>world</b>! <img src='http://evil.com/x.png'> &amp; &lt;test&gt;");
    QString clean = NotificationManager::sanitizeMarkup(malicious);
    test("sanitize: script tag removed", !clean.contains(QStringLiteral("script")) && !clean.contains(QStringLiteral("alert")));
    test("sanitize: remote img tag removed", !clean.contains(QStringLiteral("<img")));
    test("sanitize: safe content preserved", clean.contains(QStringLiteral("Hello world! & <test>")));

    // 4. Basic notification creation
    mgr.ClearAll();
    uint id1 = mgr.Notify(
        QStringLiteral("Terminal"),
        0,
        QStringLiteral("utilities-terminal"),
        QStringLiteral("Build Succeeded"),
        QStringLiteral("Compilation finished in 4.2s"),
        QStringList() << QStringLiteral("open") << QStringLiteral("Open Terminal"),
        QVariantMap(),
        5000
    );
    test("notify: valid id assigned", id1 > 0);

    // 5. History and banner presence
    QString historyJson = mgr.GetHistoryJson();
    QJsonDocument doc = QJsonDocument::fromJson(historyJson.toUtf8());
    test("history: recorded notification item", doc.isArray() && doc.array().size() == 1);
    QJsonObject obj1 = doc.array().at(0).toObject();
    test("history: fields match", obj1.value("summary").toString() == QStringLiteral("Build Succeeded"));

    // 6. Replacement ID semantics
    uint id_replaced = mgr.Notify(
        QStringLiteral("Terminal"),
        id1,
        QStringLiteral("utilities-terminal"),
        QStringLiteral("Build Updated"),
        QStringLiteral("Running tests now..."),
        QStringList(),
        QVariantMap(),
        5000
    );
    test("replacement: reused original id", id_replaced == id1);
    doc = QJsonDocument::fromJson(mgr.GetHistoryJson().toUtf8());
    test("replacement: history count still 1", doc.array().size() == 1);
    test("replacement: summary updated", doc.array().at(0).toObject().value("summary").toString() == QStringLiteral("Build Updated"));

    // 7. Do Not Disturb suppression
    mgr.setDoNotDisturbOverride(true);
    uint id_dnd = mgr.Notify(
        QStringLiteral("Files"),
        0,
        QStringLiteral("system-file-manager"),
        QStringLiteral("Copy complete"),
        QStringLiteral("Copied 3 files"),
        QStringList(),
        QVariantMap(),
        5000
    );
    QString bannersJson = mgr.GetActiveBannersJson();
    test("dnd: banner suppressed when DND is active", !bannersJson.contains(QStringLiteral("Copy complete")));
    test("dnd: notification still recorded in history", mgr.GetHistoryJson().contains(QStringLiteral("Copy complete")));

    // 8. Critical notification overrides DND
    QVariantMap critHints;
    critHints[QStringLiteral("urgency")] = 2; // Critical
    uint id_crit = mgr.Notify(
        QStringLiteral("Battery"),
        0,
        QStringLiteral("battery-caution"),
        QStringLiteral("Battery Low"),
        QStringLiteral("5% remaining, connect charger"),
        QStringList(),
        critHints,
        0
    );
    test("dnd: critical notification shows banner despite DND", mgr.GetActiveBannersJson().contains(QStringLiteral("Battery Low")));

    // Reset DND override
    mgr.setDoNotDisturbOverride(false);

    // 9. Dismissal and Action invocation
    bool actionInvokedFired = false;
    QObject::connect(&mgr, &NotificationManager::ActionInvoked, [&](uint id, const QString &key) {
        if (id == id_crit && key == QStringLiteral("charge")) {
            actionInvokedFired = true;
        }
    });
    mgr.TriggerAction(id_crit, QStringLiteral("charge"));
    test("action: ActionInvoked signal emitted", actionInvokedFired);
    test("dismiss: notification removed from active banners", !mgr.GetActiveBannersJson().contains(QStringLiteral("Battery Low")));

    // 10. ClearAll
    mgr.ClearAll();
    test("clear_all: history is empty", mgr.GetHistoryJson() == QStringLiteral("[]"));
    test("clear_all: active banners is empty", mgr.GetActiveBannersJson() == QStringLiteral("[]"));

    std::cout << "\n=== Tests Completed: " << passed << " passed, " << failed << " failed ===" << std::endl;
    return (failed == 0) ? 0 : 1;
}

#ifdef TEST_STANDALONE_MAIN
int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    return runSelfTests();
}
#endif
