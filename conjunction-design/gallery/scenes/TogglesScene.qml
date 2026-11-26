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
            Layout.fillWidth: true
            text: "Selection & Toggle Controls"
            font: Typography.windowTitle
            color: Theme.textPrimary
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: "Checkbox: used for settings taking effect after form confirmation.\nSwitch: used for settings with immediate, emphasized system state changes."
            font: Typography.secondaryBody
            color: Theme.textSecondary
            wrapMode: Text.Wrap
        }

        Rectangle {
            Layout.fillWidth: true
            height: Geometry.separatorThickness
            color: Theme.separator
        }

        RowLayout {
            spacing: Spacing.md
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Spacing.sm

                Text {
                    Layout.fillWidth: true
                    text: "Checkboxes"
                    font: Typography.sectionHeading
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                }

                CheckBox {
                    Layout.fillWidth: true; Layout.minimumWidth: 0
                    text: Appearance.stressMode ? Appearance.stressLongTitle : "Unchecked Option"
                    checked: false
                }

                CheckBox {
                    Layout.fillWidth: true; Layout.minimumWidth: 0
                    text: "Checked Option"
                    checked: true
                }

                CheckBox {
                    Layout.fillWidth: true; Layout.minimumWidth: 0
                    text: "Indeterminate Option"
                    checkState: Qt.PartiallyChecked
                }

                CheckBox {
                    Layout.fillWidth: true; Layout.minimumWidth: 0
                    text: "Disabled Checked"
                    checked: true
                    enabled: false
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Spacing.sm

                Text {
                    Layout.fillWidth: true
                    text: "Radio Buttons (Exclusive Group)"
                    font: Typography.sectionHeading
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                }

                RadioButton {
                    Layout.fillWidth: true; Layout.minimumWidth: 0
                    text: Appearance.stressMode ? Appearance.stressCompoundWord : "Automatic Configuration"
                    checked: true
                }

                RadioButton {
                    Layout.fillWidth: true; Layout.minimumWidth: 0
                    text: "Manual Architecture"
                }

                RadioButton {
                    Layout.fillWidth: true; Layout.minimumWidth: 0
                    text: "Custom Fallback Engine"
                }

                RadioButton {
                    Layout.fillWidth: true; Layout.minimumWidth: 0
                    text: "Disabled Radio"
                    enabled: false
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Spacing.sm

                Text {
                    Layout.fillWidth: true
                    text: "Switches (Immediate State)"
                    font: Typography.sectionHeading
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                }

                Switch {
                    Layout.fillWidth: true; Layout.minimumWidth: 0
                    text: Appearance.stressMode ? Appearance.stressUnbrokenUrl : "Hardware Acceleration (ON)"
                    checked: true
                }

                Switch {
                    Layout.fillWidth: true; Layout.minimumWidth: 0
                    text: "Background Indexing (OFF)"
                    checked: false
                }

                Switch {
                    Layout.fillWidth: true; Layout.minimumWidth: 0
                    text: "Disabled Feature"
                    checked: true
                    enabled: false
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
