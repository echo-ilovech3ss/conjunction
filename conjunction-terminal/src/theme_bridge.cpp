#include "theme_bridge.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusVariant>
#include <QSettings>
#include <QDir>
#include <QFile>
#include <QDebug>

namespace Conjunction {

ThemeBridge &ThemeBridge::instance()
{
    static ThemeBridge s_instance;
    return s_instance;
}

ThemeBridge::ThemeBridge(QObject *parent)
    : QObject(parent)
{
    loadFromConfigFile();
    initDBus();
}

void ThemeBridge::initDBus()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        return;
    }

    // Connect to org.conjunction.Settings SettingChanged signal
    bus.connect(QStringLiteral("org.conjunction.Settings"),
                QStringLiteral("/org/conjunction/Settings"),
                QStringLiteral("org.conjunction.Settings"),
                QStringLiteral("SettingChanged"),
                this,
                SLOT(onSettingChanged(QString, QVariant)));

    // Fetch initial appearance setting from D-Bus if service is active
    QDBusInterface iface(QStringLiteral("org.conjunction.Settings"),
                         QStringLiteral("/org/conjunction/Settings"),
                         QStringLiteral("org.conjunction.Settings"),
                         bus);
    if (iface.isValid()) {
        QDBusReply<QDBusVariant> reply = iface.call(QStringLiteral("GetSetting"), QStringLiteral("appearance.mode"));
        if (reply.isValid()) {
            QString mode = reply.value().variant().toString();
            if (!m_forced && !mode.isEmpty()) {
                m_isDark = (mode == QStringLiteral("dark"));
            }
        }
        QDBusReply<QDBusVariant> accentReply = iface.call(QStringLiteral("GetSetting"), QStringLiteral("appearance.accent"));
        if (accentReply.isValid() && !accentReply.value().variant().toString().isEmpty()) {
            m_accent = accentReply.value().variant().toString();
        }
    }
}

void ThemeBridge::loadFromConfigFile()
{
    QString configPath = QDir::homePath() + QStringLiteral("/.config/conjunction/settings.ini");
    if (QFile::exists(configPath)) {
        QSettings settings(configPath, QSettings::IniFormat);
        QString mode = settings.value(QStringLiteral("Appearance/mode"), QStringLiteral("light")).toString();
        if (!m_forced) {
            m_isDark = (mode == QStringLiteral("dark"));
        }
        m_accent = settings.value(QStringLiteral("Appearance/accent"), QStringLiteral("blue")).toString();
    }
}

void ThemeBridge::setForcedDark(bool dark)
{
    m_forced = true;
    m_isDark = dark;
    emit themeChanged();
}

void ThemeBridge::setForcedLight(bool light)
{
    m_forced = true;
    m_isDark = !light;
    emit themeChanged();
}

void ThemeBridge::onSettingChanged(const QString &key, const QVariant &value)
{
    if (m_forced) return;

    if (key == QStringLiteral("appearance.mode")) {
        QString mode = value.toString();
        bool newDark = (mode == QStringLiteral("dark"));
        if (newDark != m_isDark) {
            m_isDark = newDark;
            emit themeChanged();
        }
    } else if (key == QStringLiteral("appearance.accent")) {
        QString accent = value.toString();
        if (!accent.isEmpty() && accent != m_accent) {
            m_accent = accent;
            emit themeChanged();
        }
    }
}

QColor ThemeBridge::backgroundColor() const
{
    return m_isDark ? QColor(0x1E, 0x1E, 0x1E) : QColor(0xEC, 0xEC, 0xEC);
}

QColor ThemeBridge::surfaceColor() const
{
    return m_isDark ? QColor(0x32, 0x32, 0x32) : QColor(0xFF, 0xFF, 0xFF);
}

QColor ThemeBridge::surfaceElevatedColor() const
{
    return m_isDark ? QColor(0x2C, 0x2C, 0x2E) : QColor(0xF4, 0xF4, 0xF4);
}

QColor ThemeBridge::textPrimaryColor() const
{
    return m_isDark ? QColor(0xFF, 0xFF, 0xFF, 216) : QColor(0x00, 0x00, 0x00, 216);
}

QColor ThemeBridge::textSecondaryColor() const
{
    return m_isDark ? QColor(0xFF, 0xFF, 0xFF, 140) : QColor(0x00, 0x00, 0x00, 127);
}

QColor ThemeBridge::separatorColor() const
{
    return m_isDark ? QColor(0xFF, 0xFF, 0xFF, 25) : QColor(0x00, 0x00, 0x00, 25);
}

QColor ThemeBridge::accentColor() const
{
    if (m_accent == QStringLiteral("teal")) return m_isDark ? QColor(0x00, 0xD2, 0xE0) : QColor(0x00, 0xC3, 0xD0);
    if (m_accent == QStringLiteral("amber")) return m_isDark ? QColor(0xFF, 0x92, 0x30) : QColor(0xFF, 0x8D, 0x28);
    if (m_accent == QStringLiteral("violet")) return m_isDark ? QColor(0x6D, 0x7C, 0xFF) : QColor(0x61, 0x55, 0xF5);
    if (m_accent == QStringLiteral("graphite")) return m_isDark ? QColor(0x98, 0x98, 0x9D) : QColor(0x8E, 0x8E, 0x93);
    return m_isDark ? QColor(0x00, 0x91, 0xFF) : QColor(0x00, 0x88, 0xFF);
}

QString ThemeBridge::windowStyleSheet() const
{
    QString bg = backgroundColor().name();
    QString surface = surfaceColor().name();
    QString elevated = surfaceElevatedColor().name();
    QString text = textPrimaryColor().name();
    QString textSec = textSecondaryColor().name();
    QString sep = separatorColor().name();
    QString accent = accentColor().name();

    return QString(
        "QMainWindow { background-color: %1; color: %4; }\n"
        "QMenuBar { background-color: %2; color: %4; border-bottom: 1px solid %6; padding: 2px 8px; }\n"
        "QMenuBar::item { background: transparent; padding: 4px 8px; border-radius: 4px; }\n"
        "QMenuBar::item:selected { background-color: %7; color: #FFFFFF; }\n"
        "QMenu { background-color: %3; color: %4; border: 1px solid %6; border-radius: 6px; padding: 4px; }\n"
        "QMenu::item { padding: 5px 20px 5px 12px; border-radius: 4px; }\n"
        "QMenu::item:selected { background-color: %7; color: #FFFFFF; }\n"
        "QMenu::separator { height: 1px; background-color: %6; margin: 4px 8px; }\n"
        "QTabWidget::pane { border: none; background-color: transparent; }\n"
        "QTabBar { background-color: %2; border-bottom: 1px solid %6; }\n"
        "QTabBar::tab { background-color: %2; color: %5; padding: 6px 16px; border: none; border-bottom: 2px solid transparent; min-width: 120px; font-weight: 500; }\n"
        "QTabBar::tab:selected { background-color: %1; color: %4; border-bottom: 2px solid %7; font-weight: 600; }\n"
        "QTabBar::tab:hover:!selected { background-color: %3; color: %4; }\n"
        "QTabBar::close-button { subcontrol-position: right; margin: 2px; padding: 2px; }\n"
        "QTabBar::close-button:hover { background-color: %6; border-radius: 2px; }\n"
        "QLineEdit { background-color: %3; color: %4; border: 1px solid %6; border-radius: 6px; padding: 4px 8px; }\n"
        "QLineEdit:focus { border: 1px solid %7; }\n"
        "QPushButton { background-color: %2; color: %4; border: 1px solid %6; border-radius: 6px; padding: 4px 12px; font-weight: 500; }\n"
        "QPushButton:hover { background-color: %3; }\n"
        "QPushButton:pressed { background-color: %6; }\n"
        "QToolButton { background-color: transparent; color: %4; border: none; border-radius: 4px; padding: 3px; }\n"
        "QToolButton:hover { background-color: %6; }\n"
        "QLabel { color: %4; }\n"
    ).arg(bg, surface, elevated, text, textSec, sep, accent);
}

} // namespace Conjunction
