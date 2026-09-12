#pragma once

#include <QWidget>
#include <QLineEdit>
#include <QPushButton>
#include <QToolButton>
#include <QLabel>
#include <QHBoxLayout>

namespace Conjunction {

class TerminalSession;

class TerminalFindBar : public QWidget {
    Q_OBJECT
public:
    explicit TerminalFindBar(QWidget *parent = nullptr);

    void showForSession(TerminalSession *session);
    void hideAndReturnFocus();

signals:
    void findNextRequested(const QString &text);
    void findPrevRequested(const QString &text);

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private slots:
    void onNextClicked();
    void onPrevClicked();

private:
    TerminalSession *m_session = nullptr;
    QLineEdit *m_findInput = nullptr;
    QPushButton *m_prevButton = nullptr;
    QPushButton *m_nextButton = nullptr;
    QLabel *m_statusLabel = nullptr;
    QToolButton *m_closeButton = nullptr;
};

} // namespace Conjunction
