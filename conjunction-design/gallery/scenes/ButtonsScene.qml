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
            text: "Button Hierarchy & Size Classes"
            font: Typography.windowTitle
            color: Theme.textPrimary
            elide: Text.ElideRight
        }

        Rectangle {
            Layout.fillWidth: true
            height: Geometry.separatorThickness
            color: Theme.separator
        }

        Text {
            Layout.fillWidth: true
            text: "Action Hierarchy"
            font: Typography.sectionHeading
            color: Theme.textPrimary
            elide: Text.ElideRight
        }

        Flow {
            Layout.fillWidth: true
            spacing: Spacing.sm

            Button {
                text: Appearance.stressMode ? Appearance.stressLongTitle : "Default Action"
                isDefault: true
                width: Math.min(implicitWidth, root.width - Geometry.contentPadding * 2)
            }

            Button {
                text: "Standard Button"
            }

            Button {
                text: "Secondary Action"
                isSecondary: true
            }

            Button {
                text: "Destructive Action"
                isDestructive: true
            }

            Button {
                text: "Disabled Button"
                enabled: false
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Icon Integration & Size Classes"
            font: Typography.sectionHeading
            color: Theme.textPrimary
            elide: Text.ElideRight
        }

        Flow {
            Layout.fillWidth: true
            spacing: Spacing.sm

            Button {
                sizeClass: "compact"
                text: "Compact (24px)"
                iconName: "settings"
            }

            Button {
                sizeClass: "regular"
                text: "Regular (32px)"
                iconName: "check"
            }

            Button {
                sizeClass: "large"
                text: "Large (40px)"
                iconName: "refresh"
                isDefault: true
            }

            Button {
                iconName: "search"
                text: ""
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Toolbar Buttons (Low rest weight, hover-activated)"
            font: Typography.sectionHeading
            color: Theme.textPrimary
            elide: Text.ElideRight
        }

        Flow {
            Layout.fillWidth: true
            spacing: Spacing.xs

            ToolButton {
                iconName: "arrow-left"
                tooltipText: "Navigate Back"
            }

            ToolButton {
                iconName: "arrow-right"
                tooltipText: "Navigate Forward"
            }

            ToolButton {
                iconName: "refresh"
                tooltipText: "Reload Content"
            }

            ToolButton {
                iconName: "settings"
                text: "Settings"
            }

            ToolButton {
                iconName: "copy"
                enabled: false
                tooltipText: "Copy Disabled"
            }
        }

        Item { Layout.fillHeight: true }
    }
}
