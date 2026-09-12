import QtQuick
import Conjunction.Design

Item {
    id: root

    property string title: ""
    implicitWidth: parent ? parent.width : 180
    implicitHeight: 28

    Text {
        anchors.fill: parent
        anchors.leftMargin: Spacing.sm
        anchors.rightMargin: Spacing.sm
        verticalAlignment: Text.AlignBottom
        text: root.title.toUpperCase()
        font: Typography.caption
        color: Theme.textSecondary
    }
}
