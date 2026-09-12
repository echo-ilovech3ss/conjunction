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
        if (conjunctionAction) conjunctionAction.trigger();
    }

    implicitWidth: 180
    implicitHeight: Geometry.controlHeightSmall

    activeFocusOnTab: true

    Accessible.role: Accessible.MenuItem
    Accessible.name: text
    Accessible.focusable: true

    background: Rectangle {
        radius: Geometry.radiusSmall - 1
        color: {
            if (!control.enabled) return "transparent";
            if (control.highlighted || control.down) {
                return control.isDestructive ? Theme.destructive : Theme.selection;
            }
            return "transparent";
        }
    }

    contentItem: RowLayout {
        spacing: Spacing.sm
        anchors.fill: parent
        anchors.leftMargin: Spacing.sm
        anchors.rightMargin: Spacing.sm

        Icon {
            visible: control.iconName !== ""
            name: control.iconName
            size: 14
            color: {
                if (!control.enabled) return Theme.textDisabled;
                if (control.highlighted) return control.isDestructive ? "#FFFFFF" : Theme.selectionText;
                return control.isDestructive ? Theme.destructive : Theme.textPrimary;
            }
        }

        Text {
            Layout.fillWidth: true
            text: control.text
            font: Typography.controlLabel
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
            text: control.shortcutText
            font: Typography.caption
            color: control.highlighted ? (control.isDestructive ? "#FFFFFF" : Theme.selectionText) : Theme.textSecondary
            verticalAlignment: Text.AlignVCenter
        }
    }
}
