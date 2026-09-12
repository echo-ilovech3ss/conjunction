import QtQuick
import Conjunction.Design

Item {
    id: root

    property int size: 24
    property color color: Theme.accent
    property bool running: true

    implicitWidth: size
    implicitHeight: size

    Accessible.role: Accessible.Indicator
    Accessible.name: "Activity Indicator"

    Icon {
        id: spinner
        name: "refresh"
        size: root.size
        color: root.color
        anchors.centerIn: parent

        RotationAnimation on rotation {
            running: root.running && !Appearance.reducedMotion
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 1000
        }
    }
}
