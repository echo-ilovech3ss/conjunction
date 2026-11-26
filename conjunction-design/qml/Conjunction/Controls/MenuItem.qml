import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import Conjunction.Design

T.MenuItem {
    id: control

    property string iconName: ""
    property string shortcutText: ""
    property bool isDestructive: false
    property Action conjunctionAction: null

    onConjunctionActionChanged: {
        if (conjunctionAction) {
            text = Qt.binding(function() { return conjunctionAction.text; });
            iconName = Qt.binding(function() { return conjunctionAction.iconName; });
            shortcutText = Qt.binding(function() { return conjunctionAction.shortcut; });
            enabled = Qt.binding(function() { return conjunctionAction.enabled; });
            isDestructive = (conjunctionAction.role === "destructive");
        }
    }
    onTriggered: {
        FocusModel.markPointerNavigation();
        if (conjunctionAction) conjunctionAction.trigger();
    }

    implicitWidth: Math.min(344, Math.max(200, itemRow.implicitWidth + Spacing.sm * 2))
    implicitHeight: Math.max(24, itemRow.implicitHeight + 6)

    activeFocusOnTab: true

    Accessible.role: Accessible.MenuItem
    Accessible.name: text
    Accessible.focusable: true

    // Concentric radius: menu cr=12 - 4pt padding = 8pt (SPEC §2.1)
    background: Rectangle {
        radius: Geometry.radiusMenuItem
        color: {
            if (!control.enabled) return "transparent";
            if (control.highlighted || control.down) {
                return control.isDestructive ? Theme.destructive : Theme.selection;
            }
            return "transparent";
        }
    }

    contentItem: RowLayout {
        id: itemRow
        spacing: Spacing.sm
        anchors.fill: parent
        anchors.leftMargin: Spacing.sm
        anchors.rightMargin: Spacing.sm

        Icon {
            visible: control.iconName !== ""
            name: control.iconName
            size: 14
            Layout.preferredWidth: size
            Layout.preferredHeight: size
            color: {
                if (!control.enabled) return Theme.textDisabled;
                if (control.highlighted) return control.isDestructive ? "#FFFFFF" : Theme.selectionText;
                return control.isDestructive ? Theme.destructive : Theme.textPrimary;
            }
        }

        Text {
            id: menuItemText
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: control.text
            font: Typography.body
            color: {
                if (!control.enabled) return Theme.textDisabled;
                if (control.highlighted) return control.isDestructive ? "#FFFFFF" : Theme.selectionText;
                return control.isDestructive ? Theme.destructive : Theme.textPrimary;
            }
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            visible: control.shortcutText !== ""
            Layout.maximumWidth: 96
            text: control.shortcutText
            font: Typography.subheadline
            color: control.highlighted ? (control.isDestructive ? "#FFFFFF" : Theme.selectionText) : Theme.textSecondary
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }

    ToolTip {
        visible: control.hovered && menuItemText.truncated && control.text !== ""
        text: control.text
        delay: 400
    }
}
