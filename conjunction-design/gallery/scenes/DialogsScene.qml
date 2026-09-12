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
            text: "Dialogs, Sheets & Alerts"
            font: Typography.windowTitle
            color: Theme.textPrimary
        }

        Text {
            text: "Sheets slide down from the parent window top context. Standard modal dialogs center with backdrop dimming. Return activates default action; Escape cancels."
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
                id: openDialogBtn
                text: "Open Modal Dialog"
                onClicked: sampleDialog.open()
            }

            Button {
                id: openSheetBtn
                text: "Open Document Sheet"
                isDefault: true
                onClicked: sampleSheet.open()
            }

            Button {
                id: openAlertBtn
                text: "Open Destructive Alert"
                isDestructive: true
                onClicked: sampleAlert.open()
            }
        }

        Dialog {
            id: sampleDialog
            invokerItem: openDialogBtn
            titleText: "Save Configuration"
            messageText: "Do you want to write the active Conjunction desktop settings to ~/.config/conjunction/settings.json?"
            defaultButtonText: "Save"
            cancelButtonText: "Don't Save"
        }

        Sheet {
            id: sampleSheet
            invokerItem: openSheetBtn
            titleText: "Package Installation Sheet"
            messageText: "The package org.mozilla.firefox requires elevated confirmation through systemd-polkit before installation begins."
            defaultButtonText: "Proceed"
            cancelButtonText: "Abort"
        }

        Alert {
            id: sampleAlert
            invokerItem: openAlertBtn
            alertType: "destructive"
            titleText: "Remove Application?"
            messageText: "Are you sure you want to permanently remove dev.conjunction.terminal from this workstation?"
        }

        Item { Layout.fillHeight: true }
    }
}
