import QtQuick
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls

Surface {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    property alias searchField: kSearch
    property alias segmentedCtrl: kSegmented
    property alias sidebarNav: kSidebar
    property alias menuButton: kMenuBtn
    property alias dialogButton: kDialogBtn
    property alias sampleMenu: kMenu
    property alias sampleDialog: kDialog

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Geometry.contentPadding
        spacing: Spacing.md

        Text {
            text: "Keyboard End-to-End Workflow Verification"
            font: Typography.windowTitle
            color: Theme.textPrimary
        }

        Text {
            text: "This scene is navigated exclusively via keyboard (Tab, Arrow keys, Enter, Escape) without mouse interaction."
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
            Text { text: "1. Search:"; font: Typography.controlLabel; color: Theme.textPrimary; Layout.preferredWidth: 100 }
            SearchField {
                id: kSearch
                objectName: "kSearch"
                placeholderText: "Type and clear via Escape..."
                Layout.fillWidth: true
            }
        }

        RowLayout {
            spacing: Spacing.md
            Text { text: "2. Segmented:"; font: Typography.controlLabel; color: Theme.textPrimary; Layout.preferredWidth: 100 }
            SegmentedControl {
                id: kSegmented
                objectName: "kSegmented"
                currentIndex: 0
                Segment { text: "Alpha" }
                Segment { text: "Beta" }
                Segment { text: "Gamma" }
            }
        }

        RowLayout {
            spacing: Spacing.md
            Text { text: "3. List Nav:"; font: Typography.controlLabel; color: Theme.textPrimary; Layout.preferredWidth: 100 }
            Sidebar {
                id: kSidebar
                objectName: "kSidebar"
                implicitHeight: 80
                Layout.fillWidth: true

                SidebarRow { title: "Item Row 1"; selected: true }
                SidebarRow { title: "Item Row 2" }
            }
        }

        RowLayout {
            spacing: Spacing.md
            Text { text: "4. Menu:"; font: Typography.controlLabel; color: Theme.textPrimary; Layout.preferredWidth: 100 }
            Button {
                id: kMenuBtn
                objectName: "kMenuBtn"
                text: "Open Keyboard Menu"
                onClicked: kMenu.popup(kMenuBtn, 0, kMenuBtn.height + Spacing.xs)
            }

            Menu {
                id: kMenu
                objectName: "kMenu"
                MenuItem { text: "Menu Option 1" }
                MenuItem { text: "Menu Option 2" }
            }
        }

        RowLayout {
            spacing: Spacing.md
            Text { text: "5. Dialog:"; font: Typography.controlLabel; color: Theme.textPrimary; Layout.preferredWidth: 100 }
            Button {
                id: kDialogBtn
                objectName: "kDialogBtn"
                text: "Open Keyboard Dialog"
                onClicked: kDialog.open()
            }

            Dialog {
                id: kDialog
                objectName: "kDialog"
                invokerItem: kDialogBtn
                titleText: "Keyboard Verification Dialog"
                messageText: "Press Enter or Escape to dismiss this dialog and restore focus."
                defaultButtonText: "Done"
            }
        }

        Item { Layout.fillHeight: true }
    }
}
