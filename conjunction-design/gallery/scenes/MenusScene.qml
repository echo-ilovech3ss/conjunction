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
            text: "Desktop Menus & Action Model"
            font: Typography.windowTitle
            color: Theme.textPrimary
        }

        Text {
            text: "Dense desktop interaction surfaces supporting icons, shortcut labels, headings, checkable items, and shared Action models."
            font: Typography.secondaryBody
            color: Theme.textSecondary
        }

        Rectangle {
            Layout.fillWidth: true
            height: Geometry.separatorThickness
            color: Theme.separator
        }

        RowLayout {
            spacing: Spacing.md

            Button {
                id: openMenuBtn
                text: "Open File Menu"
                iconName: "settings"
                onClicked: sampleMenu.popup(openMenuBtn, 0, openMenuBtn.height + Spacing.xs)
            }

            Menu {
                id: sampleMenu
                title: "File"

                MenuHeading { text: "Document Actions" }
                MenuItem { text: "New Window"; iconName: "settings"; shortcutText: "Ctrl+N" }
                MenuItem { text: "Open Bundle..."; iconName: "search"; shortcutText: "Ctrl+O" }
                MenuItem { text: "Quick Refresh"; iconName: "refresh"; shortcutText: "F5" }
                MenuSeparator {}
                MenuHeading { text: "Preferences" }
                CheckableMenuItem { text: "Show System Applications"; checked: true }
                CheckableMenuItem { text: "Developer Diagnostics"; checked: false }
                MenuSeparator {}
                MenuItem { text: "Delete Unused State"; iconName: "close"; isDestructive: true; shortcutText: "Ctrl+Del" }
            }

            ComboBox {
                model: ["Package Architecture (x86_64)", "ARM64 Emulation", "Wine Win32 Bridge", "Proton Game Container"]
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 120
            radius: Geometry.radiusMedium
            color: Theme.surfaceSecondary
            border.color: Theme.separator
            border.width: Geometry.separatorThickness

            Text {
                anchors.centerIn: parent
                text: "Right-Click Here To Open Context Menu"
                font: Typography.controlLabel
                color: Theme.textSecondary
            }

            ContextMenu {
                menu: contextMenu
            }

            Menu {
                id: contextMenu
                title: "Context"
                MenuItem { text: "Inspect Process"; iconName: "search" }
                MenuItem { text: "Copy Identifier"; iconName: "copy"; shortcutText: "Ctrl+C" }
                MenuSeparator {}
                MenuItem { text: "Terminate Application"; iconName: "close"; isDestructive: true }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
