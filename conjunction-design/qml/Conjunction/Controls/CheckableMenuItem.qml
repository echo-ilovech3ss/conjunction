import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import Conjunction.Design

T.MenuItem {
    id: control

    checkable: true
    implicitWidth: 180
    implicitHeight: Geometry.controlHeightSmall

    Accessible.role: Accessible.CheckBox
    Accessible.name: text
    Accessible.checked: checked

    background: Rectangle {
        radius: Geometry.radiusSmall - 1
        color: control.highlighted ? Theme.selection : "transparent"
    }

    contentItem: RowLayout {
        spacing: Spacing.sm
        anchors.fill: parent
        anchors.leftMargin: Spacing.sm
        anchors.rightMargin: Spacing.sm

        Icon {
            visible: control.checked
            name: "check"
            size: 14
            color: control.highlighted ? Theme.selectionText : Theme.accent
        }

        Item {
            visible: !control.checked
            width: 14
            height: 14
        }

        Text {
            Layout.fillWidth: true
            text: control.text
            font: Typography.controlLabel
            color: control.enabled ? (control.highlighted ? Theme.selectionText : Theme.textPrimary) : Theme.textDisabled
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }
}
