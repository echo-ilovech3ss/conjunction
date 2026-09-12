import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Surface {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Geometry.contentPadding
        spacing: Spacing.md

        Text {
            text: "Keyboard Focus & Focus Indicators"
            font: Typography.windowTitle
            color: Theme.textPrimary
        }

        Text {
            text: "Use Tab / Shift-Tab to navigate between focus targets. The focus ring is clearly distinct from hover and selection."
            font: Typography.secondaryBody
            color: Theme.textSecondary
        }

        Rectangle {
            Layout.fillWidth: true
            height: Geometry.separatorThickness
            color: Theme.separator
        }

        ColumnLayout {
            spacing: Spacing.md
            Layout.fillWidth: true

            component FocusItem: Rectangle {
                id: fItem
                property string label: ""
                property int itemIndex: 0
                objectName: "focusTarget_" + itemIndex

                Layout.fillWidth: true
                height: Geometry.controlHeightMedium
                radius: Geometry.radiusMedium
                color: activeFocus ? (Theme.isDark ? "#2D3748" : "#EDF2F7") : Theme.surfaceSecondary
                border.color: Theme.separator
                border.width: Geometry.separatorThickness

                activeFocusOnTab: true

                FocusRing {
                    id: ring
                    target: fItem
                    active: fItem.activeFocus
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Spacing.md
                    anchors.rightMargin: Spacing.md

                    Text {
                        text: fItem.label
                        font: Typography.controlLabel
                        color: Theme.textPrimary
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: fItem.activeFocus ? "[FOCUSED]" : "[Tab Target " + fItem.itemIndex + "]"
                        font: Typography.caption
                        color: fItem.activeFocus ? Theme.accent : Theme.textSecondary
                    }
                }

                Keys.onReturnPressed: {
                    console.log("Activated " + label);
                }
            }

            FocusItem { label: "Focusable Action Alpha"; itemIndex: 1; focus: true }
            FocusItem { label: "Focusable Action Beta"; itemIndex: 2 }
            FocusItem { label: "Focusable Action Gamma"; itemIndex: 3 }
            FocusItem { label: "Focusable Action Delta"; itemIndex: 4 }
        }

        Item { Layout.fillHeight: true }
    }
}
