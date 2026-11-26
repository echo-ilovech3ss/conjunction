import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import Conjunction.Design

T.MenuItem {
    id: control

    checkable: true
    implicitWidth: Math.min(344, Math.max(180, itemRow.implicitWidth + Spacing.sm * 2))
    implicitHeight: Math.max(Geometry.controlHeightSmall, itemRow.implicitHeight + 6)

    Accessible.role: Accessible.CheckBox
    Accessible.name: text
    Accessible.checked: checked

    background: Rectangle {
        radius: Geometry.radiusSmall - 1
        color: control.highlighted ? Theme.selection : "transparent"
    }

    contentItem: RowLayout {
        id: itemRow
        spacing: Spacing.sm
        anchors.fill: parent
        anchors.leftMargin: Spacing.sm
        anchors.rightMargin: Spacing.sm

        Icon {
            visible: control.checked
            name: "check"
            size: 14
            Layout.preferredWidth: size
            Layout.preferredHeight: size
            color: control.highlighted ? Theme.selectionText : Theme.accent
        }

        Item {
            visible: !control.checked
            width: 14
            height: 14
            Layout.preferredWidth: 14
            Layout.preferredHeight: 14
        }

        Text {
            id: checkItemText
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: control.text
            font: Typography.controlLabel
            color: control.enabled ? (control.highlighted ? Theme.selectionText : Theme.textPrimary) : Theme.textDisabled
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }

    ToolTip {
        visible: control.hovered && checkItemText.truncated && control.text !== ""
        text: control.text
        delay: 400
    }
}
