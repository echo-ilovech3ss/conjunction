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
                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.maximumWidth: Math.min(160, Math.round(root.width * 0.16))
                    text: Appearance.stressMode ? Appearance.stressLongTitle : "Conjunction Applications"
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
                    Layout.minimumWidth: 72
                    Layout.maximumWidth: Math.min(220, Math.round(root.width * 0.28))
                    Segment { iconName: "copy"; text: "Installed" }
                    Segment { iconName: "search"; text: "Updates" }
                    Segment { iconName: "settings"; text: "Settings" }
                }
            ]

            trailingItems: [
                SearchField {
                    Layout.preferredWidth: Math.min(120, Math.round(root.width * 0.14))
                    Layout.minimumWidth: 40
                    Layout.maximumWidth: 140
                    Layout.fillWidth: true
                },
                ToolButton { iconName: "settings"; tooltipText: "Filter" },
                Button {
                    text: "Add App"
                    isDefault: true
                    Layout.fillWidth: true
                    Layout.minimumWidth: 36
                    Layout.maximumWidth: 72
                }
            ]
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Sidebar {
                Layout.fillHeight: true
                implicitWidth: Math.min(190, Math.round(root.width * 0.30))

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
                        Layout.preferredHeight: Math.max(48, bottomFlow.implicitHeight + 16)
                        color: Theme.surfaceSecondary
                        border.color: Theme.separator
                        border.width: Geometry.separatorThickness

                        Flow {
                            id: bottomFlow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Spacing.md
                            anchors.rightMargin: Spacing.md
                            spacing: Spacing.xs

                            Button {
                                id: inspectBtn
                                text: "Inspect Details"
                                Layout.maximumWidth: 120
                                onClicked: refPopover.open()
                            }

                            Button {
                                text: "Remove"
                                isDestructive: true
                                Layout.maximumWidth: 96
                                onClicked: refAlert.open()
                            }

                            Button {
                                text: "Manifest"
                                Layout.maximumWidth: 96
                                onClicked: refSheet.open()
                            }

                            Button {
                                text: "Cancel"
                                Layout.maximumWidth: 80
                            }

                            Button {
                                text: "Apply"
                                isDefault: true
                                Layout.maximumWidth: 80
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
