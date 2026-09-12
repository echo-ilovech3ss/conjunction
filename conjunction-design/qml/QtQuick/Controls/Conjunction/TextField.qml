import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import Conjunction.Design

T.TextField {
    id: control

    property string leadingIcon: ""
    property bool showClearButton: false
    property bool isError: false

    implicitWidth: 200
    implicitHeight: Geometry.controlHeightMedium

    font: Typography.body
    color: enabled ? Theme.textPrimary : Theme.textDisabled
    selectionColor: Theme.selection
    selectedTextColor: Theme.selectionText
    placeholderTextColor: Theme.textSecondary
    verticalAlignment: Text.AlignVCenter

    leftPadding: leadingIcon !== "" ? (28 + Spacing.xs) : Spacing.sm
    rightPadding: (showClearButton && control.text !== "") ? 28 : Spacing.sm

    Accessible.role: Accessible.EditableText
    Accessible.name: placeholderText || text
    Accessible.focusable: true

    background: Rectangle {
        id: bg
        radius: Geometry.radiusSmall
        color: control.enabled ? Theme.surface : Theme.surfaceSecondary
        border.color: control.isError ? Theme.destructive : (control.activeFocus ? Theme.accent : Theme.separator)
        border.width: Geometry.separatorThickness

        Icon {
            visible: control.leadingIcon !== ""
            name: control.leadingIcon
            size: 16
            color: Theme.textSecondary
            anchors.left: parent.left
            anchors.leftMargin: Spacing.sm
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            id: clearBtn
            visible: control.showClearButton && control.text !== ""
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
}
