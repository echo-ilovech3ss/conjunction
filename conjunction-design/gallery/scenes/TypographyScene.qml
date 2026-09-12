import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Surface {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Geometry.contentPadding
        spacing: Spacing.md

        Text {
            text: "Typography Hierarchy"
            font: Typography.windowTitle
            color: Theme.textPrimary
        }

        Rectangle {
            Layout.fillWidth: true
            height: Geometry.separatorThickness
            color: Theme.separator
        }

        ColumnLayout {
            spacing: Spacing.sm
            Layout.fillWidth: true

            Text {
                text: "Display Title (24pt)"
                font: Typography.display
                color: Theme.textPrimary
            }

            Text {
                text: "Window / Dialog Title (16pt)"
                font: Typography.windowTitle
                color: Theme.textPrimary
            }

            Text {
                text: "Section Heading (13pt)"
                font: Typography.sectionHeading
                color: Theme.textPrimary
            }

            Text {
                text: "Primary body text for standard interface content, dialogues, and reading views (11pt)."
                font: Typography.body
                color: Theme.textPrimary
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Text {
                text: "Secondary body text used for supporting descriptions, subheadings, and secondary information (10pt)."
                font: Typography.secondaryBody
                color: Theme.textSecondary
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Text {
                text: "Caption metadata, status indications, and footnote labels (9pt)."
                font: Typography.caption
                color: Theme.textSecondary
            }

            Text {
                text: "Control Label (Buttons, Toggles, Tabs) (11pt)"
                font: Typography.controlLabel
                color: Theme.textPrimary
            }

            Text {
                text: "dev.conjunction.app/1.0.0 (monospace sha256:7f83b165...)"
                font: Typography.monospace
                color: Theme.textPrimary
            }
        }

        Item { Layout.fillHeight: true }
    }
}
