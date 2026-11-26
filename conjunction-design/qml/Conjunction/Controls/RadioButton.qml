import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.RadioButton {
    id: control

    // SPEC §2.3 Radio: mini 14, small 16, regular 18 (20 fitting), large 20
    property string sizeClass: "regular"
    readonly property int boxSize: Geometry.checkBoxSize(sizeClass)

    onPressed: FocusModel.markPointerNavigation()

    implicitWidth: Math.max(boxSize, indicatorCircle.width + (text !== "" ? Spacing.sm + labelText.implicitWidth : 0))
    implicitHeight: Math.max(boxSize + 2, labelText.implicitHeight)

    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.RadioButton
    Accessible.name: text
    Accessible.checked: checked
    Accessible.focusable: true

    indicator: Rectangle {
        id: indicatorCircle
        width: control.boxSize
        height: control.boxSize
        y: Math.round((control.height - height) * 0.5)
        radius: width * 0.5
        border.width: Appearance.shouldIncreaseContrast ? 1.0 : Geometry.separatorThickness

        color: {
            if (!control.enabled) return Theme.controlFill;
            if (control.checked) return Theme.accent;
            if (control.down) return Theme.controlFillPressed;
            return Theme.controlBackgroundColor;
        }

        border.color: {
            if (Appearance.shouldIncreaseContrast) return Theme.highContrastBorderColor;
            if (!control.enabled) return Theme.separator;
            if (control.checked || control.hovered) return Theme.accent;
            return Theme.separator;
        }

        Rectangle {
            id: innerDot
            visible: control.checked
            width: Math.max(6, Math.round(control.boxSize * 0.38))
            height: width
            radius: width * 0.5
            anchors.centerIn: parent
            color: control.enabled ? "#FFFFFF" : Theme.textDisabled
        }

        FocusRing {
            target: indicatorCircle
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
    }
}
