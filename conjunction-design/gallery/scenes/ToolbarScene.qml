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
                Text { text: "Conjunction Workspace"; font: Typography.sectionHeading; color: Theme.textPrimary; verticalAlignment: Text.AlignVCenter }
            ]

            centerItems: [
                SegmentedControl {
                    currentIndex: 0
                    Segment { iconName: "copy"; text: "Overview" }
                    Segment { iconName: "settings"; text: "Inspector" }
                }
            ]

            trailingItems: [
                SearchField { implicitWidth: 160 },
                ToolButton { iconName: "settings"; tooltipText: "View Options" },
                Button { text: "Share"; isDefault: true }
            ]
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            anchors.margins: Geometry.contentPadding
            spacing: Spacing.md

            Text {
                text: "Application Toolbar Architecture"
                font: Typography.windowTitle
                color: Theme.textPrimary
            }

            Text {
                text: "The toolbar integrates cleanly with the top of the window. Leading regions house navigation and title context; center regions house prominent view selectors; trailing regions house search and secondary commands."
                font: Typography.body
                color: Theme.textSecondary
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Item { Layout.fillHeight: true }
        }
    }
}
