import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.CheckBox {
    id: control

    // SPEC §2.3 CheckBox: mini 14, small 16, regular 18 (20 fitting), large 20
    property string sizeClass: "regular"
    readonly property int boxSize: Geometry.checkBoxSize(sizeClass)

    onPressed: FocusModel.markPointerNavigation()

    implicitWidth: Math.max(boxSize, indicatorBox.width + (text !== "" ? Spacing.sm + labelText.implicitWidth : 0))
    implicitHeight: Math.max(boxSize + 2, labelText.implicitHeight)

    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.CheckBox
    Accessible.name: text
    Accessible.checked: checked
    Accessible.focusable: true

    indicator: Rectangle {
        id: indicatorBox
        width: control.boxSize
        height: control.boxSize
        y: Math.round((control.height - height) * 0.5)
        radius: Geometry.radiusCheckbox // 5.0 pt -> +3.5 = 8.5 pt focus halo
        border.width: Appearance.shouldIncreaseContrast ? 1.0 : Geometry.separatorThickness

        color: {
            if (!control.enabled) return Theme.controlFill;
            if (control.checked || control.checkState === Qt.PartiallyChecked) return Theme.accent;
            if (control.down) return Theme.controlFillPressed;
            return Theme.controlBackgroundColor;
        }

        border.color: {
            if (Appearance.shouldIncreaseContrast) return Theme.highContrastBorderColor;
            if (!control.enabled) return Theme.separator;
            if (control.checked || control.checkState === Qt.PartiallyChecked) return Theme.accent;
            if (control.hovered) return Theme.accent;
            return Theme.separator;
        }

        Icon {
            visible: control.checked && control.checkState !== Qt.PartiallyChecked
            name: "check"
            size: Math.max(10, control.boxSize - 5)
            weight: 600
            color: "#FFFFFF"
            anchors.centerIn: parent
        }

        Rectangle {
            visible: control.checkState === Qt.PartiallyChecked
            width: Math.round(control.boxSize * 0.55)
            height: 2
            radius: 1
            color: "#FFFFFF"
            anchors.centerIn: parent
        }

        FocusRing {
            target: indicatorBox
            isTextInput: false
        }
    }

    contentItem: Text {
        id: labelText
        text: control.text
        font: (control.sizeClass === "small") ? Typography.subheadline : Typography.body
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

    Keys.onSpacePressed: function(event) {
        if (control.enabled) {
            FocusModel.markKeyboardNavigation();
            control.toggle();
            event.accepted = true;
        }
    }
}
