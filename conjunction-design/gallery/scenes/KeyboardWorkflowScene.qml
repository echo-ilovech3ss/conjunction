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

    Flickable {
        anchors.fill: parent
        anchors.margins: Geometry.contentPadding
        clip: true
        contentWidth: width
        contentHeight: kwCol.implicitHeight

        ColumnLayout {
            id: kwCol
            width: parent.width
            spacing: Spacing.md

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Keyboard End-to-End Workflow Verification"
                font: Typography.windowTitle
                color: Theme.textPrimary
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "This scene is navigated exclusively via keyboard (Tab, Arrow keys, Enter, Escape) without mouse interaction."
                font: Typography.secondaryBody
                color: Theme.textSecondary
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                height: Geometry.separatorThickness
                color: Theme.separator
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Spacing.md
                Text { text: "1. Search:"; font: Typography.controlLabel; color: Theme.textPrimary; Layout.preferredWidth: 88; elide: Text.ElideRight }
                SearchField {
                    id: kSearch
                    objectName: "kSearch"
                    placeholderText: "Type and clear via Escape..."
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Spacing.md
                Text { text: "2. Segmented:"; font: Typography.controlLabel; color: Theme.textPrimary; Layout.preferredWidth: 88; elide: Text.ElideRight }
                SegmentedControl {
                    id: kSegmented
                    objectName: "kSegmented"
                    Layout.fillWidth: true
                    Layout.maximumWidth: 260
                    currentIndex: 0
                    Segment { text: "Alpha" }
                    Segment { text: "Beta" }
                    Segment { text: "Gamma" }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Spacing.md
                Text { text: "3. List Nav:"; font: Typography.controlLabel; color: Theme.textPrimary; Layout.preferredWidth: 88; elide: Text.ElideRight }
                Sidebar {
                    id: kSidebar
                    objectName: "kSidebar"
                    implicitHeight: 80
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0

                    SidebarRow { title: "Item Row 1"; selected: true }
                    SidebarRow { title: "Item Row 2" }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Spacing.md
                Text { text: "4. Menu:"; font: Typography.controlLabel; color: Theme.textPrimary; Layout.preferredWidth: 88; elide: Text.ElideRight }
                Button {
                    id: kMenuBtn
                    objectName: "kMenuBtn"
                    text: "Open Keyboard Menu"
                    Layout.fillWidth: true
                    Layout.maximumWidth: 200
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
                Layout.fillWidth: true
                spacing: Spacing.md
                Text { text: "5. Dialog:"; font: Typography.controlLabel; color: Theme.textPrimary; Layout.preferredWidth: 88; elide: Text.ElideRight }
                Button {
                    id: kDialogBtn
                    objectName: "kDialogBtn"
                    text: "Open Keyboard Dialog"
                    Layout.fillWidth: true
                    Layout.maximumWidth: 200
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
        }
    }
}
