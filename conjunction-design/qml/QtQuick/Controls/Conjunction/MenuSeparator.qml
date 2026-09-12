import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.MenuSeparator {
    id: control

    implicitWidth: 160
    implicitHeight: 9

    contentItem: Rectangle {
        anchors.centerIn: parent
        width: parent.width - Spacing.sm * 2
        height: Geometry.separatorThickness
        color: Theme.separator
    }
}
