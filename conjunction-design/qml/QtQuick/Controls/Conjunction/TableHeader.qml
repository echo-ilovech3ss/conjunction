import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Rectangle {
    id: root

    property var columns: []
    implicitWidth: parent ? parent.width : 400
    implicitHeight: 28
    color: Theme.surfaceSecondary
    border.color: Theme.separator
    border.width: Geometry.separatorThickness

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Spacing.md
        anchors.rightMargin: Spacing.md
        spacing: Spacing.md

        Repeater {
            model: root.columns
            Text {
                Layout.fillWidth: true
                text: String(modelData).toUpperCase()
                font: Typography.caption
                color: Theme.textSecondary
                elide: Text.ElideRight
            }
        }
    }
}
