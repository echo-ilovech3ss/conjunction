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
    property bool focusedSelection: false

    signal rowClicked()

    // SPEC §4.7: 30 pt height, cr = 10 pt inside 10 pt inset
    Layout.fillWidth: true
    implicitHeight: Math.max(30, rowTitleText.implicitHeight + 8)
    radius: Geometry.radiusSidebarPill

    color: selected
        ? (focusedSelection ? Theme.selectedContentBackgroundColor : (Theme.isDark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)))
        : (hoverHandler.hovered ? Theme.controlFill : "transparent")
    border.color: (selected && Appearance.shouldIncreaseContrast) ? Theme.highContrastBorderColor : "transparent"
    border.width: (selected && Appearance.shouldIncreaseContrast) ? 1.0 : 0

    Accessible.role: Accessible.ListItem
    Accessible.name: title
    Accessible.selected: selected

    HoverHandler { id: hoverHandler }

    TapHandler {
        onTapped: {
            FocusModel.markPointerNavigation();
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
            fill: root.selected ? 1 : 0
            color: (root.selected && root.focusedSelection) ? "#FFFFFF" : (root.selected ? Theme.accent : (root.enabled ? Theme.textSecondary : Theme.textDisabled))
        }

        Text {
            id: rowTitleText
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: root.title
            font: Typography.body
            color: (root.selected && root.focusedSelection) ? "#FFFFFF" : (root.enabled ? Theme.textPrimary : Theme.textDisabled)
            elide: Text.ElideRight
        }

        Rectangle {
            visible: root.badgeText !== ""
            Layout.maximumWidth: 56
            implicitWidth: Math.min(56, badgeLabel.implicitWidth + Spacing.xs * 2)
            implicitHeight: Math.max(18, badgeLabel.implicitHeight + 2)
            radius: 9
            color: (root.selected && root.focusedSelection) ? Qt.rgba(1, 1, 1, 0.25) : Theme.controlFill

            Text {
                id: badgeLabel
                anchors.centerIn: parent
                width: Math.min(implicitWidth, 44)
                text: root.badgeText
                font: Typography.subheadlineTnum
                color: (root.selected && root.focusedSelection) ? "#FFFFFF" : Theme.textSecondary
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    ToolTip {
        visible: hoverHandler.hovered && rowTitleText.truncated && root.title !== ""
        text: root.title
        delay: 400
    }
}
