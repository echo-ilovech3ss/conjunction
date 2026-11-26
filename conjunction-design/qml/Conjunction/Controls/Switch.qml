import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.Switch {
    id: control

    // SPEC §2.3 Switch: mini 26x15, small 32x18, regular/large 42x25
    property string sizeClass: "regular"
    property color onColor: Theme.systemGreen

    readonly property size trackDim: Geometry.switchSize(sizeClass)

    onPressed: FocusModel.markPointerNavigation()

    implicitWidth: Math.max(trackDim.width, trackDim.width + (control.text ? Spacing.sm + labelText.implicitWidth : 0))
    implicitHeight: Math.max(trackDim.height, labelText.implicitHeight)

    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.Button
    Accessible.name: text || "Switch"
    Accessible.checked: checked
    Accessible.focusable: true

    indicator: Rectangle {
        id: track
        width: control.trackDim.width
        height: control.trackDim.height
        y: Math.round((control.height - height) / 2)
        radius: height * 0.5
        border.width: Appearance.shouldIncreaseContrast ? 1.0 : 0.5

        color: {
            if (!control.enabled) return Theme.controlFill;
            if (control.checked) return control.onColor;
            if (control.down) return Theme.controlFillPressed;
            return Theme.isDark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.14);
        }

        border.color: {
            if (Appearance.shouldIncreaseContrast) return Theme.highContrastBorderColor;
            return control.checked ? "transparent" : Theme.separator;
        }

        Behavior on color {
            ColorAnimation { duration: Motion.duration(Motion.fast); easing.type: Motion.easingStandard }
        }

        readonly property int insetPad: 2
        readonly property real knobH: height - insetPad * 2
        readonly property real knobW: Math.round(knobH * 1.15)

        Rectangle {
            id: thumb
            width: track.knobW
            height: track.knobH
            radius: height * 0.5
            y: track.insetPad
            x: control.checked ? (track.width - width - track.insetPad) : track.insetPad
            color: "#FFFFFF"

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 1
                radius: parent.radius
                color: Qt.rgba(0, 0, 0, 0.18)
                z: -1
            }

            Behavior on x {
                NumberAnimation { duration: Motion.duration(Motion.fast); easing.type: Motion.easingStandard }
            }
        }

        FocusRing {
            target: track
            isTextInput: false
        }
    }

    contentItem: Text {
        id: labelText
        visible: control.text !== ""
        text: control.text
        font: Typography.body
        color: control.enabled ? Theme.textPrimary : Theme.textDisabled
        verticalAlignment: Text.AlignVCenter
        leftPadding: control.indicator.width + Spacing.sm
        elide: Text.ElideRight
    }

    ToolTip {
        visible: control.hovered && labelText.truncated && control.text !== ""
        text: control.text
        delay: 400
    }
}
