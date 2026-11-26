import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.MenuSeparator {
    id: control

    // SPEC §2.6 Menu Separator: 10 pt horizontal inset, 12% Light / 30% Dark / 65% AX
    implicitWidth: 180
    implicitHeight: 9

    contentItem: Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Spacing.inset
        anchors.rightMargin: Spacing.inset
        height: Geometry.separatorThickness
        color: Theme.menuSeparatorColor
    }
}
