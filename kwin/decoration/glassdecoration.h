#pragma once

#include <KDecoration3/DecoratedWindow>
#include <KDecoration3/Decoration>
#include <KDecoration3/DecorationButton>
#include <KDecoration3/DecorationShadow>
#include <KDecoration3/DecorationThemeProvider>
#include <KPluginMetaData>
#include <QDBusVariant>
#include <QImage>
#include <memory>

namespace Conjunction
{

class GlassDecoration;

class TrafficLightButton : public KDecoration3::DecorationButton
{
    Q_OBJECT
public:
    explicit TrafficLightButton(KDecoration3::DecorationButtonType type, GlassDecoration *decoration, QObject *parent = nullptr);
    void paint(QPainter *painter, const QRectF &repaintArea) override;

protected:
    void hoverEnterEvent(QHoverEvent *event) override;
    void hoverLeaveEvent(QHoverEvent *event) override;
    void mousePressEvent(QMouseEvent *event) override;
    void mouseReleaseEvent(QMouseEvent *event) override;
};

class GlassDecoration : public KDecoration3::Decoration
{
    Q_OBJECT
public:
    explicit GlassDecoration(QObject *parent = nullptr, const QVariantList &args = QVariantList());
    ~GlassDecoration() override = default;

    bool init() override;
    void paint(QPainter *painter, const QRectF &repaintArea) override;

    bool clusterHovered() const { return m_clusterHovered; }
    void setClusterHovered(bool hovered);
    bool isDark() const { return m_darkMode; }
    bool reduceTransparency() const { return m_reduceTransparency; }
    bool increaseContrast() const { return m_increaseContrast; }
    qreal buttonDiameter() const;

protected:
    void hoverEnterEvent(QHoverEvent *event) override;
    void hoverMoveEvent(QHoverEvent *event) override;
    void hoverLeaveEvent(QHoverEvent *event) override;

private Q_SLOTS:
    void updateLayout();
    void updateShadow();
    void reloadAppearance();
    void onShellSettingChanged(const QString &key, const QVariant &value);

private:
    QRectF clusterHitRect() const;
    qreal titleBarHeight() const;
    void createButtons();

    QList<TrafficLightButton *> m_buttons;
    QRectF m_titleBarRect;
    bool m_clusterHovered = false;
    bool m_darkMode = false;
    bool m_reduceTransparency = false;
    bool m_increaseContrast = false;
    QString m_toolbarStyle = QStringLiteral("unifiedCompact"); // unified (52), unifiedCompact (38), plain (28)

    static std::shared_ptr<KDecoration3::DecorationShadow> s_activeShadow;
    static std::shared_ptr<KDecoration3::DecorationShadow> s_inactiveShadow;
    static void ensureShadows();
};

class GlassThemeProvider : public KDecoration3::DecorationThemeProvider
{
    Q_OBJECT
public:
    explicit GlassThemeProvider(QObject *parent = nullptr, const KPluginMetaData &data = KPluginMetaData());
    QList<KDecoration3::DecorationThemeMetaData> themes() const override;
};

} // namespace Conjunction
