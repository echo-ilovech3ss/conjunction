import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.Popup {
    id: control

    property Item targetAnchor: null
    property Item invokerItem: null

    implicitWidth: 240
    implicitHeight: 160
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
