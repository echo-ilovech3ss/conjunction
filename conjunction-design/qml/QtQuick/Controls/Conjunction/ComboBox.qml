import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import Conjunction.Design

T.ComboBox {
    id: control

    implicitWidth: Math.max(140, contentItem.implicitWidth + Spacing.lg * 2)
    implicitHeight: Geometry.controlHeightMedium

    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.ComboBox
    Accessible.name: currentText
    Accessible.focusable: true

    background: Rectangle {
        id: bg
        radius: Geometry.radiusSmall
        color: control.enabled ? (control.down ? Theme.surfaceSecondary : Theme.surface) : Theme.surfaceSecondary
        border.color: control.activeFocus ? Theme.accent : Theme.separator
        border.width: Geometry.separatorThickness

        ColumnLayout {
            anchors.right: parent.right
            anchors.rightMargin: Spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                text: "?"
                font.pixelSize: 8
                color: control.enabled ? Theme.textSecondary : Theme.textDisabled
            }
            Text {
                text: "?"
                font.pixelSize: 8
                color: control.enabled ? Theme.textSecondary : Theme.textDisabled
            }
        }

        FocusRing {
            active: control.activeFocus && FocusModel.keyboardNavigationActive
            target: bg
        }
    }

    contentItem: Text {
        text: control.displayText
        font: Typography.controlLabel
        color: control.enabled ? Theme.textPrimary : Theme.textDisabled
        verticalAlignment: Text.AlignVCenter
        leftPadding: Spacing.sm
        rightPadding: Spacing.lg
        elide: Text.ElideRight
    }

    popup: T.Popup {
        y: control.height + Spacing.xxs
        width: control.width
        implicitHeight: Math.min(200, contentItem.implicitHeight + Spacing.xs * 2)
        padding: Spacing.xs

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
        }

        background: Surface {
            elevation: "popover"
        }
    }

    delegate: Item {
        width: control.width - Spacing.xs * 2
        height: Geometry.controlHeightSmall
        property bool highlighted: control.highlightedIndex === index

        Rectangle {
            anchors.fill: parent
            radius: Geometry.radiusSmall - 1
            color: highlighted ? Theme.selection : (hoverHandler.hovered ? Theme.surfaceSecondary : "transparent")

            HoverHandler { id: hoverHandler }
            TapHandler {
                onTapped: {
                    control.currentIndex = index;
                    control.popup.close();
                }
            }

            Text {
                anchors.fill: parent
                anchors.leftMargin: Spacing.sm
                text: (typeof modelData === "string") ? modelData : (model.text || "")
                font: Typography.body
                color: highlighted ? Theme.selectionText : Theme.textPrimary
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
    }
}
