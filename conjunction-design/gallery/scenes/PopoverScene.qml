import QtQuick
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls

Surface {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Geometry.contentPadding
        spacing: Spacing.md

        Text {
            text: "Anchored Popovers"
            font: Typography.windowTitle
            color: Theme.textPrimary
        }

        Text {
            text: "Transient floating cards anchored to a target control. Dismissed automatically on Escape or clicking outside. Keyboard focus enters predictably and restores to the invoking control upon closing."
            font: Typography.secondaryBody
            color: Theme.textSecondary
        }

        Rectangle {
            Layout.fillWidth: true
            height: Geometry.separatorThickness
            color: Theme.separator
        }

        RowLayout {
            spacing: Spacing.md

            Button {
                id: triggerBtn
                text: "Open Popover Card"
                iconName: "settings"
                onClicked: samplePopover.open()
            }

            Popover {
                id: samplePopover
                x: triggerBtn.x
                y: triggerBtn.y + triggerBtn.height + Spacing.xs
                invokerItem: triggerBtn
                implicitWidth: 260
                implicitHeight: 180

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Spacing.sm

                    Text {
                        text: "Display Options"
                        font: Typography.sectionHeading
                        color: Theme.textPrimary
                    }

                    CheckBox { text: "Show Hidden Applications"; checked: true }
                    CheckBox { text: "Enable Hardware Decoding"; checked: false }

                    Rectangle {
                        Layout.fillWidth: true
                        height: Geometry.separatorThickness
                        color: Theme.separator
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        Button {
                            text: "Close"
                            isDefault: true
                            onClicked: samplePopover.close()
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
