import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.ToolTip {
    id: control

    implicitWidth: Math.max(contentItem.implicitWidth + Spacing.sm * 2, 40)
    implicitHeight: contentItem.implicitHeight + Spacing.xs * 2
    padding: Spacing.xs

    closePolicy: T.Popup.CloseOnPressOutside | T.Popup.CloseOnEscape


    contentItem: Text {
        text: control.text
        font: Typography.caption
        color: Theme.textPrimary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Surface {
        elevation: "popover"
        radius: Geometry.radiusSmall
    }
}
