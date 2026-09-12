import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Rectangle {
    id: root

    property var values: []
    property bool selected: false
    property bool isMonospace: false

    signal clicked()

    implicitWidth: parent ? parent.width : 400
    implicitHeight: Geometry.controlHeightSmall + 8
    color: selected ? Theme.selection : (hoverHandler.hovered ? Theme.surfaceSecondary : Theme.surface)

    Accessible.role: Accessible.ListItem

    HoverHandler { id: hoverHandler }
    TapHandler { onTapped: root.clicked() }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Spacing.md
        anchors.rightMargin: Spacing.md
        spacing: Spacing.md

        Repeater {
            model: root.values
            Text {
                Layout.fillWidth: true
                text: String(modelData)
                font: root.isMonospace ? Typography.monospace : Typography.body
                color: root.selected ? Theme.selectionText : Theme.textPrimary
                elide: Text.ElideRight
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
