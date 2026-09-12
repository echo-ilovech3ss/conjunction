import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import Conjunction.Design

T.TextField {
    id: control

    signal searchSubmitted(string query)

    implicitWidth: 220
    implicitHeight: Geometry.controlHeightMedium

    placeholderText: "Search..."
    font: Typography.body
    color: enabled ? Theme.textPrimary : Theme.textDisabled
    selectionColor: Theme.selection
    selectedTextColor: Theme.selectionText
    placeholderTextColor: Theme.textSecondary
    verticalAlignment: Text.AlignVCenter

    leftPadding: 28 + Spacing.xs
    rightPadding: control.text !== "" ? 28 : Spacing.sm

    Accessible.role: Accessible.EditableText
    Accessible.name: "Search"
    Accessible.focusable: true

    background: Rectangle {
        id: bg
        radius: Geometry.radiusPill
        color: control.enabled ? Theme.surface : Theme.surfaceSecondary
        border.color: control.activeFocus ? Theme.accent : Theme.separator
        border.width: Geometry.separatorThickness

        Icon {
            name: "search"
            size: 16
            color: Theme.textSecondary
            anchors.left: parent.left
            anchors.leftMargin: Spacing.sm
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            id: clearBtn
            visible: control.text !== ""
            width: 18
            height: 18
            radius: 9
            color: clearHover.hovered ? Theme.separator : "transparent"
            anchors.right: parent.right
            anchors.rightMargin: Spacing.xs
            anchors.verticalCenter: parent.verticalCenter

            Icon {
                name: "close"
                size: 12
                color: Theme.textSecondary
                anchors.centerIn: parent
            }

            HoverHandler { id: clearHover }
            TapHandler {
                onTapped: {
                    control.clear();
                    control.forceActiveFocus();
                }
            }
        }

        FocusRing {
            active: control.activeFocus && FocusModel.keyboardNavigationActive
            target: bg
        }
    }

    Keys.onEscapePressed: function(event) {
        if (control.text !== "") {
            control.clear();
            event.accepted = true;
        }
    }

    Keys.onReturnPressed: function(event) {
        control.searchSubmitted(control.text);
        event.accepted = true;
    }
}
