import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.ScrollBar {
    id: control

    // SPEC §2.3 Overlay Scrollbar Track: idle 12 pt -> hover 16 pt
    implicitWidth: (control.hovered || control.pressed) ? Geometry.scrollBarHoverWidth : Geometry.scrollBarIdleWidth
    implicitHeight: (control.hovered || control.pressed) ? Geometry.scrollBarHoverWidth : Geometry.scrollBarIdleWidth

    visible: control.policy !== T.ScrollBar.AlwaysOff && control.size < 1.0

    Accessible.role: Accessible.ScrollBar

    Behavior on implicitWidth {
        NumberAnimation { duration: Motion.duration(Motion.fast) }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: Motion.duration(Motion.fast) }
    }

    contentItem: Rectangle {
        implicitWidth: (control.hovered || control.pressed) ? 10 : 6
        implicitHeight: (control.hovered || control.pressed) ? 10 : 6
        radius: Math.min(width, height) * 0.5
        color: control.pressed
            ? (Theme.isDark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.55))
            : (control.hovered
                ? (Theme.isDark ? Qt.rgba(1, 1, 1, 0.42) : Qt.rgba(0, 0, 0, 0.42))
                : (Theme.isDark ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(0, 0, 0, 0.25)))

        Behavior on implicitWidth {
            NumberAnimation { duration: Motion.duration(Motion.fast) }
        }
        Behavior on implicitHeight {
            NumberAnimation { duration: Motion.duration(Motion.fast) }
        }
    }

    background: Rectangle {
        color: "transparent"
    }
}
