import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.TextArea {
    id: control

    implicitWidth: 260
    implicitHeight: 120

    font: Typography.body
    color: enabled ? Theme.textPrimary : Theme.textDisabled
    selectionColor: Theme.selection
    selectedTextColor: Theme.selectionText
    placeholderTextColor: Theme.textSecondary
    wrapMode: TextEdit.WordWrap

    topPadding: Spacing.sm
    bottomPadding: Spacing.sm
    leftPadding: Spacing.sm
    rightPadding: Spacing.sm

    Accessible.role: Accessible.EditableText
    Accessible.name: placeholderText || "Text Area"
    Accessible.focusable: true

    background: SquircleRect {
        id: bg
        radius: Geometry.radiusTextField
        color: control.enabled ? Theme.controlBackgroundColor : Theme.controlFill
        borderColor: Appearance.shouldIncreaseContrast ? Theme.highContrastBorderColor : (control.activeFocus ? Theme.accent : Theme.separator)
        borderWidth: Geometry.separatorThickness

        FocusRing {
            target: bg
            isTextInput: true
        }
    }
}
