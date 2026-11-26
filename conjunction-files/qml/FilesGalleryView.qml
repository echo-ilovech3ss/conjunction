import QtQuick
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls as C

// SPEC §4.7 Gallery View (Cmd+4): large centered hero preview over bottom thumbnail strip
Item {
    id: root
    property int currentIndex: 0
    property var selectedItem: (FilesModel.count > 0 && currentIndex >= 0 && currentIndex < FilesModel.count)
        ? FilesModel.get(currentIndex) : null

    signal openRequested(var item)
    signal getInfoRequested(var item)
    signal quickLookRequested(var item)

    Rectangle {
        anchors.fill: parent
        color: isDarkTheme ? "#1E1E1E" : "#FFFFFF"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

        // Hero Preview Area
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 40, 420)
                height: Math.min(parent.height - 20, 320)
                radius: 16
                color: isDarkTheme ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.03)
                border.width: 1
                border.color: Theme.separatorColor

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 36
                    spacing: 12

                    Image {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 112
                        Layout.preferredHeight: 112
                        sourceSize: Qt.size(128, 128)
                        source: root.selectedItem ? ("image://icon/" + (root.selectedItem.iconName || "text-x-generic")) : ""
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        text: root.selectedItem ? root.selectedItem.name : "Empty Folder"
                        color: Theme.labelColor
                        font: Typography.title2Bold
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: root.selectedItem
                            ? ((root.selectedItem.isAppBundle ? "Application Bundle" : (root.selectedItem.mimeType || ""))
                               + " • " + (root.selectedItem.sizeFormatted || ""))
                            : ""
                        color: Theme.secondaryLabelColor
                        font: Typography.callout
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onDoubleClicked: if (root.selectedItem) root.openRequested(root.selectedItem)
                }
            }
        }

        // Bottom Thumbnail Strip (64 pt)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 74
            radius: 12
            color: isDarkTheme ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(0, 0, 0, 0.03)
            border.width: 1
            border.color: Theme.separatorColor

            ListView {
                id: strip
                anchors.fill: parent
                anchors.margins: 8
                orientation: ListView.Horizontal
                spacing: 8
                clip: true
                model: FilesModel
                currentIndex: root.currentIndex

                delegate: Item {
                    width: 58; height: 58
                    readonly property bool active: index === root.currentIndex
                    Rectangle {
                        anchors.fill: parent; radius: 10
                        color: active ? Theme.systemBlue : (isDarkTheme ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.05))
                    }
                    Image {
                        anchors.centerIn: parent
                        width: 40; height: 40
                        source: "image://icon/" + model.iconName
                        fillMode: Image.PreserveAspectFit
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.currentIndex = index
                        onDoubleClicked: root.openRequested(FilesModel.get(index))
                    }
                }
            }
        }
    }
}
