import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Rectangle {
    id: root

    property string title: ""
    property string iconName: ""
    property string badgeText: ""
    property bool selected: false
    property bool enabled: true

    signal rowClicked()

    Layout.fillWidth: true
    implicitHeight: Geometry.controlHeightMedium
    radius: Geometry.radiusSmall

    color: selected ? Theme.selection : (hoverHandler.hovered ? Theme.surface : "transparent")

    Accessible.role: Accessible.ListItem
    Accessible.name: title
    Accessible.selected: selected

    HoverHandler { id: hoverHandler }

    TapHandler {
        onTapped: {
            if (root.enabled) {
                root.rowClicked();
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Spacing.sm
        anchors.rightMargin: Spacing.sm
        spacing: Spacing.sm

        Icon {
            visible: root.iconName !== ""
            name: root.iconName
            size: 16
            color: root.selected ? Theme.accent : (root.enabled ? Theme.textSecondary : Theme.textDisabled)
        }

        Text {
            Layout.fillWidth: true
            text: root.title
            font: Typography.controlLabel
            color: root.selected ? Theme.selectionText : (root.enabled ? Theme.textPrimary : Theme.textDisabled)
            elide: Text.ElideRight
        }

        Rectangle {
            visible: root.badgeText !== ""
            implicitWidth: badgeLabel.implicitWidth + Spacing.xs * 2
            implicitHeight: 18
            radius: Geometry.radiusPill
            color: root.selected ? Theme.accent : Theme.surfaceSecondary

            Text {
                id: badgeLabel
                anchors.centerIn: parent
                text: root.badgeText
                font: Typography.caption
                color: root.selected ? Theme.accentText : Theme.textSecondary
            }
        }
    }
}
