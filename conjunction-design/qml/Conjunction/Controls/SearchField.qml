import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.TextField {
    id: control

    // SPEC §2.3 SearchField height: mini 16, small 19, regular 24, large 28, extraLarge 36
    property string sizeClass: "regular"
    signal searchSubmitted(string query)

    implicitWidth: 220
    implicitHeight: Geometry.textFieldHeight(sizeClass)

    placeholderText: "Search"
    font: (sizeClass === "mini") ? Typography.miniControl : ((sizeClass === "small") ? Typography.subheadline : ((sizeClass === "extraLarge") ? Typography.title3 : Typography.body))
    color: enabled ? Theme.textPrimary : Theme.textDisabled
    selectionColor: Theme.selection
    selectedTextColor: Theme.selectionText
    placeholderTextColor: Theme.textSecondary
    verticalAlignment: Text.AlignVCenter

    leftPadding: (sizeClass === "extraLarge") ? 36 : 28
    rightPadding: control.text !== "" ? 28 : Spacing.sm

    Accessible.role: Accessible.EditableText
    Accessible.name: "Search"
    Accessible.focusable: true

    background: Rectangle {
        id: bg
        radius: height * 0.5
        color: control.enabled ? Theme.controlFill : Theme.surfaceSecondary
        border.color: Appearance.shouldIncreaseContrast ? Theme.highContrastBorderColor : (control.activeFocus ? Theme.accent : Theme.separator)
        border.width: Geometry.separatorThickness

        Icon {
            name: "search"
            size: (control.sizeClass === "extraLarge") ? 18 : 14
            color: Theme.textSecondary
            anchors.left: parent.left
            anchors.leftMargin: (control.sizeClass === "extraLarge") ? 12 : Spacing.sm
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            id: clearBtn
            visible: control.text !== ""
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
