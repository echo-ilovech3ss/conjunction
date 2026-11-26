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

    Layout.fillWidth: true
    implicitWidth: parent ? parent.width : 300
    implicitHeight: Math.max(subtitle !== "" ? 54 : 44, textCol.implicitHeight + 12)
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
            Layout.preferredWidth: visible ? size : 0
            Layout.preferredHeight: visible ? size : 0
            color: root.selected ? Theme.accent : Theme.textPrimary
        }

        ColumnLayout {
            id: textCol
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 2

            Text {
                id: rowTitle
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: root.title
                font: Typography.body
                color: root.selected ? Theme.selectionText : Theme.textPrimary
                elide: Text.ElideRight
            }

            Text {
                id: rowSubtitle
                visible: root.subtitle !== ""
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: root.subtitle
                font: Typography.secondaryBody
                color: root.selected ? Theme.selectionText : Theme.textSecondary
                elide: Text.ElideRight
            }
        }

        Item {
            id: accessoryContainer
            visible: root.accessoryItem !== null
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: Math.max(60, root.width * 0.45)
            Layout.preferredWidth: root.accessoryItem ? Math.min(Layout.maximumWidth, root.accessoryItem.implicitWidth) : 0
            Layout.preferredHeight: root.accessoryItem ? root.accessoryItem.implicitHeight : 0
            implicitWidth: Layout.preferredWidth
            implicitHeight: Layout.preferredHeight
            data: root.accessoryItem ? [root.accessoryItem] : []
        }
    }

    ToolTip {
        visible: hoverHandler.hovered && (rowTitle.truncated || rowSubtitle.truncated)
        text: rowSubtitle.truncated && root.subtitle !== "" ? (root.title + "\n" + root.subtitle) : root.title
        delay: 400
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
