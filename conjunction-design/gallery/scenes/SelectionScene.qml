import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Surface {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    property int selectedIndex: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Geometry.contentPadding
        spacing: Spacing.md

        Text {
            text: "Selection System"
            font: Typography.windowTitle
            color: Theme.textPrimary
        }

        Rectangle {
            Layout.fillWidth: true
            height: Geometry.separatorThickness
            color: Theme.separator
        }

        ColumnLayout {
            spacing: Spacing.xs
            Layout.fillWidth: true

            Repeater {
                model: [
                    "Conjunction Core Framework",
                    "Application Services Daemon (Selected)",
                    "Native Package Adapters",
                    "Desktop Shell Integration"
                ]

                delegate: Rectangle {
                    id: itemDelegate
                    property bool isSelected: index === root.selectedIndex
                    property bool isHovered: hoverHandler.hovered

                    Layout.fillWidth: true
                    height: Geometry.controlHeightMedium
                    radius: Geometry.radiusSmall
                    color: isSelected ? Theme.selection : (isHovered ? Theme.surfaceSecondary : "transparent")

                    HoverHandler { id: hoverHandler }

                    TapHandler {
                        onTapped: root.selectedIndex = index
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Spacing.md
                        anchors.rightMargin: Spacing.md

                        Text {
                            text: modelData
                            font: Typography.body
                            color: itemDelegate.isSelected ? Theme.selectionText : Theme.textPrimary
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            visible: itemDelegate.isSelected
                            text: "✓"
                            font: Typography.controlLabel
                            color: Theme.accent
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
