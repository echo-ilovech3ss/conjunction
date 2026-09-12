#include "terminal_window.h"
#include "terminal_session.h"
#include "terminal_find_bar.h"
#include "theme_bridge.h"
#include "shell_escape.h"

#include <QMenuBar>
#include <QMenu>
#include <QAction>
#include <QTabBar>
#include <QToolButton>
#include <QMessageBox>
#include <QMimeData>
#include <QUrl>
#include <QFileInfo>
#include <QApplication>
#include <QClipboard>
#include <KParts/ReadOnlyPart>
#include <KActionCollection>

namespace Conjunction {

TerminalWindow::TerminalWindow(QWidget *parent)
    : QMainWindow(parent)
{
    setAcceptDrops(true);
    resize(840, 520);
    setWindowTitle(QStringLiteral("Terminal — Conjunction"));

    setupUi();
    setupMenus();

    connect(&ThemeBridge::instance(), &ThemeBridge::themeChanged, this, &TerminalWindow::applyTheme);
    applyTheme();
}

TerminalWindow::~TerminalWindow()
{
}

void TerminalWindow::setupUi()
{
    QWidget *centralWidget = new QWidget(this);
    QVBoxLayout *mainLayout = new QVBoxLayout(centralWidget);
    mainLayout->setContentsMargins(0, 0, 0, 0);
    mainLayout->setSpacing(0);

    m_tabWidget = new QTabWidget(centralWidget);
    m_tabWidget->setDocumentMode(true);
    m_tabWidget->setTabsClosable(true);
    m_tabWidget->setMovable(true);

    // New Tab "+" button in corner of tab bar
    QToolButton *newTabBtn = new QToolButton(m_tabWidget);
    newTabBtn->setText(QStringLiteral("+"));
    newTabBtn->setToolTip(QStringLiteral("New Tab (Ctrl+Shift+T)"));
    newTabBtn->setCursor(Qt::PointingHandCursor);
    newTabBtn->setStyleSheet("font-size: 16px; font-weight: bold; padding: 2px 8px;");
    connect(newTabBtn, &QToolButton::clicked, this, [this]() {
        newTab();
    });
    m_tabWidget->setCornerWidget(newTabBtn, Qt::TopRightCorner);

    m_findBar = new TerminalFindBar(centralWidget);

    mainLayout->addWidget(m_tabWidget, 1);
    mainLayout->addWidget(m_findBar);

    setCentralWidget(centralWidget);

    connect(m_tabWidget, &QTabWidget::tabCloseRequested, this, &TerminalWindow::onTabCloseRequested);
    connect(m_tabWidget, &QTabWidget::currentChanged, this, &TerminalWindow::onCurrentTabChanged);
}

void TerminalWindow::setupMenus()
{
    QMenuBar *mb = menuBar();

    // 1. File Menu
    m_fileMenu = mb->addMenu(QStringLiteral("&File"));
    QAction *newWinAct = m_fileMenu->addAction(QStringLiteral("New Window"), this, [this]() { newWindow(); });
    newWinAct->setShortcut(QKeySequence(QStringLiteral("Ctrl+Shift+N")));

    QAction *newTabAct = m_fileMenu->addAction(QStringLiteral("New Tab"), this, [this]() { newTab(); });
    newTabAct->setShortcut(QKeySequence(QStringLiteral("Ctrl+Shift+T")));

    m_fileMenu->addSeparator();
    QAction *closeTabAct = m_fileMenu->addAction(QStringLiteral("Close Tab"), this, &TerminalWindow::closeCurrentTab);
    closeTabAct->setShortcut(QKeySequence(QStringLiteral("Ctrl+Shift+W")));

    QAction *closeWinAct = m_fileMenu->addAction(QStringLiteral("Close Window"), this, &QWidget::close);
    closeWinAct->setShortcut(QKeySequence(QStringLiteral("Ctrl+Shift+Q")));

    // 2. Edit Menu
    m_editMenu = mb->addMenu(QStringLiteral("&Edit"));
    QAction *copyAct = m_editMenu->addAction(QStringLiteral("Copy"), this, &TerminalWindow::copyText);
    copyAct->setShortcut(QKeySequence(QStringLiteral("Ctrl+Shift+C")));

    QAction *pasteAct = m_editMenu->addAction(QStringLiteral("Paste"), this, &TerminalWindow::pasteText);
    pasteAct->setShortcut(QKeySequence(QStringLiteral("Ctrl+Shift+V")));

    QAction *selAllAct = m_editMenu->addAction(QStringLiteral("Select All"), this, &TerminalWindow::selectAllText);
    selAllAct->setShortcut(QKeySequence(QStringLiteral("Ctrl+Shift+A")));

    m_editMenu->addSeparator();
    QAction *findAct = m_editMenu->addAction(QStringLiteral("Find..."), this, &TerminalWindow::toggleFind);
    findAct->setShortcut(QKeySequence(QStringLiteral("Ctrl+Shift+F")));

    // 3. View Menu
    m_viewMenu = mb->addMenu(QStringLiteral("&View"));
    m_toggleTabBarAction = m_viewMenu->addAction(QStringLiteral("Show Tab Bar"), this, [this]() {
        m_tabWidget->tabBar()->setVisible(!m_tabWidget->tabBar()->isVisible());
    });
    m_toggleTabBarAction->setCheckable(true);
    m_toggleTabBarAction->setChecked(true);

    m_viewMenu->addSeparator();
    QAction *zoomInAct = m_viewMenu->addAction(QStringLiteral("Zoom In"), this, &TerminalWindow::zoomIn);
    zoomInAct->setShortcut(QKeySequence(QStringLiteral("Ctrl++")));

    QAction *zoomOutAct = m_viewMenu->addAction(QStringLiteral("Zoom Out"), this, &TerminalWindow::zoomOut);
    zoomOutAct->setShortcut(QKeySequence(QStringLiteral("Ctrl+-")));

    QAction *actualSizeAct = m_viewMenu->addAction(QStringLiteral("Actual Size"), this, &TerminalWindow::actualSize);
    actualSizeAct->setShortcut(QKeySequence(QStringLiteral("Ctrl+0")));

    m_viewMenu->addSeparator();
    QAction *fullScreenAct = m_viewMenu->addAction(QStringLiteral("Toggle Full Screen"), this, &TerminalWindow::toggleFullScreenMode);
    fullScreenAct->setShortcut(QKeySequence(Qt::Key_F11));

    // 4. Shell Menu
    m_shellMenu = mb->addMenu(QStringLiteral("&Shell"));
    QAction *clearAct = m_shellMenu->addAction(QStringLiteral("Clear Scrollback"), this, &TerminalWindow::clearScrollback);
    clearAct->setShortcut(QKeySequence(QStringLiteral("Ctrl+Shift+K")));
    m_shellMenu->addAction(QStringLiteral("Reset Terminal"), this, &TerminalWindow::resetTerminal);
    m_shellMenu->addSeparator();

    m_profilesMenu = m_shellMenu->addMenu(QStringLiteral("Profiles"));
    populateProfilesMenu();

    // 5. Window Menu
    m_windowMenu = mb->addMenu(QStringLiteral("&Window"));
    QAction *nextTabAct = m_windowMenu->addAction(QStringLiteral("Select Next Tab"), this, &TerminalWindow::selectNextTab);
    nextTabAct->setShortcut(QKeySequence(QStringLiteral("Ctrl+Shift+]")));

    QAction *prevTabAct = m_windowMenu->addAction(QStringLiteral("Select Previous Tab"), this, &TerminalWindow::selectPreviousTab);
    prevTabAct->setShortcut(QKeySequence(QStringLiteral("Ctrl+Shift+[")));

    m_windowMenu->addSeparator();
    m_windowMenu->addAction(QStringLiteral("Move Tab to New Window"), this, &TerminalWindow::moveTabToNewWindow);

    // 6. Help Menu
    m_helpMenu = mb->addMenu(QStringLiteral("&Help"));
    m_helpMenu->addAction(QStringLiteral("About Conjunction Terminal"), this, [this]() {
        QMessageBox::about(this, QStringLiteral("About Conjunction Terminal"),
            QStringLiteral("<h3>Conjunction Terminal</h3>"
                           "<p>Version 1.0.0</p>"
                           "<p>A modern, macOS-inspired desktop terminal for Conjunction OS.<br>"
                           "Powered by KDE KonsolePart architecture.</p>"));
    });
}

void TerminalWindow::populateProfilesMenu()
{
    m_profilesMenu->clear();
    TerminalSession *s = activeSession();
    QStringList profiles = s ? s->availableProfiles() : QStringList();
    QString current = s ? s->currentProfileName() : QString();

    if (profiles.isEmpty()) {
        profiles << QStringLiteral("Built-in");
    }

    for (const QString &prof : profiles) {
        QAction *act = m_profilesMenu->addAction(prof, this, [this, prof]() {
            switchProfile(prof);
        });
        act->setCheckable(true);
        if (prof == current || (current.isEmpty() && prof == QStringLiteral("Built-in"))) {
            act->setChecked(true);
        }
    }
}

bool TerminalWindow::openSession(const QString &workingDir, const QString &profile)
{
    TerminalSession *session = new TerminalSession(m_tabWidget, this);
    if (!session->initialize(workingDir, profile)) {
        delete session;
        return false;
    }

    m_sessions.append(session);
    QWidget *w = session->widget();
    int idx = m_tabWidget->addTab(w, session->sessionTitle());
    m_tabWidget->setCurrentIndex(idx);

    connect(session, &TerminalSession::titleChanged, this, &TerminalWindow::onSessionTitleChanged);
    connect(session, &TerminalSession::finished, this, &TerminalWindow::onSessionFinished);

    if (w) {
        w->setFocus();
    }
    populateProfilesMenu();
    return true;
}

bool TerminalWindow::openProgram(const QString &program, const QStringList &args, const QString &workingDir)
{
    TerminalSession *session = new TerminalSession(m_tabWidget, this);
    if (!session->startProgram(program, args, workingDir)) {
        delete session;
        return false;
    }

    m_sessions.append(session);
    QWidget *w = session->widget();
    int idx = m_tabWidget->addTab(w, session->sessionTitle());
    m_tabWidget->setCurrentIndex(idx);

    connect(session, &TerminalSession::titleChanged, this, &TerminalWindow::onSessionTitleChanged);
    connect(session, &TerminalSession::finished, this, &TerminalWindow::onSessionFinished);

    if (w) {
        w->setFocus();
    }
    populateProfilesMenu();
    return true;
}

TerminalSession *TerminalWindow::activeSession() const
{
    int idx = m_tabWidget->currentIndex();
    if (idx >= 0 && idx < m_sessions.size()) {
        return m_sessions.at(idx);
    }
    return nullptr;
}

int TerminalWindow::sessionCount() const
{
    return m_sessions.size();
}

void TerminalWindow::newTab(const QString &workingDir)
{
    QString dir = workingDir;
    if (dir.isEmpty()) {
        TerminalSession *cur = activeSession();
        dir = cur ? cur->currentWorkingDirectory() : QDir::homePath();
    }
    openSession(dir);
}

void TerminalWindow::newWindow(const QString &workingDir)
{
    QString dir = workingDir;
    if (dir.isEmpty()) {
        TerminalSession *cur = activeSession();
        dir = cur ? cur->currentWorkingDirectory() : QDir::homePath();
    }
    TerminalWindow *win = new TerminalWindow();
    win->openSession(dir);
    win->show();
}

void TerminalWindow::closeCurrentTab()
{
    closeTab(m_tabWidget->currentIndex());
}

bool TerminalWindow::closeTab(int index)
{
    if (index < 0 || index >= m_sessions.size()) {
        return false;
    }

    TerminalSession *session = m_sessions.at(index);
    if (session->hasActiveForegroundProcess()) {
        QString procName = session->foregroundProcessName();
        int pid = session->foregroundProcessId();
        auto res = QMessageBox::warning(this,
            QStringLiteral("Terminate Process?"),
            QStringLiteral("Closing this tab will terminate '%1' (PID %2).\nDo you want to continue?").arg(procName).arg(pid),
            QMessageBox::Yes | QMessageBox::Cancel,
            QMessageBox::Cancel);

        if (res != QMessageBox::Yes) {
            return false;
        }
    }

    m_sessions.removeAt(index);
    m_tabWidget->removeTab(index);
    session->deleteLater();

    if (m_sessions.isEmpty()) {
        close();
    } else {
        TerminalSession *cur = activeSession();
        if (cur && cur->widget()) {
            cur->widget()->setFocus();
        }
    }
    return true;
}

void TerminalWindow::selectNextTab()
{
    int count = m_tabWidget->count();
    if (count > 1) {
        int next = (m_tabWidget->currentIndex() + 1) % count;
        m_tabWidget->setCurrentIndex(next);
    }
}

void TerminalWindow::selectPreviousTab()
{
    int count = m_tabWidget->count();
    if (count > 1) {
        int prev = (m_tabWidget->currentIndex() - 1 + count) % count;
        m_tabWidget->setCurrentIndex(prev);
    }
}

void TerminalWindow::moveTabToNewWindow()
{
    if (m_sessions.size() <= 1) return;
    int idx = m_tabWidget->currentIndex();
    if (idx < 0) return;

    TerminalSession *s = m_sessions.at(idx);
    QString dir = s->currentWorkingDirectory();
    QString profile = s->currentProfileName();

    closeTab(idx);

    TerminalWindow *win = new TerminalWindow();
    win->openSession(dir, profile);
    win->show();
}

void TerminalWindow::copyText()
{
    TerminalSession *s = activeSession();
    if (s && s->part()) {
        KActionCollection *coll = s->part()->actionCollection();
        if (coll) {
            QAction *act = coll->action(QStringLiteral("edit_copy"));
            if (act) {
                act->trigger();
                return;
            }
        }
    }
}

void TerminalWindow::pasteText()
{
    TerminalSession *s = activeSession();
    if (s && s->part()) {
        KActionCollection *coll = s->part()->actionCollection();
        if (coll) {
            QAction *act = coll->action(QStringLiteral("edit_paste"));
            if (act) {
                act->trigger();
                return;
            }
        }
        // Fallback: send clipboard text directly
        QClipboard *clipboard = QApplication::clipboard();
        if (clipboard && clipboard->mimeData()->hasText()) {
            s->sendInput(clipboard->text());
        }
    }
}

void TerminalWindow::selectAllText()
{
    TerminalSession *s = activeSession();
    if (s && s->part()) {
        KActionCollection *coll = s->part()->actionCollection();
        if (coll) {
            QAction *act = coll->action(QStringLiteral("edit_select_all"));
            if (act) act->trigger();
        }
    }
}

void TerminalWindow::toggleFind()
{
    if (m_findBar->isVisible()) {
        m_findBar->hideAndReturnFocus();
    } else {
        m_findBar->showForSession(activeSession());
    }
}

void TerminalWindow::zoomIn()
{
    TerminalSession *s = activeSession();
    if (s && s->part()) {
        KActionCollection *coll = s->part()->actionCollection();
        if (coll) {
            QAction *act = coll->action(QStringLiteral("enlarge-font"));
            if (act) act->trigger();
        }
    }
}

void TerminalWindow::zoomOut()
{
    TerminalSession *s = activeSession();
    if (s && s->part()) {
        KActionCollection *coll = s->part()->actionCollection();
        if (coll) {
            QAction *act = coll->action(QStringLiteral("shrink-font"));
            if (act) act->trigger();
        }
    }
}

void TerminalWindow::actualSize()
{
    TerminalSession *s = activeSession();
    if (s && s->part()) {
        KActionCollection *coll = s->part()->actionCollection();
        if (coll) {
            QAction *act = coll->action(QStringLiteral("reset-font-size"));
            if (act) act->trigger();
        }
    }
}

void TerminalWindow::toggleFullScreenMode()
{
    if (isFullScreen()) {
        showNormal();
    } else {
        showFullScreen();
    }
}

void TerminalWindow::clearScrollback()
{
    TerminalSession *s = activeSession();
    if (s && s->part()) {
        KActionCollection *coll = s->part()->actionCollection();
        if (coll) {
            QAction *act = coll->action(QStringLiteral("clear-history-and-reset"));
            if (act) {
                act->trigger();
                return;
            }
        }
        s->sendInput(QStringLiteral("clear\n"));
    }
}

void TerminalWindow::resetTerminal()
{
    TerminalSession *s = activeSession();
    if (s && s->part()) {
        KActionCollection *coll = s->part()->actionCollection();
        if (coll) {
            QAction *act = coll->action(QStringLiteral("reset-terminal"));
            if (act) {
                act->trigger();
                return;
            }
        }
        s->sendInput(QStringLiteral("reset\n"));
    }
}

void TerminalWindow::switchProfile(const QString &name)
{
    TerminalSession *s = activeSession();
    if (s) {
        s->setCurrentProfile(name);
        populateProfilesMenu();
    }
}

void TerminalWindow::applyTheme()
{
    setStyleSheet(ThemeBridge::instance().windowStyleSheet());
}

void TerminalWindow::dragEnterEvent(QDragEnterEvent *event)
{
    if (event->mimeData()->hasUrls() || event->mimeData()->hasText()) {
        event->acceptProposedAction();
    }
}

void TerminalWindow::dropEvent(QDropEvent *event)
{
    TerminalSession *s = activeSession();
    if (!s) return;

    if (event->mimeData()->hasUrls()) {
        QStringList filePaths;
        const auto urls = event->mimeData()->urls();
        for (const QUrl &url : urls) {
            if (url.isLocalFile()) {
                filePaths.append(url.toLocalFile());
            } else {
                filePaths.append(url.toString());
            }
        }

        if (!filePaths.isEmpty()) {
            QString escaped = escapeDroppedPaths(filePaths);
            // Append space but NEVER append newline or enter!
            s->sendInput(escaped + QStringLiteral(" "));
            event->acceptProposedAction();
            return;
        }
    }

    if (event->mimeData()->hasText()) {
        QString text = event->mimeData()->text();
        // Disallow dangerous newline execution from unvalidated dragged raw text
        text.replace(QLatin1Char('\n'), QLatin1Char(' '));
        text.replace(QLatin1Char('\r'), QLatin1Char(' '));
        s->sendInput(text);
        event->acceptProposedAction();
    }
}

void TerminalWindow::closeEvent(QCloseEvent *event)
{
    for (int i = 0; i < m_sessions.size(); ++i) {
        TerminalSession *s = m_sessions.at(i);
        if (s->hasActiveForegroundProcess()) {
            QString proc = s->foregroundProcessName();
            int pid = s->foregroundProcessId();
            auto res = QMessageBox::warning(this,
                QStringLiteral("Terminate Processes and Close Window?"),
                QStringLiteral("Closing this window will terminate running process '%1' (PID %2).\nAre you sure you want to close?").arg(proc).arg(pid),
                QMessageBox::Yes | QMessageBox::Cancel,
                QMessageBox::Cancel);

            if (res != QMessageBox::Yes) {
                event->ignore();
                return;
            }
            break;
        }
    }
    event->accept();
}

void TerminalWindow::onTabCloseRequested(int index)
{
    closeTab(index);
}

void TerminalWindow::onCurrentTabChanged(int index)
{
    if (index >= 0 && index < m_sessions.size()) {
        TerminalSession *s = m_sessions.at(index);
        setWindowTitle(QStringLiteral("%1 — Terminal").arg(s->sessionTitle()));
        if (s->widget()) {
            s->widget()->setFocus();
        }
        populateProfilesMenu();
    }
}

void TerminalWindow::onSessionTitleChanged(const QString &title)
{
    TerminalSession *senderSession = qobject_cast<TerminalSession *>(sender());
    int idx = m_sessions.indexOf(senderSession);
    if (idx >= 0) {
        m_tabWidget->setTabText(idx, title);
        if (idx == m_tabWidget->currentIndex()) {
            setWindowTitle(QStringLiteral("%1 — Terminal").arg(title));
        }
    }
}

void TerminalWindow::onSessionFinished()
{
    TerminalSession *senderSession = qobject_cast<TerminalSession *>(sender());
    int idx = m_sessions.indexOf(senderSession);
    if (idx >= 0) {
        closeTab(idx);
    }
}

} // namespace Conjunction
