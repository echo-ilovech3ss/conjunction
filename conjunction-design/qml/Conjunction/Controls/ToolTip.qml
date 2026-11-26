import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.ToolTip {
    id: control

    readonly property real maxTipW: control.T.Overlay.overlay ? Math.min(340, Math.max(120, control.T.Overlay.overlay.width - 24)) : 320

    implicitWidth: Math.min(maxTipW, Math.max(tipText.implicitWidth + Spacing.sm * 2, 40))
    implicitHeight: tipText.implicitHeight + Spacing.xs * 2
    margins: 8
    padding: Spacing.xs

    closePolicy: T.Popup.CloseOnPressOutside | T.Popup.CloseOnEscape

    TextMetrics {
        id: tipMetrics
        font: Typography.caption
        text: control.text
    }

    contentItem: Text {
        id: tipText
        width: Math.min(control.maxTipW - Spacing.sm * 2, Math.max(24, Math.ceil(tipMetrics.advanceWidth) + 2))
        text: control.text
        font: Typography.caption
        color: Theme.textPrimary
        wrapMode: Text.Wrap
        maximumLineCount: 4
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Surface {
        elevation: "popover"
        radius: Geometry.radiusSmall
    }
}
