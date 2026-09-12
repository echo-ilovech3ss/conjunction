import QtQuick
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls

Rectangle {
    id: root
    color: Theme.background
    LayoutMirroring.enabled: Appearance.isRTL
    LayoutMirroring.childrenInherit: true

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Toolbar {
            Layout.fillWidth: true

            leadingItems: [
                ToolButton { iconName: "arrow-left"; tooltipText: "Back" },
                ToolButton { iconName: "arrow-right"; tooltipText: "Forward" },
                Text { text: "Conjunction Applications"; font: Typography.sectionHeading; color: Theme.textPrimary; verticalAlignment: Text.AlignVCenter }
            ]

            centerItems: [
                SegmentedControl {
                    currentIndex: 0
                    Segment { iconName: "copy"; text: "Installed" }
                    Segment { iconName: "search"; text: "Updates" }
                    Segment { iconName: "settings"; text: "Settings" }
                }
            ]

            trailingItems: [
                SearchField { implicitWidth: 180 },
                ToolButton { iconName: "settings"; tooltipText: "Filter" },
                Button { text: "Add App"; isDefault: true }
            ]
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Sidebar {
                Layout.fillHeight: true
                implicitWidth: 200

                SidebarSection { title: "Locations" }
                SidebarRow { title: "Workstation Apps"; iconName: "settings"; selected: true; badgeText: "24" }
                SidebarRow { title: "Native Bundles"; iconName: "copy"; badgeText: "5" }
                SidebarRow { title: "Linux Desktop Entries"; iconName: "search"; badgeText: "19" }

                SidebarSection { title: "Maintenance" }
                SidebarRow { title: "Daemon Telemetry"; iconName: "check" }
                SidebarRow { title: "Privileged Log"; iconName: "warning"; badgeText: "1" }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.surface

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    TableHeader {
                        columns: ["Application Name", "Identifier", "Status", "Actions"]
                    }

                    TableDataRow {
                        values: ["Terminal Emulation", "dev.conjunction.term", "Active (PID 1042)", "Running"]
                        selected: true
                        isMonospace: true
                    }

                    TableDataRow {
                        values: ["System Monitor", "org.conjunction.monitor", "Active (PID 1109)", "Running"]
                        isMonospace: true
                    }

                    TableDataRow {
                        values: ["Text Editor", "dev.conjunction.editor", "Idle", "Ready"]
                        isMonospace: true
                    }

                    TableDataRow {
                        values: ["Arch Package Manager", "org.conjunction.pacman", "Ready", "Ready"]
                        isMonospace: true
                    }

                    Item { Layout.fillHeight: true }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 48
                        color: Theme.surfaceSecondary
                        border.color: Theme.separator
                        border.width: Geometry.separatorThickness

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Spacing.md
                            anchors.rightMargin: Spacing.md
                            spacing: Spacing.sm

                            Button {
                                id: inspectBtn
                                text: "Inspect Details"
                                onClicked: refPopover.open()
                            }

                            Button {
                                text: "Remove Selected"
                                isDestructive: true
                                onClicked: refAlert.open()
                            }

                            Button {
                                text: "View Manifest Sheet"
                                onClicked: refSheet.open()
                            }

                            Item { Layout.fillWidth: true }

                            Button {
                                text: "Cancel"
                            }

                            Button {
                                text: "Apply Changes"
                                isDefault: true
                            }
                        }
                    }
                }
            }
        }
    }

    Popover {
        id: refPopover
        invokerItem: inspectBtn
        x: inspectBtn.x + Spacing.md
        y: root.height - 240
        implicitWidth: 260
        implicitHeight: 180

        ColumnLayout {
            anchors.fill: parent
            spacing: Spacing.sm

            Text { text: "Quick Inspection"; font: Typography.sectionHeading; color: Theme.textPrimary }
            Text { text: "Bundle: dev.conjunction.term
Version: 1.4.0 (x86_64)
Security: Signed sandbox"; font: Typography.secondaryBody; color: Theme.textSecondary }
            Item { Layout.fillHeight: true }
            Button { text: "Dismiss"; isDefault: true; onClicked: refPopover.close() }
        }
    }

    Alert {
        id: refAlert
        alertType: "destructive"
        titleText: "Delete Selected Application?"
        messageText: "This action will permanently purge the bundle directory from the workstation filesystem."
    }

    Sheet {
        id: refSheet
        titleText: "Application Manifest Inspector"
        messageText: "Metadata extracted from /Applications/dev.conjunction.term.app/Contents/Info.toml confirms full compatibility with Arch Linux."
    }
}
