import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import Conjunction.Design

T.CheckBox {
    id: control

    implicitWidth: Math.max(Geometry.minTargetSize, indicatorBox.width + Spacing.sm + labelText.implicitWidth)
    implicitHeight: Math.max(Geometry.minTargetSize, Geometry.controlHeightSmall)

    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.CheckBox
    Accessible.name: text
    Accessible.checked: checked
    Accessible.focusable: true

    indicator: Rectangle {
        id: indicatorBox
        width: 16
        height: 16
        y: Math.round((control.height - height) / 2)
        radius: Geometry.radiusSmall - 1
        border.width: Geometry.separatorThickness

        color: {
            if (!control.enabled) return Theme.surfaceSecondary;
            if (control.checked || control.checkState === Qt.PartiallyChecked) return Theme.accent;
            if (control.down) return Theme.surfaceSecondary;
            return Theme.surface;
        }

        border.color: {
            if (!control.enabled) return Theme.separator;
            if (control.checked || control.checkState === Qt.PartiallyChecked) return Theme.accent;
            if (control.hovered) return Theme.accent;
            return Theme.separator;
        }

        Icon {
            visible: control.checked && control.checkState !== Qt.PartiallyChecked
            name: "check"
            size: 12
            color: "#FFFFFF"
            anchors.centerIn: parent
        }

        Rectangle {
            visible: control.checkState === Qt.PartiallyChecked
            width: 8
            height: 2
            radius: 1
            color: "#FFFFFF"
            anchors.centerIn: parent
        }

        FocusRing {
            active: control.activeFocus && FocusModel.keyboardNavigationActive
            target: indicatorBox
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

    Keys.onSpacePressed: function(event) {
        if (control.enabled) {
            control.toggle();
            event.accepted = true;
        }
    }
}
