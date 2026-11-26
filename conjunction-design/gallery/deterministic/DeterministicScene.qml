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

    Flickable {
        anchors.fill: parent
        anchors.margins: Geometry.windowMargin
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, detMainCol.implicitHeight)

        ColumnLayout {
            id: detMainCol
            width: parent.width
            height: Math.max(parent.height, implicitHeight)
            spacing: Spacing.md

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Spacing.md

                Icon {
                    name: "settings"
                    size: 24
                    color: Theme.accent
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                }

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: "Conjunction Design System Benchmark"
                    font: Typography.windowTitle
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                }

                Rectangle {
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 24
                    radius: Geometry.radiusPill
                    color: Theme.selection

                    Text {
                        anchors.centerIn: parent
                        width: Math.max(0, parent.width - 8)
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
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

            // 2-Column Content Grid (stacks to 1 column at narrow window width)
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: root.width < 540 ? 1 : 2
                columnSpacing: Spacing.md
                rowSpacing: Spacing.md

                // Left Column: Hierarchy & Dense Content
                Surface {
                    elevation: "base"
                    Layout.fillWidth: true
                    Layout.fillHeight: root.width >= 540
                    Layout.minimumHeight: 200
                    implicitHeight: detLeftCol.implicitHeight + Geometry.contentPadding * 2

                    ColumnLayout {
                        id: detLeftCol
                        anchors.fill: parent
                        anchors.margins: Geometry.contentPadding
                        spacing: Spacing.sm

                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            elide: Text.ElideRight
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
                            Layout.minimumWidth: 0
                        }

                        Text {
                            text: "The Conjunction architecture decouples design tokens from arbitrary rendering parameters to enforce systematic elegance and high accessibility across light, dark, and localized views."
                            font: Typography.secondaryBody
                            color: Theme.textSecondary
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: Geometry.separatorThickness
                            color: Theme.separator
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            elide: Text.ElideRight
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
                                Layout.minimumWidth: 0
                                radius: Geometry.radiusSmall
                                color: Theme.surfaceSecondary
                                Text { anchors.centerIn: parent; width: Math.max(0, parent.width - 6); horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: "PID: 1042"; font: Typography.monospace; color: Theme.textPrimary }
                            }
                            Rectangle {
                                height: 24
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                radius: Geometry.radiusSmall
                                color: Theme.surfaceSecondary
                                Text { anchors.centerIn: parent; width: Math.max(0, parent.width - 6); horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: "UID: 1000"; font: Typography.monospace; color: Theme.textPrimary }
                            }
                            Rectangle {
                                height: 24
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                radius: Geometry.radiusSmall
                                color: Theme.surfaceSecondary
                                Text { anchors.centerIn: parent; width: Math.max(0, parent.width - 6); horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: "ARCH: x86_64"; font: Typography.monospace; color: Theme.textPrimary }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                // Right Column: Controls, Focus, States
                Surface {
                    elevation: "raised"
                    Layout.fillWidth: true
                    Layout.fillHeight: root.width >= 540
                    Layout.minimumHeight: 200
                    implicitHeight: detRightCol.implicitHeight + Geometry.contentPadding * 2

                    ColumnLayout {
                        id: detRightCol
                        anchors.fill: parent
                        anchors.margins: Geometry.contentPadding
                        spacing: Spacing.sm

                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            elide: Text.ElideRight
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
                                Text { Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight; text: "Active Focus Target"; font: Typography.controlLabel; color: Theme.textPrimary }
                                Icon { name: "check"; size: 16; color: Theme.accent; Layout.preferredWidth: 16; Layout.preferredHeight: 16 }
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
                                Text { Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight; text: "Selected Navigation Row"; font: Typography.controlLabel; color: Theme.selectionText }
                            }
                        }

                        // Semantic Status badges
                        RowLayout {
                            spacing: Spacing.xs
                            Layout.fillWidth: true

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                height: 24
                                radius: Geometry.radiusSmall
                                color: Theme.success
                                Text { anchors.centerIn: parent; width: Math.max(0, parent.width - 6); horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: "SUCCESS"; font: Typography.caption; color: Theme.successText }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                height: 24
                                radius: Geometry.radiusSmall
                                color: Theme.warning
                                Text { anchors.centerIn: parent; width: Math.max(0, parent.width - 6); horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: "WARNING"; font: Typography.caption; color: Theme.warningText }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                height: 24
                                radius: Geometry.radiusSmall
                                color: Theme.destructive
                                Text { anchors.centerIn: parent; width: Math.max(0, parent.width - 6); horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: "DESTRUCTIVE"; font: Typography.caption; color: Theme.destructiveText }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }
}
