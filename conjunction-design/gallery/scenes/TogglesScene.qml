import QtQuick
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls

Surface {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Geometry.contentPadding
        spacing: Spacing.md

        Text {
            text: "Selection & Toggle Controls"
            font: Typography.windowTitle
            color: Theme.textPrimary
        }

        Text {
            text: "Checkbox: used for settings taking effect after form confirmation.
Switch: used for settings with immediate, emphasized system state changes."
            font: Typography.secondaryBody
            color: Theme.textSecondary
        }

        Rectangle {
            Layout.fillWidth: true
            height: Geometry.separatorThickness
            color: Theme.separator
        }

        RowLayout {
            spacing: Spacing.xl
            Layout.fillWidth: true

            ColumnLayout {
                spacing: Spacing.sm

                Text {
                    text: "Checkboxes"
                    font: Typography.sectionHeading
                    color: Theme.textPrimary
                }

                CheckBox {
                    text: "Unchecked Option"
                    checked: false
                }

                CheckBox {
                    text: "Checked Option"
                    checked: true
                }

                CheckBox {
                    text: "Indeterminate Option"
                    checkState: Qt.PartiallyChecked
                }

                CheckBox {
                    text: "Disabled Checked"
                    checked: true
                    enabled: false
                }
            }

            ColumnLayout {
                spacing: Spacing.sm

                Text {
                    text: "Radio Buttons (Exclusive Group)"
                    font: Typography.sectionHeading
                    color: Theme.textPrimary
                }

                RadioButton {
                    text: "Automatic Configuration"
                    checked: true
                }

                RadioButton {
                    text: "Manual Architecture"
                }

                RadioButton {
                    text: "Custom Fallback Engine"
                }

                RadioButton {
                    text: "Disabled Radio"
                    enabled: false
                }
            }

            ColumnLayout {
                spacing: Spacing.sm

                Text {
                    text: "Switches (Immediate State)"
                    font: Typography.sectionHeading
                    color: Theme.textPrimary
                }

                Switch {
                    text: "Hardware Acceleration (ON)"
                    checked: true
                }

                Switch {
                    text: "Background Indexing (OFF)"
                    checked: false
                }

                Switch {
                    text: "Disabled Feature"
                    checked: true
                    enabled: false
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
