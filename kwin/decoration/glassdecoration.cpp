#include "glassdecoration.h"

#include <KConfig>
#include <KConfigGroup>
#include <KDecoration3/DecorationSettings>
#include <KPluginFactory>
#include <KSharedConfig>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDir>
#include <QGuiApplication>
#include <QHoverEvent>
#include <QMouseEvent>
#include <QPainter>
#include <QPainterPath>
#include <QSettings>
#include <QStandardPaths>
#include <QtMath>

namespace Conjunction
{

std::shared_ptr<KDecoration3::DecorationShadow> GlassDecoration::s_activeShadow;
std::shared_ptr<KDecoration3::DecorationShadow> GlassDecoration::s_inactiveShadow;

namespace
{
// SPEC §2.5 Empirical active window drop shadow alpha falloff curve
// Bottom pad = 74 pt, Side pad = 56 pt, Top pad = 38 pt; inactive = 0.52x active
QImage buildSpecShadowImage(qreal opacityScale)
{
    constexpr int padL = 56;
    constexpr int padR = 56;
    constexpr int padT = 38;
    constexpr int padB = 74;
    constexpr int cornerR = 16;
    // Inner cutout width/height inside corner tiles (overlap behind 16pt corners prevents 9-patch seam)
    constexpr int innerSpan = 48;
    const int texW = padL + innerSpan + padR; // 160
    const int texH = padT + innerSpan + padB; // 160

    const QRectF winRect(padL, padT, innerSpan, innerSpan);

    auto evalEdgeAlpha = [](qreal dOut, qreal nY) -> qreal {
        if (dOut <= 0.0) {
            return 0.0;
        }
        // Asymmetric directional falloff (SPEC §2.5):
        // Bottom (nY -> +1): 0.341@0.5, 0.157@2.5, 0.118@6.5, 0.078@10.5, 0.027@16.5, 0.004@26.5
        // Side   (nY ->  0): 0.286@0.5, 0.063@1.5, 0.012@3.5
        // Top    (nY -> -1): 0.231@0.5, 0.031@1.0, 0.004@3.5
        const qreal bottomW = qBound(0.0, nY, 1.0);
        const qreal topW = qBound(0.0, -nY, 1.0);
        const qreal sideW = 1.0 - bottomW - topW;

        const qreal aBottom = 0.20 * qExp(-dOut / 2.2) + 0.145 * qExp(-(dOut * dOut) / (2.0 * 11.5 * 11.5));
        const qreal aSide = 0.286 * qExp(-dOut / 1.15);
        const qreal aTop = 0.231 * qExp(-dOut / 0.65);
        const qreal a = bottomW * aBottom + sideW * aSide + topW * aTop;
        return (a < 0.002) ? 0.0 : qBound(0.0, a, 1.0);
    };

    QImage img(texW, texH, QImage::Format_ARGB32_Premultiplied);
    img.fill(Qt::transparent);

    const qreal cx = winRect.center().x();
    const qreal cy = winRect.center().y();
    const qreal hx = winRect.width() * 0.5;
    const qreal hy = winRect.height() * 0.5;

    for (int y = 0; y < texH; ++y) {
        auto *line = reinterpret_cast<QRgb *>(img.scanLine(y));
        const qreal py = (y + 0.5) - cy;
        for (int x = 0; x < texW; ++x) {
            const qreal px = (x + 0.5) - cx;
            const qreal qx = qAbs(px) - hx + cornerR;
            const qreal qy = qAbs(py) - hy + cornerR;
            const qreal kx = qMax(qx, 0.0);
            const qreal ky = qMax(qy, 0.0);
            const qreal dOut = qMin(qMax(qx, qy), 0.0) + qSqrt(kx * kx + ky * ky) - cornerR;
            if (dOut <= 0.0) {
                // Keep slight ambient occlusion right inside outer 16pt corner perimeter
                const qreal innerRim = (dOut > -2.0) ? (0.14 * opacityScale) : 0.0;
                const int a = qRound(innerRim * 255.0);
                line[x] = qRgba(0, 0, 0, a);
                continue;
            }
            const qreal len = qMax(qSqrt(px * px + py * py), 1e-4);
            // Smooth vertical directional weight along outer perimeter
            const qreal ny = (qAbs(py) > hy - cornerR * 0.5) ? (py > 0 ? 1.0 : -1.0) : (py / len);
            const qreal alpha = qBound(0.0, evalEdgeAlpha(dOut, ny) * opacityScale, 1.0);
            line[x] = qRgba(0, 0, 0, qRound(alpha * 255.0));
        }
    }
    return img;
}

QPainterPath buildContinuousTopTitlebarPath(const QRectF &r, qreal radius)
{
    QPainterPath path;
    const qreal ext = qMin(radius * 1.528665, qMin(r.width() * 0.45, r.height()));
    path.moveTo(r.left(), r.bottom());
    path.lineTo(r.left(), r.top() + ext);
    path.cubicTo(r.left(), r.top() + radius * 0.28,
                 r.left() + radius * 0.28, r.top(),
                 r.left() + ext, r.top());
    path.lineTo(r.right() - ext, r.top());
    path.cubicTo(r.right() - radius * 0.28, r.top(),
                 r.right(), r.top() + radius * 0.28,
                 r.right(), r.top() + ext);
    path.lineTo(r.right(), r.bottom());
    path.closeSubpath();
    return path;
}
} // namespace

// ---------------- TrafficLightButton (SPEC §4.6) ----------------

TrafficLightButton::TrafficLightButton(KDecoration3::DecorationButtonType type, GlassDecoration *decoration, QObject *parent)
    : KDecoration3::DecorationButton(type, decoration, parent)
{
}

void TrafficLightButton::hoverEnterEvent(QHoverEvent *event)
{
    KDecoration3::DecorationButton::hoverEnterEvent(event);
    if (auto *deco = qobject_cast<GlassDecoration *>(decoration())) {
        deco->setClusterHovered(true);
    }
}

void TrafficLightButton::hoverLeaveEvent(QHoverEvent *event)
{
    KDecoration3::DecorationButton::hoverLeaveEvent(event);
    if (auto *deco = qobject_cast<GlassDecoration *>(decoration())) {
        deco->setClusterHovered(false);
    }
}

void TrafficLightButton::mousePressEvent(QMouseEvent *event)
{
    KDecoration3::DecorationButton::mousePressEvent(event);
    update();
}

void TrafficLightButton::mouseReleaseEvent(QMouseEvent *event)
{
    KDecoration3::DecorationButton::mouseReleaseEvent(event);
    update();
}

void TrafficLightButton::paint(QPainter *painter, const QRectF &repaintArea)
{
    Q_UNUSED(repaintArea)
    auto *deco = qobject_cast<GlassDecoration *>(decoration());
    const auto *win = deco ? deco->window() : nullptr;
    if (!deco || !win) {
        return;
    }

    const qreal d = deco->buttonDiameter();
    const QRectF circleRect(geometry().center().x() - d * 0.5,
                            geometry().center().y() - d * 0.5,
                            d, d);

    const bool activeWin = win->isActive();
    const bool showSymbols = deco->clusterHovered();
    const bool showActiveColors = activeWin || showSymbols;

    QColor fillColor;
    QColor highlightColor;
    if (!isEnabled()) {
        fillColor = deco->isDark() ? QColor(77, 77, 79, 90) : QColor(200, 200, 204, 128);
        highlightColor = Qt::transparent;
    } else if (!showActiveColors) {
        // Inactive window neutral mid-gray (SPEC §4.6)
        fillColor = deco->isDark() ? QColor(0x4D, 0x4D, 0x4F) : QColor(220, 220, 220, 128);
        highlightColor = deco->isDark() ? QColor(255, 255, 255, 28) : QColor(255, 255, 255, 90);
    } else {
        switch (type()) {
        case KDecoration3::DecorationButtonType::Close:
            fillColor = QColor(0xE2, 0x68, 0x5B);
            highlightColor = QColor(0xF5, 0xC5, 0xBA);
            break;
        case KDecoration3::DecorationButtonType::Minimize:
            fillColor = QColor(0xF4, 0xC3, 0x2C);
            highlightColor = QColor(0xFF, 0xFF, 0x7D);
            break;
        case KDecoration3::DecorationButtonType::Maximize:
            fillColor = QColor(0x62, 0xBD, 0x2E);
            highlightColor = QColor(0xB7, 0xF6, 0x97);
            break;
        default:
            fillColor = QColor(0x8E, 0x8E, 0x93);
            highlightColor = Qt::transparent;
            break;
        }
        if (isPressed()) {
            fillColor = fillColor.darker(125); // ~20% darker on press (SPEC §4.6)
        }
    }

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, true);

    // Circle base fill
    painter->setPen(QPen(QColor(0, 0, 0, deco->isDark() ? 80 : 36), 0.75));
    painter->setBrush(fillColor);
    painter->drawEllipse(circleRect);

    // Subtle top-arc specular sheen (SPEC §4.6)
    if (highlightColor.alpha() > 0 && !isPressed()) {
        QLinearGradient sheen(circleRect.left(), circleRect.top(), circleRect.left(), circleRect.bottom());
        sheen.setColorAt(0.0, QColor(highlightColor.red(), highlightColor.green(), highlightColor.blue(), 110));
        sheen.setColorAt(0.42, Qt::transparent);
        painter->setPen(Qt::NoPen);
        painter->setBrush(sheen);
        painter->drawEllipse(circleRect.adjusted(0.75, 0.75, -0.75, -0.75));
    }

    // Group Hover Symbols rendered simultaneously on all 3 circles (SPEC §4.6)
    if (showSymbols && isEnabled()) {
        const QPointF c = circleRect.center();
        const qreal glyphR = d * 0.24;
        if (type() == KDecoration3::DecorationButtonType::Close) {
            painter->setPen(QPen(QColor(0, 0, 0, 145), 1.45, Qt::SolidLine, Qt::RoundCap));
            painter->drawLine(QPointF(c.x() - glyphR, c.y() - glyphR), QPointF(c.x() + glyphR, c.y() + glyphR));
            painter->drawLine(QPointF(c.x() + glyphR, c.y() - glyphR), QPointF(c.x() - glyphR, c.y() + glyphR));
        } else if (type() == KDecoration3::DecorationButtonType::Minimize) {
            painter->setPen(QPen(QColor(0, 0, 0, 145), 1.45, Qt::SolidLine, Qt::RoundCap));
            painter->drawLine(QPointF(c.x() - glyphR * 1.15, c.y()), QPointF(c.x() + glyphR * 1.15, c.y()));
        } else if (type() == KDecoration3::DecorationButtonType::Maximize) {
            const bool altHeld = QGuiApplication::queryKeyboardModifiers().testFlag(Qt::AltModifier);
            if (altHeld) {
                painter->setPen(QPen(QColor(0x00, 0x55, 0x00, 210), 1.45, Qt::SolidLine, Qt::RoundCap));
                painter->drawLine(QPointF(c.x() - glyphR, c.y()), QPointF(c.x() + glyphR, c.y()));
                painter->drawLine(QPointF(c.x(), c.y() - glyphR), QPointF(c.x(), c.y() + glyphR));
            } else {
                // Opposing right-triangles along TL-BR diagonal (#005500 SPEC §4.6)
                painter->setPen(Qt::NoPen);
                painter->setBrush(QColor(0x00, 0x55, 0x00, 210));
                const qreal a = d * 0.26;
                const qreal gap = 0.7;
                QPolygonF tl;
                tl << QPointF(c.x() - a, c.y() - a)
                   << QPointF(c.x() + a - gap, c.y() - a)
                   << QPointF(c.x() - a, c.y() + a - gap);
                QPolygonF br;
                br << QPointF(c.x() + a, c.y() + a)
                   << QPointF(c.x() - a + gap, c.y() + a)
                   << QPointF(c.x() + a, c.y() - a + gap);
                painter->drawPolygon(tl);
                painter->drawPolygon(br);
            }
        }
    }

    painter->restore();
}

// ---------------- GlassDecoration ----------------

GlassDecoration::GlassDecoration(QObject *parent, const QVariantList &args)
    : KDecoration3::Decoration(parent, args)
{
}

void GlassDecoration::ensureShadows()
{
    if (!s_activeShadow) {
        s_activeShadow = std::make_shared<KDecoration3::DecorationShadow>();
        s_activeShadow->setShadow(buildSpecShadowImage(1.0));
        // innerShadowRect inset by cornerR=16 inside padding(56,38,56,74) -> overlap behind 16pt corners
        s_activeShadow->setInnerShadowRect(QRectF(72, 54, 16, 16));
        s_activeShadow->setPadding(QMarginsF(56, 38, 56, 74));
    }
    if (!s_inactiveShadow) {
        s_inactiveShadow = std::make_shared<KDecoration3::DecorationShadow>();
        s_inactiveShadow->setShadow(buildSpecShadowImage(0.52)); // Inactive = 0.52x active (SPEC §2.5)
        s_inactiveShadow->setInnerShadowRect(QRectF(72, 54, 16, 16));
        s_inactiveShadow->setPadding(QMarginsF(56, 38, 56, 74));
    }
}

qreal GlassDecoration::titleBarHeight() const
{
    const auto *win = window();
    if (!win) {
        return 38.0;
    }
    const QString cls = win->windowClass().toLower();
    // Optional plain 28pt bar for dialogs/auxiliary tools or config
    if (m_toolbarStyle == QStringLiteral("plain") || win->isModal()) {
        return 28.0;
    }
    if (m_toolbarStyle == QStringLiteral("unified") || cls.contains(QStringLiteral("files")) || cls.contains(QStringLiteral("settings"))) {
        return 52.0;
    }
    return 38.0; // Compact Unified default (SPEC §4.6)
}

qreal GlassDecoration::buttonDiameter() const
{
    return (titleBarHeight() <= 30.0) ? 12.0 : 14.0;
}

QRectF GlassDecoration::clusterHitRect() const
{
    const qreal h = titleBarHeight();
    const qreal x0 = (h >= 50.0) ? 26.0 : ((h <= 30.0) ? 14.0 : 20.0);
    const qreal cy = (h >= 50.0) ? 26.0 : (h * 0.5);
    const qreal pitch = (h <= 30.0) ? 20.0 : 23.0;
    const qreal r = buttonDiameter() * 0.5;
    return QRectF(x0 - r - 6.0, cy - r - 6.0, pitch * 2.0 + r * 2.0 + 12.0, r * 2.0 + 12.0);
}

void GlassDecoration::createButtons()
{
    qDeleteAll(m_buttons);
    m_buttons.clear();
    m_buttons << new TrafficLightButton(KDecoration3::DecorationButtonType::Close, this, this)
              << new TrafficLightButton(KDecoration3::DecorationButtonType::Minimize, this, this)
              << new TrafficLightButton(KDecoration3::DecorationButtonType::Maximize, this, this);
}

bool GlassDecoration::init()
{
    ensureShadows();
    reloadAppearance();
    createButtons();

    auto *win = window();
    connect(win, &KDecoration3::DecoratedWindow::activeChanged, this, [this]() {
        updateShadow();
        update();
    });
    connect(win, &KDecoration3::DecoratedWindow::widthChanged, this, &GlassDecoration::updateLayout);
    connect(win, &KDecoration3::DecoratedWindow::heightChanged, this, &GlassDecoration::updateLayout);
    connect(win, &KDecoration3::DecoratedWindow::maximizedChanged, this, &GlassDecoration::updateLayout);
    connect(win, &KDecoration3::DecoratedWindow::captionChanged, this, [this]() { update(m_titleBarRect); });
    connect(win, &KDecoration3::DecoratedWindow::paletteChanged, this, &GlassDecoration::reloadAppearance);

    QDBusConnection::sessionBus().connect(
        QStringLiteral("org.conjunction.Settings"),
        QStringLiteral("/org/conjunction/Settings"),
        QStringLiteral("org.conjunction.Settings"),
        QStringLiteral("SettingChanged"),
        this,
        SLOT(onShellSettingChanged(QString, QVariant)));

    updateLayout();
    updateShadow();
    return true;
}

void GlassDecoration::reloadAppearance()
{
    const QString iniPath = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation)
                            + QStringLiteral("/conjunction/settings.ini");
    QSettings qs(iniPath, QSettings::IniFormat);
    const QString mode = qs.value(QStringLiteral("Appearance/mode"), QStringLiteral("light")).toString();
    m_darkMode = (mode == QStringLiteral("dark"));
    m_reduceTransparency = qs.value(QStringLiteral("Accessibility/reduceTransparency"), false).toBool();
    m_increaseContrast = qs.value(QStringLiteral("Accessibility/increaseContrast"), false).toBool();

    KSharedConfig::Ptr kwinCfg = KSharedConfig::openConfig(QStringLiteral("kwinrc"));
    KConfigGroup cg(kwinCfg, QStringLiteral("Conjunction"));
    m_toolbarStyle = cg.readEntry(QStringLiteral("ToolbarStyle"), QStringLiteral("unifiedCompact"));

    // Query live Settings D-Bus if running
    QDBusInterface iface(QStringLiteral("org.conjunction.Settings"),
                         QStringLiteral("/org/conjunction/Settings"),
                         QStringLiteral("org.conjunction.Settings"),
                         QDBusConnection::sessionBus());
    if (iface.isValid()) {
        QDBusReply<QDBusVariant> rep = iface.call(QStringLiteral("GetSetting"), QStringLiteral("appearance.mode"));
        if (rep.isValid() && !rep.value().variant().toString().isEmpty()) {
            m_darkMode = (rep.value().variant().toString() == QStringLiteral("dark"));
        }
        QDBusReply<QDBusVariant> rt = iface.call(QStringLiteral("GetSetting"), QStringLiteral("accessibility.reduceTransparency"));
        if (rt.isValid()) {
            m_reduceTransparency = rt.value().variant().toBool();
        }
        QDBusReply<QDBusVariant> ic = iface.call(QStringLiteral("GetSetting"), QStringLiteral("accessibility.increaseContrast"));
        if (ic.isValid()) {
            m_increaseContrast = ic.value().variant().toBool();
        }
    }

    update();
}

void GlassDecoration::onShellSettingChanged(const QString &key, const QVariant &value)
{
    if (key == QStringLiteral("appearance.mode") || key == QStringLiteral("Appearance/mode")) {
        m_darkMode = (value.toString() == QStringLiteral("dark"));
    } else if (key == QStringLiteral("accessibility.reduceTransparency") || key == QStringLiteral("Accessibility/reduceTransparency")) {
        m_reduceTransparency = value.toBool();
    } else if (key == QStringLiteral("accessibility.increaseContrast") || key == QStringLiteral("Accessibility/increaseContrast")) {
        m_increaseContrast = value.toBool();
    } else {
        return;
    }
    updateLayout();
    update();
}

void GlassDecoration::updateShadow()
{
    const auto *win = window();
    if (!win || win->isMaximized()) {
        setShadow(nullptr);
        return;
    }
    setShadow(win->isActive() ? s_activeShadow : s_inactiveShadow);
}

void GlassDecoration::updateLayout()
{
    const auto *win = window();
    if (!win) {
        return;
    }

    const qreal h = titleBarHeight();
    const bool maxed = win->isMaximized();
    setBorders(QMarginsF(0.0, h, 0.0, 0.0));
    setResizeOnlyBorders(maxed ? QMarginsF() : QMarginsF(6.0, 6.0, 6.0, 6.0));
    setOpaque(m_reduceTransparency);
    setBorderRadius(maxed ? KDecoration3::BorderRadius(0.0) : KDecoration3::BorderRadius(16.0));

    if (!maxed) {
        const QColor outlineColor = m_increaseContrast
            ? (m_darkMode ? QColor(255, 255, 255, 115) : QColor(0, 0, 0, 115))
            : (m_darkMode ? QColor(255, 255, 255, 36) : QColor(0, 0, 0, 26));
        setBorderOutline(KDecoration3::BorderOutline(1.0, outlineColor, KDecoration3::BorderRadius(16.0)));
    } else {
        setBorderOutline(KDecoration3::BorderOutline());
    }

    m_titleBarRect = QRectF(0.0, 0.0, size().width(), h);
    setTitleBar(m_titleBarRect);
    setBlurRegion(m_reduceTransparency ? QRegion() : QRegion(m_titleBarRect.toRect()));

    // Position 3 Traffic Light buttons (SPEC §4.6 Table)
    const qreal x0 = (h >= 50.0) ? 26.0 : ((h <= 30.0) ? 14.0 : 20.0);
    const qreal cy = (h >= 50.0) ? 26.0 : (h * 0.5);
    const qreal pitch = (h <= 30.0) ? 20.0 : 23.0;
    const qreal hit = 20.0;
    for (int i = 0; i < m_buttons.size(); ++i) {
        const qreal cx = x0 + i * pitch;
        m_buttons[i]->setGeometry(QRectF(cx - hit * 0.5, cy - hit * 0.5, hit, hit));
    }

    updateShadow();
    update();
}

void GlassDecoration::setClusterHovered(bool hovered)
{
    if (m_clusterHovered == hovered) {
        return;
    }
    m_clusterHovered = hovered;
    for (auto *btn : m_buttons) {
        btn->update();
    }
}

void GlassDecoration::hoverEnterEvent(QHoverEvent *event)
{
    KDecoration3::Decoration::hoverEnterEvent(event);
    setClusterHovered(clusterHitRect().contains(event->position()));
}

void GlassDecoration::hoverMoveEvent(QHoverEvent *event)
{
    KDecoration3::Decoration::hoverMoveEvent(event);
    setClusterHovered(clusterHitRect().contains(event->position()));
}

void GlassDecoration::hoverLeaveEvent(QHoverEvent *event)
{
    KDecoration3::Decoration::hoverLeaveEvent(event);
    setClusterHovered(false);
}

void GlassDecoration::paint(QPainter *painter, const QRectF &repaintArea)
{
    Q_UNUSED(repaintArea)
    const auto *win = window();
    if (!win) {
        return;
    }

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, true);

    const bool maxed = win->isMaximized();
    const QPainterPath barPath = maxed ? [&]() {
        QPainterPath p;
        p.addRect(m_titleBarRect);
        return p;
    }() : buildContinuousTopTitlebarPath(m_titleBarRect, 16.0);

    // Translucent Liquid Glass header tint (or Reduce Transparency chrome #ECECEC/#282828)
    QColor bg;
    if (m_reduceTransparency) {
        bg = m_darkMode ? QColor(0x28, 0x28, 0x28) : QColor(0xEC, 0xEC, 0xEC);
    } else if (m_darkMode) {
        bg = win->isActive() ? QColor(34, 34, 38, 175) : QColor(28, 28, 32, 195);
    } else {
        bg = win->isActive() ? QColor(246, 247, 250, 178) : QColor(238, 238, 240, 200);
    }

    painter->setClipPath(barPath);
    painter->fillRect(m_titleBarRect, bg);

    // Directional 90 deg top specular rim highlight along top header edge (SPEC §1.1 & §4.6)
    painter->setPen(QPen(m_darkMode ? QColor(255, 255, 255, 34) : QColor(255, 255, 255, 165), 1.0));
    painter->drawLine(QPointF(m_titleBarRect.left(), m_titleBarRect.top() + 0.5),
                      QPointF(m_titleBarRect.right(), m_titleBarRect.top() + 0.5));

    // Titlebar bottom separator hairline (SPEC §2.6)
    const QColor sep = m_increaseContrast
        ? (m_darkMode ? QColor(255, 255, 255, 166) : QColor(0, 0, 0, 166))
        : (m_darkMode ? QColor(255, 255, 255, 25) : QColor(0, 0, 0, 25));
    painter->setPen(QPen(sep, 0.75));
    painter->drawLine(QPointF(m_titleBarRect.left(), m_titleBarRect.bottom() - 0.5),
                      QPointF(m_titleBarRect.right(), m_titleBarRect.bottom() - 0.5));

    // Window Caption (13 pt Bold Inter, SPEC §2.4 & §4.6)
    QFont titleFont(QStringLiteral("Inter"));
    titleFont.setPixelSize(qRound(13.0 * 0.9685));
    titleFont.setWeight(QFont::DemiBold);
    titleFont.setLetterSpacing(QFont::PercentageSpacing, 99.9);
    painter->setFont(titleFont);

    QColor textCol;
    if (m_increaseContrast) {
        textCol = m_darkMode ? Qt::white : Qt::black;
    } else if (win->isActive()) {
        textCol = m_darkMode ? QColor(255, 255, 255, 216) : QColor(0, 0, 0, 216);
    } else {
        textCol = m_darkMode ? QColor(255, 255, 255, 110) : QColor(0, 0, 0, 110);
    }
    painter->setPen(textCol);

    const qreal leftReserve = clusterHitRect().right() + 12.0;
    const QRectF captionRect(leftReserve, m_titleBarRect.top(),
                             qMax(40.0, m_titleBarRect.width() - leftReserve * 2.0),
                             m_titleBarRect.height());
    const QString elided = QFontMetricsF(titleFont).elidedText(win->caption(), Qt::ElideRight, captionRect.width());
    painter->drawText(captionRect, Qt::AlignCenter | Qt::TextSingleLine, elided);

    painter->restore();

    // Paint the 3 traffic lights
    for (auto *btn : m_buttons) {
        btn->paint(painter, repaintArea);
    }
}

// ---------------- GlassThemeProvider ----------------

GlassThemeProvider::GlassThemeProvider(QObject *parent, const KPluginMetaData &data)
    : KDecoration3::DecorationThemeProvider(parent)
{
    Q_UNUSED(data)
}

QList<KDecoration3::DecorationThemeMetaData> GlassThemeProvider::themes() const
{
    KDecoration3::DecorationThemeMetaData meta;
    meta.setVisibleName(QStringLiteral("Conjunction Glass"));
    meta.setThemeName(QStringLiteral("ConjunctionGlass"));
    meta.setBorderSize(KDecoration3::BorderSize::None);
    meta.setPluginId(QStringLiteral("org.conjunction.glass"));
    return {meta};
}

} // namespace Conjunction

K_PLUGIN_FACTORY_WITH_JSON(ConjunctionGlassDecoFactory,
                           "glassdecoration.json",
                           registerPlugin<Conjunction::GlassDecoration>();
                           registerPlugin<Conjunction::GlassThemeProvider>();)

#include "glassdecoration.moc"
