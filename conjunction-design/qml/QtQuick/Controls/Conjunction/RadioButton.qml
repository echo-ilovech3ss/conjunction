import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import Conjunction.Design

T.RadioButton {
    id: control

    implicitWidth: Math.max(Geometry.minTargetSize, indicatorCircle.width + Spacing.sm + labelText.implicitWidth)
    implicitHeight: Math.max(Geometry.minTargetSize, Geometry.controlHeightSmall)

    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.RadioButton
    Accessible.name: text
    Accessible.checked: checked
    Accessible.focusable: true

    indicator: Rectangle {
        id: indicatorCircle
        width: 16
        height: 16
        y: Math.round((control.height - height) / 2)
        radius: 8
        border.width: Geometry.separatorThickness

        color: {
            if (!control.enabled) return Theme.surfaceSecondary;
            if (control.down) return Theme.surfaceSecondary;
            return Theme.surface;
        }

        border.color: {
            if (!control.enabled) return Theme.separator;
            if (control.checked) return Theme.accent;
            if (control.hovered) return Theme.accent;
            return Theme.separator;
        }

        Rectangle {
            id: innerDot
            visible: control.checked
            width: 6
            height: 6
            radius: 3
            anchors.centerIn: parent
            color: control.enabled ? Theme.accent : Theme.textDisabled
        }

        FocusRing {
            active: control.activeFocus && FocusModel.keyboardNavigationActive
            target: indicatorCircle
        }
    }

    contentItem: Text {
        id: labelText
        text: control.text
        font: Typography.body
        color: control.enabled ? Theme.textPrimary : Theme.textDisabled
        verticalAlignment: Text.AlignVCenter
        leftPadding: control.indicator.width + Spacing.sm
    }
}
