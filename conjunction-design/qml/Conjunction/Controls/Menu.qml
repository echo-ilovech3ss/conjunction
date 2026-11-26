import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.Menu {
    id: control

    // SPEC §2.1 & §3.1 Menu: cr = 12, padding = 4, open 65 ms / close 133 ms
    implicitWidth: Math.max(180, contentItem.implicitWidth + Spacing.xs * 2)
    implicitHeight: contentItem.implicitHeight + Spacing.xs * 2
    padding: Spacing.xs

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: Motion.duration(Motion.menuOpen)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            property: "y"
            from: control.y - (Appearance.reducedMotion ? 0 : 2)
            to: control.y
            duration: Motion.duration(Motion.menuOpen)
            easing.type: Easing.OutCubic
        }
    }

    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: Motion.duration(Motion.menuClose)
            easing.type: Easing.OutCubic
        }
    }

    contentItem: ListView {
        implicitHeight: contentHeight
        model: control.contentModel
        currentIndex: control.currentIndex
        clip: true
    }

    background: Surface {
        elevation: "popover"
        radius: Geometry.radiusMenu
    }
}
