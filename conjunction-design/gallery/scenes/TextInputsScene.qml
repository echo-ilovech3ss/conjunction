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
            text: "Text Entry & Search Fields"
            font: Typography.windowTitle
            color: Theme.textPrimary
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
                spacing: Spacing.md
                Layout.preferredWidth: 320

                Text {
                    text: "Single-Line Text Fields"
                    font: Typography.sectionHeading
                    color: Theme.textPrimary
                }

                TextField {
                    placeholderText: "Standard Text Field"
                    Layout.fillWidth: true
                }

                TextField {
                    text: "Editable text content"
                    showClearButton: true
                    Layout.fillWidth: true
                }

                TextField {
                    placeholderText: "Leading Icon Field"
                    leadingIcon: "settings"
                    Layout.fillWidth: true
                }

                TextField {
                    text: "Invalid format error"
                    isError: true
                    Layout.fillWidth: true
                }

                TextField {
                    text: "Read-only disabled field"
                    enabled: false
                    Layout.fillWidth: true
                }
            }

            ColumnLayout {
                spacing: Spacing.md
                Layout.preferredWidth: 320

                Text {
                    text: "Search Field & Multi-Line Editor"
                    font: Typography.sectionHeading
                    color: Theme.textPrimary
                }

                SearchField {
                    text: "conjunction"
                    Layout.fillWidth: true
                }

                SearchField {
                    placeholderText: "Search applications..."
                    Layout.fillWidth: true
                }

                TextArea {
                    text: "Multi-line desktop text area supporting proportional font rendering, keyboard navigation, text selection, and word wrapping."
                    Layout.fillWidth: true
                    implicitHeight: 90
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
