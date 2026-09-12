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
            text: "Semantic Color System"
            font: Typography.windowTitle
            color: Theme.textPrimary
        }

        Rectangle {
            Layout.fillWidth: true
            height: Geometry.separatorThickness
            color: Theme.separator
        }

        GridLayout {
            columns: 3
            rowSpacing: Spacing.sm
            columnSpacing: Spacing.sm
            Layout.fillWidth: true

            component ColorChip: Rectangle {
                property string title: ""
                property color chipColor: "transparent"
                property color labelColor: Theme.textPrimary
                property bool hasBorder: true

                Layout.fillWidth: true
                height: 48
                radius: Geometry.radiusSmall
                color: chipColor
                border.color: hasBorder ? Theme.separator : "transparent"
                border.width: Geometry.separatorThickness

                Text {
                    anchors.centerIn: parent
                    text: title
                    font: Typography.caption
                    color: labelColor
                }
            }

            ColorChip { title: "Background"; chipColor: Theme.background; labelColor: Theme.textPrimary }
            ColorChip { title: "Surface"; chipColor: Theme.surface; labelColor: Theme.textPrimary }
            ColorChip { title: "Surface Elevated"; chipColor: Theme.surfaceElevated; labelColor: Theme.textPrimary }

            ColorChip { title: "Accent"; chipColor: Theme.accent; labelColor: Theme.accentText; hasBorder: false }
            ColorChip { title: "Accent Hover"; chipColor: Theme.accentHover; labelColor: Theme.accentText; hasBorder: false }
            ColorChip { title: "Accent Pressed"; chipColor: Theme.accentPressed; labelColor: Theme.accentText; hasBorder: false }

            ColorChip { title: "Selection"; chipColor: Theme.selection; labelColor: Theme.selectionText }
            ColorChip { title: "Focus Ring"; chipColor: Theme.focusRing; labelColor: "#FFFFFF"; hasBorder: false }
            ColorChip { title: "Separator"; chipColor: Theme.separator; labelColor: Theme.textPrimary }

            ColorChip { title: "Success"; chipColor: Theme.success; labelColor: Theme.successText; hasBorder: false }
            ColorChip { title: "Warning"; chipColor: Theme.warning; labelColor: Theme.warningText; hasBorder: false }
            ColorChip { title: "Destructive"; chipColor: Theme.destructive; labelColor: Theme.destructiveText; hasBorder: false }
        }

        Item { Layout.fillHeight: true }
    }
}
