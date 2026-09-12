#pragma once

#include <QObject>
#include <QString>
#include <QColor>
#include <QVariant>

namespace Conjunction {

class ThemeBridge : public QObject {
    Q_OBJECT
public:
    static ThemeBridge &instance();

    bool isDark() const { return m_isDark; }
    QString accent() const { return m_accent; }

    void setForcedDark(bool dark);
    void setForcedLight(bool light);

    QColor backgroundColor() const;
    QColor surfaceColor() const;
    QColor surfaceElevatedColor() const;
    QColor textPrimaryColor() const;
    QColor textSecondaryColor() const;
    QColor separatorColor() const;
    QColor accentColor() const;

    QString windowStyleSheet() const;

signals:
    void themeChanged();

private slots:
    void onSettingChanged(const QString &key, const QVariant &value);

private:
    explicit ThemeBridge(QObject *parent = nullptr);
    void initDBus();
    void loadFromConfigFile();

    bool m_isDark = false;
    bool m_forced = false;
    QString m_accent = QStringLiteral("blue");
};

} // namespace Conjunction
