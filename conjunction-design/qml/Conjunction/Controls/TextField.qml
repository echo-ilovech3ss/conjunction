import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.TextField {
    id: control

    // SPEC §2.3 TextField height: mini 16, small 19, regular 24, large 28, extraLarge 36
    property string sizeClass: "regular"
    property string leadingIcon: ""
    property bool showClearButton: false
    property bool isError: false

    implicitWidth: 200
    implicitHeight: Geometry.textFieldHeight(sizeClass)

    font: (sizeClass === "mini") ? Typography.miniControl : ((sizeClass === "small") ? Typography.subheadline : Typography.body)
    color: enabled ? Theme.textPrimary : Theme.textDisabled
    selectionColor: Theme.selection
    selectedTextColor: Theme.selectionText
    placeholderTextColor: Theme.textSecondary
    verticalAlignment: Text.AlignVCenter

    leftPadding: leadingIcon !== "" ? 28 : Spacing.sm
    rightPadding: (showClearButton && control.text !== "") ? 26 : Spacing.sm

    Accessible.role: Accessible.EditableText
    Accessible.name: placeholderText || text
    Accessible.focusable: true

    background: SquircleRect {
        id: bg
        radius: Geometry.radiusTextField
        color: control.enabled ? Theme.controlBackgroundColor : Theme.controlFill
        borderColor: {
            if (control.isError) return Theme.destructive;
            if (Appearance.shouldIncreaseContrast) return Theme.highContrastBorderColor;
            if (control.activeFocus) return Theme.accent;
            return Theme.separator;
        }
        borderWidth: Geometry.separatorThickness

        Icon {
            visible: control.leadingIcon !== ""
            name: control.leadingIcon
            size: 14
            color: Theme.textSecondary
            anchors.left: parent.left
            anchors.leftMargin: Spacing.sm
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            id: clearBtn
            visible: control.showClearButton && control.text !== ""
            width: 16
            height: 16
            radius: 8
            color: clearHover.hovered ? Theme.separator : "transparent"
            anchors.right: parent.right
            anchors.rightMargin: Spacing.xs
            anchors.verticalCenter: parent.verticalCenter

            Icon {
                name: "close"
                size: 11
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
            target: bg
            isTextInput: true
        }
    }
}
