import QtQuick
import Conjunction.Design

Item {
    id: root

    property string title: ""
    implicitWidth: parent ? parent.width : 196
    implicitHeight: 24

    Text {
        anchors.fill: parent
        anchors.leftMargin: Spacing.sm
        anchors.rightMargin: Spacing.sm
        verticalAlignment: Text.AlignBottom
        text: root.title
        font: Typography.subheadlineBold // SPEC §4.7: 11 pt Bold
        color: Theme.secondaryLabelColor
        elide: Text.ElideRight
    }
}
