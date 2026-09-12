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
            text: "Interactive Component States"
            font: Typography.windowTitle
            color: Theme.textPrimary
        }

        Rectangle {
            Layout.fillWidth: true
            height: Geometry.separatorThickness
            color: Theme.separator
        }

        ColumnLayout {
            spacing: Spacing.sm
            Layout.fillWidth: true

            component StatePreview: Rectangle {
                property string stateTitle: ""
                property color bgColor: Theme.surfaceSecondary
                property color txtColor: Theme.textPrimary
                property bool isFocused: false
                property bool hasBorder: true

                Layout.fillWidth: true
                height: Geometry.controlHeightMedium
                radius: Geometry.radiusMedium
                color: bgColor
                border.color: hasBorder ? Theme.separator : "transparent"
                border.width: Geometry.separatorThickness

                FocusRing {
                    active: isFocused
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Spacing.md
                    anchors.rightMargin: Spacing.md

                    Text {
                        text: stateTitle
                        font: Typography.controlLabel
                        color: txtColor
                    }
                }
            }

            StatePreview { stateTitle: "1. Normal / Idle State"; bgColor: Theme.surfaceSecondary; txtColor: Theme.textPrimary }
            StatePreview { stateTitle: "2. Hover State (Simulated)"; bgColor: Theme.accentHover; txtColor: Theme.accentText; hasBorder: false }
            StatePreview { stateTitle: "3. Pressed / Active State"; bgColor: Theme.accentPressed; txtColor: Theme.accentText; hasBorder: false }
            StatePreview { stateTitle: "4. Focused State (Keyboard)"; bgColor: Theme.surfaceSecondary; txtColor: Theme.textPrimary; isFocused: true }
            StatePreview { stateTitle: "5. Disabled State"; bgColor: Theme.surface; txtColor: Theme.textDisabled }
        }

        Item { Layout.fillHeight: true }
    }
}
