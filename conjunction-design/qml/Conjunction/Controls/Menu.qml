import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.Menu {
    id: control

    readonly property real maxWinW: control.T.Overlay.overlay ? Math.max(180, control.T.Overlay.overlay.width - 16) : 360
    readonly property real maxWinH: control.T.Overlay.overlay ? Math.max(120, control.T.Overlay.overlay.height - 16) : 480

    // SPEC §2.1 & §3.1 Menu: cr = 12, padding = 4, open 65 ms / close 133 ms
    implicitWidth: Math.min(Math.min(360, maxWinW), Math.max(180, contentItem.implicitWidth + Spacing.xs * 2))
    implicitHeight: Math.min(maxWinH, contentItem.implicitHeight + Spacing.xs * 2)
    margins: 8
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
        implicitWidth: Math.min(344, Math.max(172, contentWidth > 0 ? contentWidth : 200))
        implicitHeight: contentHeight
        model: control.contentModel
        currentIndex: control.currentIndex
        clip: true
        T.ScrollBar.vertical: ScrollBar {}
    }

    background: Surface {
        elevation: "popover"
        radius: Geometry.radiusMenu
    }
}
