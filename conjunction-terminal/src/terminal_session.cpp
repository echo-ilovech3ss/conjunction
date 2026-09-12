#include "terminal_session.h"

#include <KParts/ReadOnlyPart>

#if __has_include(<kde_terminal_interface.h>)
#include <kde_terminal_interface.h>
#elif __has_include(<KParts/kde_terminal_interface.h>)
#include <KParts/kde_terminal_interface.h>
#elif __has_include(<KF6/KParts/kde_terminal_interface.h>)
#include <KF6/KParts/kde_terminal_interface.h>
#endif
#include <KPluginFactory>
#include <KPluginMetaData>
#include <QFileInfo>
#include <QTimer>
#include <QDebug>
#include <unistd.h>
#include <pwd.h>

namespace Conjunction {

TerminalSession::TerminalSession(QWidget *parentWidget, QObject *parent)
    : QObject(parent)
    , m_parentWidget(parentWidget)
{
}

TerminalSession::~TerminalSession()
{
    if (m_part) {
        m_part->deleteLater();
        m_part = nullptr;
        m_iface = nullptr;
    }
}

bool TerminalSession::initialize(const QString &workingDir, const QString &profile)
{
    QString dir = workingDir;
    if (dir.isEmpty() || !QDir(dir).exists()) {
        dir = QDir::homePath();
    }
    m_initialDir = dir;
    m_currentDir = dir;
    m_activeProfile = profile;

    KPluginMetaData metaData(QStringLiteral("kf6/parts/konsolepart"));
    auto res = KPluginFactory::instantiatePlugin<KParts::ReadOnlyPart>(metaData, m_parentWidget, QVariantList());
    if (!res.plugin) {
        qCritical() << "[TerminalSession] Failed to instantiate KonsolePart (kf6/parts/konsolepart):" << res.errorString;
        return false;
    }

    m_part = res.plugin;
    m_iface = qobject_cast<TerminalInterface *>(m_part);
    if (!m_iface) {
        qCritical() << "[TerminalSession] KonsolePart does not implement TerminalInterface";
        delete m_part;
        m_part = nullptr;
        return false;
    }

    if (!profile.isEmpty()) {
        m_iface->setCurrentProfile(profile);
    }

    // Connect directory changed signal
    connect(m_part, SIGNAL(currentDirectoryChanged(QString)), this, SLOT(onDirectoryChanged(QString)));
    connect(m_part, &QObject::destroyed, this, &TerminalSession::finished);

    // Launch default user login shell in specified directory
    m_iface->showShellInDir(dir);

    // Initial title update
    QTimer::singleShot(200, this, &TerminalSession::checkTitleUpdate);

    return true;
}

bool TerminalSession::startProgram(const QString &program, const QStringList &args, const QString &workingDir)
{
    QString dir = workingDir;
    if (dir.isEmpty() || !QDir(dir).exists()) {
        dir = QDir::homePath();
    }
    m_initialDir = dir;
    m_currentDir = dir;

    KPluginMetaData metaData(QStringLiteral("kf6/parts/konsolepart"));
    auto res = KPluginFactory::instantiatePlugin<KParts::ReadOnlyPart>(metaData, m_parentWidget, QVariantList());
    if (!res.plugin) {
        qCritical() << "[TerminalSession] Failed to instantiate KonsolePart:" << res.errorString;
        return false;
    }

    m_part = res.plugin;
    m_iface = qobject_cast<TerminalInterface *>(m_part);
    if (!m_iface) {
        qCritical() << "[TerminalSession] KonsolePart does not implement TerminalInterface";
        delete m_part;
        m_part = nullptr;
        return false;
    }

    connect(m_part, SIGNAL(currentDirectoryChanged(QString)), this, SLOT(onDirectoryChanged(QString)));
    connect(m_part, &QObject::destroyed, this, &TerminalSession::finished);

    m_iface->showShellInDir(dir);
    m_iface->startProgram(program, args);

    QTimer::singleShot(200, this, &TerminalSession::checkTitleUpdate);
    return true;
}

void TerminalSession::sendInput(const QString &text)
{
    if (m_iface) {
        m_iface->sendInput(text);
    }
}

QWidget *TerminalSession::widget() const
{
    return m_part ? m_part->widget() : nullptr;
}

int TerminalSession::terminalProcessId() const
{
    return m_iface ? m_iface->terminalProcessId() : 0;
}

int TerminalSession::foregroundProcessId() const
{
    return m_iface ? m_iface->foregroundProcessId() : -1;
}

QString TerminalSession::foregroundProcessName() const
{
    return m_iface ? m_iface->foregroundProcessName() : QString();
}

QString TerminalSession::currentWorkingDirectory() const
{
    if (m_iface) {
        QString cwd = m_iface->currentWorkingDirectory();
        if (!cwd.isEmpty()) return cwd;
    }
    return m_currentDir;
}

QStringList TerminalSession::availableProfiles() const
{
    return m_iface ? m_iface->availableProfiles() : QStringList();
}

QString TerminalSession::currentProfileName() const
{
    return m_iface ? m_iface->currentProfileName() : QString();
}

bool TerminalSession::setCurrentProfile(const QString &profileName)
{
    if (m_iface) {
        bool ok = m_iface->setCurrentProfile(profileName);
        if (ok) {
            m_activeProfile = profileName;
            checkTitleUpdate();
        }
        return ok;
    }
    return false;
}

bool TerminalSession::hasActiveForegroundProcess() const
{
    if (!m_iface) return false;

    int fgPid = m_iface->foregroundProcessId();
    int termPid = m_iface->terminalProcessId();

    if (fgPid <= 0) {
        return false;
    }

    // If foreground PID is identical to shell/terminal process, it is idle
    if (fgPid == termPid) {
        return false;
    }

    QString fgName = m_iface->foregroundProcessName().trimmed();
    if (fgName.isEmpty()) {
        return false;
    }

    // Check if foreground process is just a standard shell
    QString baseName = QFileInfo(fgName).fileName();
    if (baseName == QStringLiteral("bash") ||
        baseName == QStringLiteral("zsh") ||
        baseName == QStringLiteral("fish") ||
        baseName == QStringLiteral("sh") ||
        baseName == QStringLiteral("dash") ||
        baseName == QStringLiteral("csh") ||
        baseName == QStringLiteral("tcsh")) {
        return false;
    }

    return true;
}

QString TerminalSession::sessionTitle() const
{
    // Priority:
    // 1. Foreground process name (e.g. "vim", "python")
    // 2. Current working directory basename
    // 3. Profile name if custom
    // 4. "Terminal"
    if (m_iface) {
        QString fg = m_iface->foregroundProcessName().trimmed();
        if (!fg.isEmpty()) {
            QString baseName = QFileInfo(fg).fileName();
            if (baseName != QStringLiteral("bash") &&
                baseName != QStringLiteral("zsh") &&
                baseName != QStringLiteral("fish") &&
                baseName != QStringLiteral("sh")) {
                return baseName;
            }
        }

        QString cwd = currentWorkingDirectory();
        if (!cwd.isEmpty()) {
            if (cwd == QDir::homePath()) {
                return QStringLiteral("~");
            }
            QString dirName = QFileInfo(cwd).fileName();
            if (!dirName.isEmpty()) {
                return dirName;
            }
        }

        QString profile = m_iface->currentProfileName();
        if (!profile.isEmpty() && profile != QStringLiteral("Built-in")) {
            return profile;
        }
    }

    return QStringLiteral("Terminal");
}

void TerminalSession::onDirectoryChanged(const QString &dir)
{
    m_currentDir = dir;
    emit directoryChanged(dir);
    checkTitleUpdate();
}

void TerminalSession::checkTitleUpdate()
{
    QString newTitle = sessionTitle();
    if (newTitle != m_lastTitle) {
        m_lastTitle = newTitle;
        emit titleChanged(newTitle);
    }
}

} // namespace Conjunction
