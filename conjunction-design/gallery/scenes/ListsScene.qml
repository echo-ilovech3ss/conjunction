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
            text: "Settings Rows & Dense Data Tables"
            font: Typography.windowTitle
            color: Theme.textPrimary
        }

        Rectangle {
            Layout.fillWidth: true
            height: Geometry.separatorThickness
            color: Theme.separator
        }

        Text {
            text: "List Rows (Settings & Preferences Pattern)"
            font: Typography.sectionHeading
            color: Theme.textPrimary
        }

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true

            ListRow {
                title: "Dark Mode Theme"
                subtitle: "Dynamically synchronize system palette between light and dark"
                iconName: "settings"
                accessoryItem: Switch { checked: Appearance.isDark; onToggled: Appearance.toggleTheme() }
            }

            ListRow {
                title: "Reduced Motion Accessibility"
                subtitle: "Collapse non-essential interface animations and transitions"
                iconName: "refresh"
                accessoryItem: Switch { checked: Appearance.reducedMotion; onToggled: Appearance.setReducedMotion(checked) }
            }

            ListRow {
                title: "Right-To-Left Text Alignment"
                subtitle: "Mirror interface controls for RTL language layouts"
                iconName: "arrow-right"
                accessoryItem: Button { text: "Toggle"; onClicked: Appearance.toggleRTL() }
            }
        }

        Text {
            text: "Desktop Data Table (High-density readability)"
            font: Typography.sectionHeading
            color: Theme.textPrimary
        }

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true

            TableHeader {
                columns: ["Application ID", "Version", "Architecture", "Backend"]
            }

            TableDataRow {
                values: ["dev.conjunction.terminal", "1.4.0", "x86_64", "Native .app"]
                selected: true
                isMonospace: true
            }

            TableDataRow {
                values: ["org.mozilla.firefox", "128.0", "x86_64", "Pacman Linux"]
                isMonospace: true
            }

            TableDataRow {
                values: ["com.valvesoftware.Steam", "1.0.0", "x86_64", "Flatpak Adapter"]
                isMonospace: true
            }
        }

        Item { Layout.fillHeight: true }
    }
}
