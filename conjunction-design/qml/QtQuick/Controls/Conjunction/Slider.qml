import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.Slider {
    id: control

    implicitWidth: 200
    implicitHeight: Math.max(Geometry.minTargetSize, 22)

    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.Slider
    Accessible.name: "Slider"
    Accessible.focusable: true

    background: Rectangle {
        id: track
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        width: control.availableWidth
        height: 4
        radius: 2
        color: Theme.surfaceSecondary

        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: 2
            color: control.enabled ? Theme.accent : Theme.textDisabled
        }
    }

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + (control.availableHeight - height) / 2
        width: 18
        height: 18
        radius: 9
        color: control.enabled ? Theme.surface : Theme.surfaceSecondary
        border.color: control.activeFocus ? Theme.accent : Theme.separator
        border.width: Geometry.separatorThickness

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 1
            radius: 9
            color: "#20000000"
            z: -1
        }

        FocusRing {
            active: control.activeFocus && FocusModel.keyboardNavigationActive
            target: control.handle
        }
    }

    Keys.onLeftPressed: function(event) {
        control.decrease();
        event.accepted = true;
    }
    Keys.onRightPressed: function(event) {
        control.increase();
        event.accepted = true;
    }
}
