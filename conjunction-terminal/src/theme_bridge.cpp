#include "theme_bridge.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
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
        QDBusReply<QVariant> reply = iface.call(QStringLiteral("get"), QStringLiteral("appearance.mode"));
        if (reply.isValid()) {
            QString mode = reply.value().toString();
            if (!m_forced) {
                m_isDark = (mode == QStringLiteral("dark"));
            }
        }
        QDBusReply<QVariant> accentReply = iface.call(QStringLiteral("get"), QStringLiteral("appearance.accent"));
        if (accentReply.isValid() && !accentReply.value().toString().isEmpty()) {
            m_accent = accentReply.value().toString();
        }
    }
}

void ThemeBridge::loadFromConfigFile()
{
    QString configPath = QDir::homePath() + QStringLiteral("/.config/conjunction/settings.ini");
    if (QFile::exists(configPath)) {
        QSettings settings(configPath, QSettings::IniFormat);
        QString mode = settings.value(QStringLiteral("appearance/mode"), QStringLiteral("light")).toString();
        if (!m_forced) {
            m_isDark = (mode == QStringLiteral("dark"));
        }
        m_accent = settings.value(QStringLiteral("appearance/accent"), QStringLiteral("blue")).toString();
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
    return m_isDark ? QColor(0x1A, 0x1B, 0x20) : QColor(0xF4, 0xF5, 0xF8);
}

QColor ThemeBridge::surfaceColor() const
{
    return m_isDark ? QColor(0x24, 0x26, 0x2E) : QColor(0xFF, 0xFF, 0xFF);
}

QColor ThemeBridge::surfaceElevatedColor() const
{
    return m_isDark ? QColor(0x2D, 0x30, 0x3A) : QColor(0xFF, 0xFF, 0xFF);
}

QColor ThemeBridge::textPrimaryColor() const
{
    return m_isDark ? QColor(0xF5, 0xF6, 0xF8) : QColor(0x15, 0x16, 0x1A);
}

QColor ThemeBridge::textSecondaryColor() const
{
    return m_isDark ? QColor(0x9E, 0xA2, 0xAD) : QColor(0x5A, 0x5D, 0x66);
}

QColor ThemeBridge::separatorColor() const
{
    return m_isDark ? QColor(0x37, 0x3A, 0x44) : QColor(0xD3, 0xD6, 0xDC);
}

QColor ThemeBridge::accentColor() const
{
    if (m_accent == QStringLiteral("teal")) return m_isDark ? QColor(0x1A, 0x99, 0x88) : QColor(0x0D, 0x7D, 0x6C);
    if (m_accent == QStringLiteral("amber")) return m_isDark ? QColor(0xD9, 0x77, 0x06) : QColor(0xB4, 0x53, 0x09);
    if (m_accent == QStringLiteral("violet")) return m_isDark ? QColor(0x8B, 0x5C, 0xF6) : QColor(0x6D, 0x28, 0xD9);
    if (m_accent == QStringLiteral("graphite")) return m_isDark ? QColor(0x9C, 0xA3, 0xAF) : QColor(0x4B, 0x55, 0x63);
    return m_isDark ? QColor(0x25, 0x63, 0xEB) : QColor(0x1D, 0x4E, 0xD8);
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
