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
            text: "Surfaces, Continuous Squircles & Concentric Nesting"
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
                    Text { text: "radius 12pt"; font: Typography.caption; color: Theme.textSecondary; Layout.alignment: Qt.AlignCenter }
                }
            }

            Surface {
                elevation: "popover"
                Layout.fillWidth: true
                height: 100

                ColumnLayout {
                    anchors.centerIn: parent
                    Text { text: "Popover Surface"; font: Typography.controlLabel; color: Theme.textPrimary; Layout.alignment: Qt.AlignCenter }
                    Text { text: "cr = 14pt, shadow 24%"; font: Typography.caption; color: Theme.textSecondary; Layout.alignment: Qt.AlignCenter }
                }
            }

            Surface {
                elevation: "dialog"
                Layout.fillWidth: true
                height: 100

                ColumnLayout {
                    anchors.centerIn: parent
                    Text { text: "Dialog / Window"; font: Typography.controlLabel; color: Theme.textPrimary; Layout.alignment: Qt.AlignCenter }
                    Text { text: "cr = 16pt (24.5pt tangent)"; font: Typography.caption; color: Theme.textSecondary; Layout.alignment: Qt.AlignCenter }
                }
            }
        }

        Text {
            text: "Concentric Nesting Formula: R_inner = max(4, R_outer - padding)"
            font: Typography.sectionHeading
            color: Theme.textPrimary
        }

        // Outer 16pt squircle with 8pt pad -> Inner 8pt squircle
        SquircleRect {
            Layout.preferredWidth: 340
            Layout.preferredHeight: 84
            radius: Geometry.radiusWindow // 16 pt
            color: Theme.controlFill
            borderColor: Theme.separator
            borderWidth: 1

            SquircleRect {
                anchors.fill: parent
                anchors.margins: 8
                radius: Geometry.concentricRadius(Geometry.radiusWindow, 8) // 8 pt
                color: Theme.surface
                borderColor: Theme.separator
                borderWidth: 1

                Text {
                    anchors.centerIn: parent
                    text: "Outer 16pt - Pad 8pt = Inner 8pt Continuous Squircle"
                    font: Typography.subheadline
                    color: Theme.textPrimary
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
