#pragma once

#include <QMainWindow>
#include <QTabWidget>
#include <QDragEnterEvent>
#include <QDropEvent>
#include <QList>

namespace Conjunction {

class TerminalSession;
class TerminalFindBar;

class TerminalWindow : public QMainWindow {
    Q_OBJECT
public:
    explicit TerminalWindow(QWidget *parent = nullptr);
    ~TerminalWindow() override;

    bool openSession(const QString &workingDir = QString(), const QString &profile = QString());
    bool openProgram(const QString &program, const QStringList &args, const QString &workingDir = QString());

    TerminalSession *activeSession() const;
    int sessionCount() const;

public slots:
    void newTab(const QString &workingDir = QString());
    void newWindow(const QString &workingDir = QString());
    void closeCurrentTab();
    bool closeTab(int index);
    void selectNextTab();
    void selectPreviousTab();
    void moveTabToNewWindow();

    void copyText();
    void pasteText();
    void selectAllText();
    void toggleFind();

    void zoomIn();
    void zoomOut();
    void actualSize();
    void toggleFullScreenMode();

    void clearScrollback();
    void resetTerminal();
    void switchProfile(const QString &name);

    void applyTheme();

protected:
    void dragEnterEvent(QDragEnterEvent *event) override;
    void dropEvent(QDropEvent *event) override;
    void closeEvent(QCloseEvent *event) override;

private slots:
    void onTabCloseRequested(int index);
    void onCurrentTabChanged(int index);
    void onSessionTitleChanged(const QString &title);
    void onSessionFinished();

private:
    void setupUi();
    void setupMenus();
    void populateProfilesMenu();

    QTabWidget *m_tabWidget = nullptr;
    TerminalFindBar *m_findBar = nullptr;
    QList<TerminalSession *> m_sessions;

    QMenu *m_fileMenu = nullptr;
    QMenu *m_editMenu = nullptr;
    QMenu *m_viewMenu = nullptr;
    QMenu *m_shellMenu = nullptr;
    QMenu *m_profilesMenu = nullptr;
    QMenu *m_windowMenu = nullptr;
    QMenu *m_helpMenu = nullptr;

    QAction *m_toggleTabBarAction = nullptr;
    QString m_initialDir;
};

} // namespace Conjunction
