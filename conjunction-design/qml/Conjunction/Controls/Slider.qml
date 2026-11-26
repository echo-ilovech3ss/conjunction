import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.Slider {
    id: control

    // SPEC §2.3 Slider: 4 pt track (3 pt mini), 20x28 pill knob (24x28 large)
    property string sizeClass: "regular"

    readonly property int trackH: Geometry.sliderTrackHeight(sizeClass)
    readonly property size knobDim: Geometry.sliderKnobSize(sizeClass)

    onPressedChanged: if (pressed) FocusModel.markPointerNavigation()

    implicitWidth: 200
    implicitHeight: Math.max(knobDim.height, 28)

    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.Slider
    Accessible.name: "Slider"
    Accessible.focusable: true

    background: Rectangle {
        id: track
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) * 0.5
        width: control.availableWidth
        height: control.trackH
        radius: height * 0.5
        color: Theme.isDark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12)
        border.color: Appearance.shouldIncreaseContrast ? Theme.highContrastBorderColor : "transparent"
        border.width: Appearance.shouldIncreaseContrast ? 1.0 : 0

        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: control.enabled ? Theme.accent : Theme.textDisabled
        }
    }

    handle: Rectangle {
        id: handleItem
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + (control.availableHeight - height) * 0.5
        width: control.knobDim.width
        height: control.knobDim.height
        radius: Math.min(width, height) * 0.5
        color: control.enabled ? (control.pressed ? "#F2F2F7" : "#FFFFFF") : Theme.surfaceSecondary
        border.color: Appearance.shouldIncreaseContrast ? Theme.highContrastBorderColor : (control.activeFocus ? Theme.accent : Qt.rgba(0, 0, 0, 0.14))
        border.width: 0.75

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 2
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.16)
            z: -1
        }

        FocusRing {
            target: handleItem
            isTextInput: false
        }
    }

    Keys.onLeftPressed: function(event) {
        FocusModel.markKeyboardNavigation();
        control.decrease();
        event.accepted = true;
    }
    Keys.onRightPressed: function(event) {
        FocusModel.markKeyboardNavigation();
        control.increase();
        event.accepted = true;
    }
}
