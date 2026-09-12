import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Surface {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Geometry.contentPadding
        spacing: Spacing.md

        Text {
            text: "Surfaces, Depth & Geometry"
            font: Typography.windowTitle
            color: Theme.textPrimary
        }

        Rectangle {
            Layout.fillWidth: true
            height: Geometry.separatorThickness
            color: Theme.separator
        }

        RowLayout {
            spacing: Spacing.md
            Layout.fillWidth: true

            Surface {
                elevation: "base"
                Layout.fillWidth: true
                height: 100

                ColumnLayout {
                    anchors.centerIn: parent
                    Text { text: "Base Surface"; font: Typography.controlLabel; color: Theme.textPrimary; Layout.alignment: Qt.AlignCenter }
                    Text { text: "elevation: \"base\""; font: Typography.caption; color: Theme.textSecondary; Layout.alignment: Qt.AlignCenter }
                }
            }

            Surface {
                elevation: "raised"
                Layout.fillWidth: true
                height: 100

                ColumnLayout {
                    anchors.centerIn: parent
                    Text { text: "Raised Card"; font: Typography.controlLabel; color: Theme.textPrimary; Layout.alignment: Qt.AlignCenter }
                    Text { text: "elevation: \"raised\""; font: Typography.caption; color: Theme.textSecondary; Layout.alignment: Qt.AlignCenter }
                }
            }

            Surface {
                elevation: "popover"
                Layout.fillWidth: true
                height: 100

                ColumnLayout {
                    anchors.centerIn: parent
                    Text { text: "Popover / Sheet"; font: Typography.controlLabel; color: Theme.textPrimary; Layout.alignment: Qt.AlignCenter }
                    Text { text: "elevation: \"popover\""; font: Typography.caption; color: Theme.textSecondary; Layout.alignment: Qt.AlignCenter }
                }
            }
        }

        Text {
            text: "Corner Radii Hierarchy"
            font: Typography.sectionHeading
            color: Theme.textPrimary
        }

        RowLayout {
            spacing: Spacing.md
            Layout.fillWidth: true

            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: Geometry.radiusSmall
                color: Theme.surfaceSecondary
                border.color: Theme.separator
                border.width: Geometry.separatorThickness
                Text { anchors.centerIn: parent; text: "Small (4px)"; font: Typography.caption; color: Theme.textPrimary }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: Geometry.radiusMedium
                color: Theme.surfaceSecondary
                border.color: Theme.separator
                border.width: Geometry.separatorThickness
                Text { anchors.centerIn: parent; text: "Medium (8px)"; font: Typography.caption; color: Theme.textPrimary }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: Geometry.radiusLarge
                color: Theme.surfaceSecondary
                border.color: Theme.separator
                border.width: Geometry.separatorThickness
                Text { anchors.centerIn: parent; text: "Large (12px)"; font: Typography.caption; color: Theme.textPrimary }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: Geometry.radiusPill
                color: Theme.surfaceSecondary
                border.color: Theme.separator
                border.width: Geometry.separatorThickness
                Text { anchors.centerIn: parent; text: "Pill (Badge)"; font: Typography.caption; color: Theme.textPrimary }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
