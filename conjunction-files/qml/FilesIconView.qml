import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Conjunction.Design 1.0
import Conjunction.Controls 1.0

Item {
    id: root

    property int selectedIndex: -1
    property var selectedItem: (selectedIndex >= 0 && selectedIndex < FilesModel.count) ? FilesModel.get(selectedIndex) : null

    signal openRequested(var item)
    signal getInfoRequested(var item)
    signal quickLookRequested(var item)
    signal showPackageContentsRequested(var item)

    GridView {
        id: grid
        anchors.fill: parent
        anchors.margins: 16
        cellWidth: 104
        cellHeight: 114
        model: FilesModel
        clip: true
        focus: true

        delegate: Rectangle {
            id: delegateRoot
            width: 96
            height: 106
            radius: 6

            property bool isSelected: (root.selectedIndex === index)
            property bool isHovered: mouseArea.containsMouse

            color: isSelected
                   ? (isDarkTheme ? "#2A4B7C" : "#CCE4FF")
                   : (isHovered ? (isDarkTheme ? "#262629" : "#EFEFEF") : "transparent")
            border.color: isSelected ? (isDarkTheme ? "#3880FF" : "#007AFF") : "transparent"
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 6
                width: parent.width - 8

                // Icon / Thumbnail
                Item {
                    width: 56
                    height: 56
                    anchors.horizontalCenter: parent.horizontalCenter

                    Image {
                        id: itemIcon
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        source: (model.bundleIcon && model.bundleIcon !== "")
                                ? ("file://" + model.bundleIcon)
                                : ("image://icon/" + model.iconName)
                        smooth: true
                    }

                    // App bundle badge indicator
                    Rectangle {
                        visible: model.isAppBundle
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        width: 14
                        height: 14
                        radius: 7
                        color: "#007AFF"
                        border.color: "#FFFFFF"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "A"
                            font.pixelSize: 8
                            font.bold: true
                            color: "#FFFFFF"
                        }
                    }
                }

                // Name label
                Text {
                    id: nameLabel
                    width: parent.width
                    text: model.name
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 2
                    elide: Text.ElideMiddle
                    color: isSelected
                           ? (isDarkTheme ? "#FFFFFF" : "#004085")
                           : (isDarkTheme ? "#E5E5EA" : "#1D1D1F")
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: (mouse) => {
                    root.selectedIndex = index;
                    grid.forceActiveFocus();
                    if (mouse.button === Qt.RightButton) {
                        contextMenu.popup();
                    }
                }

                onDoubleClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        var it = FilesModel.get(index);
                        root.openRequested(it);
                    }
                }
            }

            QQC2.Menu {
                id: contextMenu

                QQC2.MenuItem {
                    text: "Open"
                    onTriggered: {
                        var it = FilesModel.get(index);
                        root.openRequested(it);
                    }
                }

                QQC2.MenuItem {
                    text: "Show Package Contents"
                    visible: model.canShowPackageContents
                    onTriggered: {
                        var it = FilesModel.get(index);
                        root.showPackageContentsRequested(it);
                    }
                }

                QQC2.MenuSeparator {}

                QQC2.MenuItem {
                    text: "Quick Look"
                    onTriggered: {
                        var it = FilesModel.get(index);
                        root.quickLookRequested(it);
                    }
                }

                QQC2.MenuItem {
                    text: "Get Info"
                    onTriggered: {
                        var it = FilesModel.get(index);
                        root.getInfoRequested(it);
                    }
                }

                QQC2.MenuItem {
                    text: "Duplicate"
                    onTriggered: FileOps.duplicateItem(model.path)
                }

                QQC2.MenuSeparator {}

                QQC2.MenuItem {
                    text: "Move to Trash"
                    onTriggered: FileOps.moveToTrash([model.path])
                }
            }
        }
    }
}
