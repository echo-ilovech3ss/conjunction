import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.Popup {
    id: control

    property Item targetAnchor: null
    property Item invokerItem: null

    readonly property real maxWinW: control.T.Overlay.overlay ? Math.max(180, control.T.Overlay.overlay.width - 16) : 640
    readonly property real maxWinH: control.T.Overlay.overlay ? Math.max(120, control.T.Overlay.overlay.height - 16) : 480

    implicitWidth: 240
    implicitHeight: 160
    width: Math.min(implicitWidth, maxWinW)
    height: Math.min(implicitHeight, maxWinH)
    margins: 8
    padding: Spacing.lg

    modal: true
    focus: true
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

    // SPEC §3.1 Popover Open 158 ms (0.94 -> 1.00) / Close 150 ms
    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: Motion.duration(Motion.popoverOpen)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            property: "scale"
            from: Appearance.reducedMotion ? 1.0 : 0.94
            to: 1.0
            duration: Motion.duration(Motion.popoverOpen)
            easing.type: Easing.OutCubic
        }
    }

    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: Motion.duration(Motion.popoverClose)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            property: "scale"
            from: 1.0
            to: Appearance.reducedMotion ? 1.0 : 0.94
            duration: Motion.duration(Motion.popoverClose)
            easing.type: Easing.OutCubic
        }
    }

    background: Surface {
        elevation: "popover"
        radius: Geometry.radiusPopover // 14 pt SPEC §2.1
    }

    onOpened: forceActiveFocus()
    onClosed: {
        if (invokerItem) invokerItem.forceActiveFocus();
    }
}
