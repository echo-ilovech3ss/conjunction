import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Rectangle {
    id: root

    property var columns: []
    Layout.fillWidth: true
    implicitWidth: parent ? parent.width : 400
    implicitHeight: Math.max(28, headerRow.implicitHeight + 10)
    color: Theme.surfaceSecondary
    border.color: Theme.separator
    border.width: Geometry.separatorThickness

    RowLayout {
        id: headerRow
        anchors.fill: parent
        anchors.leftMargin: Spacing.md
        anchors.rightMargin: Spacing.md
        spacing: Spacing.md

        Repeater {
            model: root.columns
            Text {
                readonly property int colCount: Math.max(1, root.columns ? root.columns.length : 1)
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: Math.max(36, Math.floor((headerRow.width - headerRow.spacing * (colCount - 1)) / colCount))
                text: String(modelData).toUpperCase()
                font: Typography.caption
                color: Theme.textSecondary
                elide: Text.ElideRight
            }
        }
    }
}
