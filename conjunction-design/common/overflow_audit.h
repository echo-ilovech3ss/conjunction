#pragma once

#include <QQuickWindow>
#include <QQuickItem>
#include <QVariant>
#include <QStringList>
#include <QRectF>
#include <QMetaObject>
#include <QtMath>
#include <QDebug>

namespace Conjunction {

struct OverflowFinding {
    QString kind;
    QString itemDesc;
    QString detail;
};

class OverflowAudit {
public:
    static bool isGlassBackdropHelper(const QQuickItem *item) {
        if (!item) return false;
        const QString cls = QString::fromLatin1(item->metaObject()->className());
        if (cls.contains("ShaderEffect")) return true;
        // GlassSurface internal backdrop capture / shadow halo nodes intentionally extend by captureMargin / shadow spread
        const QString idName = item->objectName();
        if (idName == QLatin1String("captureHelper") || idName == QLatin1String("shadowHalo") || idName == QLatin1String("focusRing")) {
            return true;
        }
        // Negative-margin outer shadows / FocusRing offsets (-4..+4 px outside parent)
        if (item->x() < 0 && item->y() < 0 && item->width() > item->parentItem()->width() && cls.contains("FocusRing")) {
            return true;
        }
        return false;
    }

    static bool hasScrollableAncestor(const QQuickItem *item) {
        const QQuickItem *cur = item ? item->parentItem() : nullptr;
        while (cur) {
            if (cur->inherits("QQuickFlickable")) return true;
            cur = cur->parentItem();
        }
        return false;
    }

    static const QQuickItem *nearestClipOrScrollAncestor(const QQuickItem *item) {
        const QQuickItem *cur = item ? item->parentItem() : nullptr;
        while (cur) {
            if (cur->clip() || cur->inherits("QQuickFlickable")) return cur;
            cur = cur->parentItem();
        }
        return nullptr;
    }

    static QString describeItem(const QQuickItem *item) {
        if (!item) return "<null>";
        QString cls = QString::fromLatin1(item->metaObject()->className());
        QString obj = item->objectName();
        QVariant txt = item->property("text");
        QString tail = txt.isValid() && !txt.toString().isEmpty()
            ? QStringLiteral(" \"%1\"").arg(txt.toString().left(28))
            : QString();
        return QStringLiteral("%1%2%3").arg(cls, obj.isEmpty() ? QString() : ("#" + obj), tail);
    }

    static QList<OverflowFinding> auditWindow(QQuickWindow *win, qreal tolerancePx = 2.5) {
        QList<OverflowFinding> findings;
        if (!win || !win->contentItem()) return findings;

        const QRectF winRect(0.0, 0.0, win->width(), win->height());

        auto walk = [&](auto &self, QQuickItem *item, bool insideGlassMargin, bool insideFlickable) -> void {
            if (!item || !item->isVisible() || item->opacity() <= 0.01) return;

            const QString cls = QString::fromLatin1(item->metaObject()->className());
            const bool isGlassFx = cls.contains("ShaderEffect") || item->inherits("QQuickShaderEffect")
                || (item->parentItem() && QString::fromLatin1(item->parentItem()->metaObject()->className()).contains("GlassSurface")
                    && (item->x() < -8.0 || item->y() < -8.0));
            const bool skipBounds = insideGlassMargin || isGlassFx || cls.contains("FocusRing");

            const qreal w = item->width();
            const qreal h = item->height();

            // 1. Text / TextInput / TextEdit specific checks
            if (cls.startsWith("QQuickText") && !cls.contains("Input") && !cls.contains("Edit")) {
                const QString text = item->property("text").toString();
                if (!text.isEmpty() && w > 0.5 && h > 0.5) {
                    const bool truncated = item->property("truncated").toBool();
                    const int elideMode = item->property("elide").toInt(); // 0 = ElideNone
                    const int wrapMode = item->property("wrapMode").toInt(); // 0 = NoWrap
                    const qreal paintedW = item->property("paintedWidth").toReal();
                    const qreal paintedH = item->property("paintedHeight").toReal();

                    if (truncated && elideMode == 0) {
                        findings.push_back({"text_truncated_no_elide", describeItem(item),
                            QStringLiteral("truncated=true without elide (w=%1, paintedW=%2)").arg(w, 0, 'f', 1).arg(paintedW, 0, 'f', 1)});
                    } else if (wrapMode == 0 && elideMode == 0 && paintedW > w + tolerancePx) {
                        findings.push_back({"text_width_overflow", describeItem(item),
                            QStringLiteral("paintedWidth %1 > width %2 without elide").arg(paintedW, 0, 'f', 1).arg(w, 0, 'f', 1)});
                    }
                    if (!insideFlickable && paintedH > h + tolerancePx + 2.0) {
                        findings.push_back({"text_height_overflow", describeItem(item),
                            QStringLiteral("paintedHeight %1 > height %2").arg(paintedH, 0, 'f', 1).arg(h, 0, 'f', 1)});
                    }
                }
            }

            // 2. Child bounding checks vs clipping parent or window bounds (when outside scrolling content)
            if (!skipBounds && !insideFlickable && w > 0.5 && h > 0.5 && cls != QLatin1String("QQuickRootItem")) {
                const QRectF sceneRect = item->mapRectToScene(QRectF(0.0, 0.0, w, h));
                if (sceneRect.left() < -tolerancePx || sceneRect.top() < -tolerancePx
                    || sceneRect.right() > winRect.right() + tolerancePx
                    || sceneRect.bottom() > winRect.bottom() + tolerancePx) {
                    findings.push_back({"window_bounds_overflow", describeItem(item),
                        QStringLiteral("scene (%1,%2 %3x%4) exceeds window (%5x%6)")
                            .arg(sceneRect.x(), 0, 'f', 1).arg(sceneRect.y(), 0, 'f', 1)
                            .arg(sceneRect.width(), 0, 'f', 1).arg(sceneRect.height(), 0, 'f', 1)
                            .arg(winRect.width(), 0, 'f', 1).arg(winRect.height(), 0, 'f', 1)});
                }

                const QQuickItem *clipAnc = nearestClipOrScrollAncestor(item);
                if (clipAnc && !clipAnc->inherits("QQuickFlickable") && !clipAnc->inherits("QQuickRootItem")) {
                    const QRectF clipRect = clipAnc->mapRectToScene(QRectF(0.0, 0.0, clipAnc->width(), clipAnc->height()));
                    if (sceneRect.left() < clipRect.left() - tolerancePx || sceneRect.top() < clipRect.top() - tolerancePx
                        || sceneRect.right() > clipRect.right() + tolerancePx || sceneRect.bottom() > clipRect.bottom() + tolerancePx) {
                        // Ignore Text inside elided single-line clip rect if elide is active
                        const bool isElidedText = cls.startsWith("QQuickText") && item->property("elide").toInt() != 0;
                        if (!isElidedText) {
                            findings.push_back({"clipped_by_ancestor", describeItem(item),
                                QStringLiteral("child (%1..%2, %3..%4) exceeds clip ancestor %5 (%6..%7, %8..%9)")
                                    .arg(sceneRect.left(),0,'f',1).arg(sceneRect.right(),0,'f',1)
                                    .arg(sceneRect.top(),0,'f',1).arg(sceneRect.bottom(),0,'f',1)
                                    .arg(describeItem(clipAnc))
                                    .arg(clipRect.left(),0,'f',1).arg(clipRect.right(),0,'f',1)
                                    .arg(clipRect.top(),0,'f',1).arg(clipRect.bottom(),0,'f',1)});
                        }
                    }
                }
            }

            // 3. Sibling overlap check inside Row / RowLayout / Column / ColumnLayout
            if (!skipBounds && (cls.contains("RowLayout") || cls == QLatin1String("QQuickRow")
                || cls.contains("ColumnLayout") || cls == QLatin1String("QQuickColumn"))) {
                QList<QPair<QQuickItem*, QRectF>> boxes;
                for (QQuickItem *c : item->childItems()) {
                    if (!c || !c->isVisible() || c->opacity() <= 0.01) continue;
                    if (c->width() <= 1.0 || c->height() <= 1.0) continue;
                    const QString cc = QString::fromLatin1(c->metaObject()->className());
                    if (cc.contains("Repeater") || cc.contains("GlassSurface") || cc.contains("FocusRing") || cc.contains("MouseArea")) continue;
                    boxes.push_back({c, c->mapRectToScene(QRectF(0, 0, c->width(), c->height()))});
                }
                for (int i = 0; i < boxes.size(); ++i) {
                    for (int j = i + 1; j < boxes.size(); ++j) {
                        const QRectF inter = boxes[i].second.intersected(boxes[j].second);
                        if (inter.width() > 3.5 && inter.height() > 3.5) {
                            findings.push_back({"sibling_overlap", describeItem(boxes[i].first) + " <-> " + describeItem(boxes[j].first),
                                QStringLiteral("overlap %1x%2 inside %3")
                                    .arg(inter.width(), 0, 'f', 1).arg(inter.height(), 0, 'f', 1).arg(describeItem(item))});
                        }
                    }
                }
            }

            const bool childInFlickable = insideFlickable || item->inherits("QQuickFlickable");
            for (QQuickItem *child : item->childItems()) {
                self(self, child, skipBounds, childInFlickable);
            }
        };

        walk(walk, win->contentItem(), false, false);
        return findings;
    }
};

} // namespace Conjunction
