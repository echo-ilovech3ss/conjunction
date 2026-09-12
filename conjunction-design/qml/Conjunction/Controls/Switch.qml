import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.Switch {
    id: control

    implicitWidth: Math.max(Geometry.minTargetSize, track.width + (control.text ? Spacing.sm + labelText.implicitWidth : 0))
    implicitHeight: Math.max(Geometry.minTargetSize, 22)

    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.Button
    Accessible.name: text || "Switch"
    Accessible.checked: checked
    Accessible.focusable: true

    indicator: Rectangle {
        id: track
        width: 36
        height: 20
        y: Math.round((control.height - height) / 2)
        radius: 10
        border.width: Geometry.separatorThickness

        color: {
            if (!control.enabled) return Theme.surfaceSecondary;
            if (control.checked) return Theme.accent;
            if (control.down) return Theme.surfaceSecondary;
            return Theme.surfaceSecondary;
        }

        border.color: control.checked ? Theme.accent : Theme.separator

        Behavior on color {
            ColorAnimation { duration: Motion.duration(Motion.fast); easing.type: Motion.easingStandard }
        }

        Rectangle {
            id: thumb
            width: 16
            height: 16
            radius: 8
            y: 1
            x: control.checked ? (track.width - width - 2) : 2
            color: "#FFFFFF"

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 1
                radius: parent.radius
                color: "#20000000"
                z: -1
            }

            Behavior on x {
                NumberAnimation { duration: Motion.duration(Motion.fast); easing.type: Motion.easingStandard }
            }
        }

        FocusRing {
            active: control.activeFocus && FocusModel.keyboardNavigationActive
            target: track
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
    }
}
