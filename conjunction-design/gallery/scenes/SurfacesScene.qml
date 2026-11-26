import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Surface {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    Flickable {
        anchors.fill: parent
        anchors.margins: Geometry.contentPadding
        clip: true
        contentWidth: width
        contentHeight: surfCol.implicitHeight

        ColumnLayout {
            id: surfCol
            width: parent.width
            spacing: Spacing.md

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Surfaces, Continuous Squircles & Concentric Nesting"
                font: Typography.windowTitle
                color: Theme.textPrimary
                elide: Text.ElideRight
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
                    Layout.minimumWidth: 0
                    height: 100

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        Item { Layout.fillHeight: true }
                        Text { Layout.fillWidth: true; Layout.minimumWidth: 0; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: "Base Surface"; font: Typography.controlLabel; color: Theme.textPrimary }
                        Text { Layout.fillWidth: true; Layout.minimumWidth: 0; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: "radius 12pt"; font: Typography.caption; color: Theme.textSecondary }
                        Item { Layout.fillHeight: true }
                    }
                }

                Surface {
                    elevation: "popover"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    height: 100

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        Item { Layout.fillHeight: true }
                        Text { Layout.fillWidth: true; Layout.minimumWidth: 0; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: "Popover Surface"; font: Typography.controlLabel; color: Theme.textPrimary }
                        Text { Layout.fillWidth: true; Layout.minimumWidth: 0; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: "cr = 14pt, shadow 24%"; font: Typography.caption; color: Theme.textSecondary }
                        Item { Layout.fillHeight: true }
                    }
                }

                Surface {
                    elevation: "dialog"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    height: 100

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        Item { Layout.fillHeight: true }
                        Text { Layout.fillWidth: true; Layout.minimumWidth: 0; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: "Dialog / Window"; font: Typography.controlLabel; color: Theme.textPrimary }
                        Text { Layout.fillWidth: true; Layout.minimumWidth: 0; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: "cr = 16pt (24.5pt tangent)"; font: Typography.caption; color: Theme.textSecondary }
                        Item { Layout.fillHeight: true }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Concentric Nesting Formula: R_inner = max(4, R_outer - padding)"
                font: Typography.sectionHeading
                color: Theme.textPrimary
                wrapMode: Text.WordWrap
            }

            // Outer 16pt squircle with 8pt pad -> Inner 8pt squircle
            SquircleRect {
                Layout.fillWidth: true
                Layout.maximumWidth: 340
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
                        anchors.fill: parent
                        anchors.margins: 8
                        text: "Outer 16pt - Pad 8pt = Inner 8pt Continuous Squircle"
                        font: Typography.subheadline
                        color: Theme.textPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
