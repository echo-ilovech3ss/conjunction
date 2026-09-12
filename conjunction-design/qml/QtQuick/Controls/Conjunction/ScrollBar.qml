import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.ScrollBar {
    id: control

    implicitWidth: Math.max(Geometry.separatorThickness, control.interactive ? 12 : 8)
    implicitHeight: Math.max(Geometry.separatorThickness, control.interactive ? 12 : 8)

    visible: control.policy !== T.ScrollBar.AlwaysOff && control.size < 1.0

    Accessible.role: Accessible.ScrollBar

    contentItem: Rectangle {
        implicitWidth: control.interactive ? 8 : 4
        implicitHeight: control.interactive ? 8 : 4
        radius: Geometry.radiusPill
        color: control.pressed ? Theme.textPrimary : (control.hovered ? Theme.textSecondary : (Theme.isDark ? "#40FFFFFF" : "#40000000"))

        Behavior on implicitWidth {
            NumberAnimation { duration: Motion.duration(Motion.fast) }
        }
    }

    background: Rectangle {
        color: "transparent"
    }
}
