import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string iconName: ""
    property Item accessoryItem: null
    property bool selected: false
    property bool showSeparator: true

    signal clicked()

    implicitWidth: parent ? parent.width : 300
    implicitHeight: subtitle !== "" ? 54 : 44
    color: selected ? Theme.selection : (hoverHandler.hovered ? Theme.surfaceSecondary : Theme.surface)

    Accessible.role: Accessible.ListItem
    Accessible.name: title
    Accessible.selected: selected

    HoverHandler { id: hoverHandler }
    TapHandler { onTapped: root.clicked() }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Spacing.md
        anchors.rightMargin: Spacing.md
        spacing: Spacing.md

        Icon {
            visible: root.iconName !== ""
            name: root.iconName
            size: 20
            color: root.selected ? Theme.accent : Theme.textPrimary
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: root.title
                font: Typography.body
                color: root.selected ? Theme.selectionText : Theme.textPrimary
                elide: Text.ElideRight
            }

            Text {
                visible: root.subtitle !== ""
                text: root.subtitle
                font: Typography.secondaryBody
                color: root.selected ? Theme.selectionText : Theme.textSecondary
                elide: Text.ElideRight
            }
        }

        Item {
            id: accessoryContainer
            implicitWidth: root.accessoryItem ? root.accessoryItem.implicitWidth : 0
            implicitHeight: root.accessoryItem ? root.accessoryItem.implicitHeight : 0
            data: root.accessoryItem ? [root.accessoryItem] : []
        }
    }

    Rectangle {
        visible: root.showSeparator
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.iconName !== "" ? (Spacing.md * 2 + 20) : Spacing.md
        height: Geometry.separatorThickness
        color: Theme.separator
    }
}
