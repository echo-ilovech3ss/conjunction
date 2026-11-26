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
        spacing: Spacing.md

        Toolbar {
            Layout.fillWidth: true

            leadingItems: [
                ToolButton { iconName: "arrow-left"; tooltipText: "Back" },
                ToolButton { iconName: "arrow-right"; tooltipText: "Forward" },
                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.maximumWidth: Math.min(180, Math.round(root.width * 0.20))
                    text: Appearance.stressMode ? Appearance.stressLongTitle : "Conjunction Workspace"
                    font: Typography.sectionHeading
                    color: Theme.textPrimary
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            ]

            centerItems: [
                SegmentedControl {
                    currentIndex: 0
                    Layout.fillWidth: true
                    Layout.maximumWidth: Math.min(200, Math.round(root.width * 0.34))
                    Segment { iconName: "copy"; text: "Overview" }
                    Segment { iconName: "settings"; text: "Inspector" }
                }
            ]

            trailingItems: [
                SearchField {
                    Layout.preferredWidth: Math.min(140, Math.round(root.width * 0.18))
                    Layout.minimumWidth: 52
                    Layout.maximumWidth: 160
                    Layout.fillWidth: true
                },
                ToolButton { iconName: "settings"; tooltipText: "View Options" },
                Button {
                    text: "Share"
                    isDefault: true
                    Layout.minimumWidth: 44
                    Layout.maximumWidth: 76
                }
            ]
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Geometry.contentPadding
            spacing: Spacing.md

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Application Toolbar Architecture"
                font: Typography.windowTitle
                color: Theme.textPrimary
                elide: Text.ElideRight
            }

            Text {
                text: "The toolbar integrates cleanly with the top of the window. Leading regions house navigation and title context; center regions house prominent view selectors; trailing regions house search and secondary commands."
                font: Typography.body
                color: Theme.textSecondary
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }

            Item { Layout.fillHeight: true }
        }
    }
}
