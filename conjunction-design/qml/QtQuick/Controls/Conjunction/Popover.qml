import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.Popup {
    id: control

    property Item targetAnchor: null
    property Item invokerItem: null

    implicitWidth: 240
    implicitHeight: 160
    padding: Spacing.md

    modal: true
    focus: true
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside


    background: Surface {
        elevation: "popover"
        radius: Geometry.radiusMedium
    }

    onOpened: {
        forceActiveFocus();
    }

    onClosed: {
        if (invokerItem) invokerItem.forceActiveFocus();
    }
}
