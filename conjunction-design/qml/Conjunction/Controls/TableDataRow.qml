import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Rectangle {
    id: root

    property var values: []
    property bool selected: false
    property bool isMonospace: false

    signal clicked()

    Layout.fillWidth: true
    implicitWidth: parent ? parent.width : 400
    implicitHeight: Math.max(Geometry.controlHeightSmall + 8, tableRowLayout.implicitHeight + 6)
    color: selected ? Theme.selection : (hoverHandler.hovered ? Theme.surfaceSecondary : Theme.surface)

    Accessible.role: Accessible.ListItem

    HoverHandler { id: hoverHandler }
    TapHandler { onTapped: root.clicked() }

    RowLayout {
        id: tableRowLayout
        anchors.fill: parent
        anchors.leftMargin: Spacing.md
        anchors.rightMargin: Spacing.md
        spacing: Spacing.md

        Repeater {
            model: root.values
            Text {
                id: cellText
                readonly property int colCount: Math.max(1, root.values ? root.values.length : 1)
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: Math.max(36, Math.floor((tableRowLayout.width - tableRowLayout.spacing * (colCount - 1)) / colCount))
                text: String(modelData)
                font: root.isMonospace ? Typography.monospace : Typography.body
                color: root.selected ? Theme.selectionText : Theme.textPrimary
                elide: Text.ElideRight

                HoverHandler { id: cellHover }
                ToolTip {
                    visible: cellHover.hovered && cellText.truncated && cellText.text !== ""
                    text: cellText.text
                    delay: 400
                }
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: Geometry.separatorThickness
        color: Theme.separator
    }
}
