#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QWidget>
#include <QDir>

namespace KParts {
    class ReadOnlyPart;
}
class TerminalInterface;

namespace Conjunction {

class TerminalSession : public QObject {
    Q_OBJECT
public:
    explicit TerminalSession(QWidget *parentWidget = nullptr, QObject *parent = nullptr);
    ~TerminalSession() override;

    bool initialize(const QString &workingDir = QString(), const QString &profile = QString());
    bool startProgram(const QString &program, const QStringList &args, const QString &workingDir = QString());
    void sendInput(const QString &text);

    QWidget *widget() const;
    KParts::ReadOnlyPart *part() const { return m_part; }
    TerminalInterface *terminalInterface() const { return m_iface; }

    int terminalProcessId() const;
    int foregroundProcessId() const;
    QString foregroundProcessName() const;
    QString currentWorkingDirectory() const;
    QStringList availableProfiles() const;
    QString currentProfileName() const;
    bool setCurrentProfile(const QString &profileName);

    bool hasActiveForegroundProcess() const;
    QString sessionTitle() const;

signals:
    void directoryChanged(const QString &dir);
    void titleChanged(const QString &title);
    void finished();

private slots:
    void onDirectoryChanged(const QString &dir);
    void checkTitleUpdate();

private:
    QWidget *m_parentWidget = nullptr;
    KParts::ReadOnlyPart *m_part = nullptr;
    TerminalInterface *m_iface = nullptr;
    QString m_initialDir;
    QString m_currentDir;
    QString m_activeProfile;
    QString m_lastTitle;
};

} // namespace Conjunction
