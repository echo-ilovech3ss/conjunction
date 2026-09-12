#include "terminal_find_bar.h"
#include "terminal_session.h"
#include "theme_bridge.h"

#include <QKeyEvent>
#include <KParts/ReadOnlyPart>
#include <KActionCollection>
#include <QAction>

namespace Conjunction {

TerminalFindBar::TerminalFindBar(QWidget *parent)
    : QWidget(parent)
{
    setFixedHeight(40);
    QHBoxLayout *layout = new QHBoxLayout(this);
    layout->setContentsMargins(12, 4, 12, 4);
    layout->setSpacing(8);

    QLabel *iconLabel = new QLabel(QStringLiteral("Find:"), this);
    iconLabel->setStyleSheet("font-weight: 600;");

    m_findInput = new QLineEdit(this);
    m_findInput->setPlaceholderText(QStringLiteral("Search terminal output..."));
    m_findInput->installEventFilter(this);

    m_prevButton = new QPushButton(QStringLiteral("Previous"), this);
    m_nextButton = new QPushButton(QStringLiteral("Next"), this);
    m_statusLabel = new QLabel(this);
    m_statusLabel->setStyleSheet("color: #8E8E93; font-size: 11px;");

    m_closeButton = new QToolButton(this);
    m_closeButton->setText(QStringLiteral("✕"));
    m_closeButton->setToolTip(QStringLiteral("Close find bar (Esc)"));

    layout->addWidget(iconLabel);
    layout->addWidget(m_findInput, 1);
    layout->addWidget(m_prevButton);
    layout->addWidget(m_nextButton);
    layout->addWidget(m_statusLabel);
    layout->addWidget(m_closeButton);

    connect(m_nextButton, &QPushButton::clicked, this, &TerminalFindBar::onNextClicked);
    connect(m_prevButton, &QPushButton::clicked, this, &TerminalFindBar::onPrevClicked);
    connect(m_findInput, &QLineEdit::returnPressed, this, &TerminalFindBar::onNextClicked);
    connect(m_closeButton, &QToolButton::clicked, this, &TerminalFindBar::hideAndReturnFocus);

    hide();
}

void TerminalFindBar::showForSession(TerminalSession *session)
{
    m_session = session;
    show();
    m_findInput->setFocus();
    m_findInput->selectAll();

    // Trigger KonsolePart native find action if available
    if (m_session && m_session->part()) {
        KActionCollection *coll = m_session->part()->actionCollection();
        if (coll) {
            QAction *findAct = coll->action(QStringLiteral("edit_find"));
            if (findAct) {
                findAct->trigger();
            }
        }
    }
}

void TerminalFindBar::hideAndReturnFocus()
{
    hide();
    if (m_session && m_session->widget()) {
        m_session->widget()->setFocus();
    }
}

bool TerminalFindBar::eventFilter(QObject *watched, QEvent *event)
{
    if (watched == m_findInput && event->type() == QEvent::KeyPress) {
        QKeyEvent *ke = static_cast<QKeyEvent *>(event);
        if (ke->key() == Qt::Key_Escape) {
            hideAndReturnFocus();
            return true;
        }
    }
    return QWidget::eventFilter(watched, event);
}

void TerminalFindBar::onNextClicked()
{
    QString text = m_findInput->text();
    if (text.isEmpty()) return;

    if (m_session && m_session->part()) {
        KActionCollection *coll = m_session->part()->actionCollection();
        if (coll) {
            QAction *nextAct = coll->action(QStringLiteral("edit_find_next"));
            if (nextAct) {
                nextAct->trigger();
                return;
            }
        }
    }
    emit findNextRequested(text);
}

void TerminalFindBar::onPrevClicked()
{
    QString text = m_findInput->text();
    if (text.isEmpty()) return;

    if (m_session && m_session->part()) {
        KActionCollection *coll = m_session->part()->actionCollection();
        if (coll) {
            QAction *prevAct = coll->action(QStringLiteral("edit_find_prev"));
            if (prevAct) {
                prevAct->trigger();
                return;
            }
        }
    }
    emit findPrevRequested(text);
}

} // namespace Conjunction
