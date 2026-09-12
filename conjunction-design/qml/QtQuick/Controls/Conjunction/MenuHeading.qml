import QtQuick
import Conjunction.Design

Item {
    id: root

    property string text: ""
    implicitWidth: 160
    implicitHeight: 20

    Text {
        anchors.fill: parent
        anchors.leftMargin: Spacing.sm
        anchors.rightMargin: Spacing.sm
        verticalAlignment: Text.AlignVCenter
        text: root.text.toUpperCase()
        font: Typography.caption
        color: Theme.textSecondary
    }
}
