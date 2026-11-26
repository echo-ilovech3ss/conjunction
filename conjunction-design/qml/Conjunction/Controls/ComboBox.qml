import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.ComboBox {
    id: control

    // SPEC §2.3 PopUpButton/ComboBox height: mini 16, small 21, regular 24, large 28
    property string sizeClass: "regular"

    onPressedChanged: if (pressed) FocusModel.markPointerNavigation()

    implicitWidth: Math.max(140, contentItem.implicitWidth + Spacing.lg * 2)
    implicitHeight: Geometry.popUpHeight(sizeClass)

    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.ComboBox
    Accessible.name: currentText
    Accessible.focusable: true

    background: SquircleRect {
        id: bg
        radius: Geometry.radiusTextField
        color: control.enabled ? (control.down ? Theme.controlFillPressed : Theme.controlBackgroundColor) : Theme.controlFill
        borderColor: Appearance.shouldIncreaseContrast ? Theme.highContrastBorderColor : (control.activeFocus ? Theme.accent : Theme.separator)
        borderWidth: Geometry.separatorThickness

        Icon {
            anchors.right: parent.right
            anchors.rightMargin: Spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron-down"
            size: 14
            color: control.enabled ? Theme.textSecondary : Theme.textDisabled
        }

        FocusRing {
            target: bg
            isTextInput: false
        }
    }

    contentItem: Text {
        text: control.displayText
        font: (control.sizeClass === "small") ? Typography.subheadline : Typography.body
        color: control.enabled ? Theme.textPrimary : Theme.textDisabled
        verticalAlignment: Text.AlignVCenter
        leftPadding: Spacing.sm
        rightPadding: Spacing.lg
        elide: Text.ElideRight
    }

    popup: T.Popup {
        y: control.height + Spacing.xs
        width: control.width
        implicitHeight: Math.min(220, contentItem.implicitHeight + Spacing.xs * 2)
        padding: Spacing.xs

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
        }

        background: Surface {
            elevation: "popover"
            radius: Geometry.radiusMenu
        }
    }

    delegate: Item {
        width: control.width - Spacing.xs * 2
        height: 24
        property bool highlighted: control.highlightedIndex === index

        Rectangle {
            anchors.fill: parent
            radius: Geometry.radiusMenuItem
            color: highlighted ? Theme.selection : (hoverHandler.hovered ? Theme.controlFillHover : "transparent")

            HoverHandler { id: hoverHandler }
            TapHandler {
                onTapped: {
                    FocusModel.markPointerNavigation();
                    control.currentIndex = index;
                    control.popup.close();
                }
            }

            Text {
                anchors.fill: parent
                anchors.leftMargin: Spacing.sm
                anchors.rightMargin: Spacing.sm
                text: (typeof modelData === "string") ? modelData : (model.text || "")
                font: Typography.body
                color: highlighted ? Theme.selectionText : Theme.textPrimary
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
    }
}
