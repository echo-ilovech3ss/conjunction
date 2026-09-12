import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Rectangle {
    id: root
    width: 800
    height: 600
    color: Theme.background
    LayoutMirroring.enabled: Appearance.isRTL
    LayoutMirroring.childrenInherit: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Geometry.windowMargin
        spacing: Spacing.md

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Spacing.md

            Icon {
                name: "settings"
                size: 24
                color: Theme.accent
            }

            Text {
                text: "Conjunction Design System Benchmark"
                font: Typography.windowTitle
                color: Theme.textPrimary
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 70
                height: 24
                radius: Geometry.radiusPill
                color: Theme.selection

                Text {
                    anchors.centerIn: parent
                    text: Appearance.effectiveTheme.toUpperCase()
                    font: Typography.caption
                    color: Theme.selectionText
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: Geometry.separatorThickness
            color: Theme.separator
        }

        // 2-Column Content Grid
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Spacing.md

            // Left Column: Hierarchy & Dense Content
            Surface {
                elevation: "base"
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Geometry.contentPadding
                    spacing: Spacing.sm

                    Text {
                        text: "Typography & Content Scale"
                        font: Typography.sectionHeading
                        color: Theme.textPrimary
                    }

                    Text {
                        text: "Primary body copy displaying regular weight, proportional line spacing, and crisp contrast."
                        font: Typography.body
                        color: Theme.textPrimary
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "The Conjunction architecture decouples design tokens from arbitrary rendering parameters to enforce systematic elegance and high accessibility across light, dark, and localized views."
                        font: Typography.secondaryBody
                        color: Theme.textSecondary
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: Geometry.separatorThickness
                        color: Theme.separator
                    }

                    Text {
                        text: "High-Density Data Row"
                        font: Typography.caption
                        color: Theme.textSecondary
                    }

                    // Dense items
                    RowLayout {
                        spacing: Spacing.xs
                        Layout.fillWidth: true

                        Rectangle {
                            height: 24
                            Layout.fillWidth: true
                            radius: Geometry.radiusSmall
                            color: Theme.surfaceSecondary
                            Text { anchors.centerIn: parent; text: "PID: 1042"; font: Typography.monospace; color: Theme.textPrimary }
                        }
                        Rectangle {
                            height: 24
                            Layout.fillWidth: true
                            radius: Geometry.radiusSmall
                            color: Theme.surfaceSecondary
                            Text { anchors.centerIn: parent; text: "UID: 1000"; font: Typography.monospace; color: Theme.textPrimary }
                        }
                        Rectangle {
                            height: 24
                            Layout.fillWidth: true
                            radius: Geometry.radiusSmall
                            color: Theme.surfaceSecondary
                            Text { anchors.centerIn: parent; text: "ARCH: x86_64"; font: Typography.monospace; color: Theme.textPrimary }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // Right Column: Controls, Focus, States
            Surface {
                elevation: "raised"
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Geometry.contentPadding
                    spacing: Spacing.sm

                    Text {
                        text: "Interaction & Focus Indicators"
                        font: Typography.sectionHeading
                        color: Theme.textPrimary
                    }

                    // Focusable item with active focus ring
                    Rectangle {
                        Layout.fillWidth: true
                        height: Geometry.controlHeightMedium
                        radius: Geometry.radiusMedium
                        color: Theme.surfaceSecondary
                        border.color: Theme.separator

                        FocusRing {
                            active: true
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Spacing.md
                            anchors.rightMargin: Spacing.md
                            Text { text: "Active Focus Target"; font: Typography.controlLabel; color: Theme.textPrimary }
                            Item { Layout.fillWidth: true }
                            Icon { name: "check"; size: 16; color: Theme.accent }
                        }
                    }

                    // Selection state
                    Rectangle {
                        Layout.fillWidth: true
                        height: Geometry.controlHeightMedium
                        radius: Geometry.radiusMedium
                        color: Theme.selection

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Spacing.md
                            anchors.rightMargin: Spacing.md
                            Text { text: "Selected Navigation Row"; font: Typography.controlLabel; color: Theme.selectionText }
                        }
                    }

                    // Semantic Status badges
                    RowLayout {
                        spacing: Spacing.xs
                        Layout.fillWidth: true

                        Rectangle {
                            Layout.fillWidth: true
                            height: 24
                            radius: Geometry.radiusSmall
                            color: Theme.success
                            Text { anchors.centerIn: parent; text: "SUCCESS"; font: Typography.caption; color: Theme.successText }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 24
                            radius: Geometry.radiusSmall
                            color: Theme.warning
                            Text { anchors.centerIn: parent; text: "WARNING"; font: Typography.caption; color: Theme.warningText }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 24
                            radius: Geometry.radiusSmall
                            color: Theme.destructive
                            Text { anchors.centerIn: parent; text: "DESTRUCTIVE"; font: Typography.caption; color: Theme.destructiveText }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
