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

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Table Header
        Rectangle {
            Layout.fillWidth: true
            height: 26
            color: isDarkTheme ? "#222225" : "#E4E4E8"

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: isDarkTheme ? "#333336" : "#D1D1D6"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                // Name Column
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 320
                    height: parent.height
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        Text {
                            text: "Name"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: isDarkTheme ? "#A1A1A6" : "#6E6E73"
                        }
                        Text {
                            visible: FilesModel.sortRole === "name"
                            text: FilesModel.sortOrder === Qt.AscendingOrder ? "▲" : "▼"
                            font.pixelSize: 8
                            color: "#007AFF"
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var order = (FilesModel.sortRole === "name" && FilesModel.sortOrder === Qt.AscendingOrder)
                                        ? Qt.DescendingOrder : Qt.AscendingOrder;
                            FilesModel.setSort("name", order);
                        }
                    }
                }

                // Date Modified Column
                Rectangle {
                    Layout.preferredWidth: 150
                    height: parent.height
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        Text {
                            text: "Date Modified"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: isDarkTheme ? "#A1A1A6" : "#6E6E73"
                        }
                        Text {
                            visible: FilesModel.sortRole === "date"
                            text: FilesModel.sortOrder === Qt.AscendingOrder ? "▲" : "▼"
                            font.pixelSize: 8
                            color: "#007AFF"
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var order = (FilesModel.sortRole === "date" && FilesModel.sortOrder === Qt.AscendingOrder)
                                        ? Qt.DescendingOrder : Qt.AscendingOrder;
                            FilesModel.setSort("date", order);
                        }
                    }
                }

                // Size Column
                Rectangle {
                    Layout.preferredWidth: 90
                    height: parent.height
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        Text {
                            text: "Size"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: isDarkTheme ? "#A1A1A6" : "#6E6E73"
                        }
                        Text {
                            visible: FilesModel.sortRole === "size"
                            text: FilesModel.sortOrder === Qt.AscendingOrder ? "▲" : "▼"
                            font.pixelSize: 8
                            color: "#007AFF"
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var order = (FilesModel.sortRole === "size" && FilesModel.sortOrder === Qt.AscendingOrder)
                                        ? Qt.DescendingOrder : Qt.AscendingOrder;
                            FilesModel.setSort("size", order);
                        }
                    }
                }

                // Kind Column
                Rectangle {
                    Layout.preferredWidth: 140
                    height: parent.height
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        Text {
                            text: "Kind"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: isDarkTheme ? "#A1A1A6" : "#6E6E73"
                        }
                        Text {
                            visible: FilesModel.sortRole === "kind"
                            text: FilesModel.sortOrder === Qt.AscendingOrder ? "▲" : "▼"
                            font.pixelSize: 8
                            color: "#007AFF"
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var order = (FilesModel.sortRole === "kind" && FilesModel.sortOrder === Qt.AscendingOrder)
                                        ? Qt.DescendingOrder : Qt.AscendingOrder;
                            FilesModel.setSort("kind", order);
                        }
                    }
                }
            }
        }

        // Table Rows
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: FilesModel
            clip: true
            focus: true

            delegate: Rectangle {
                id: rowDelegate
                width: listView.width
                height: 28

                property bool isSelected: (root.selectedIndex === index)
                property bool isHovered: rowMouse.containsMouse

                color: isSelected
                       ? (isDarkTheme ? "#0058D0" : "#007AFF")
                       : (index % 2 === 1
                          ? (isDarkTheme ? "#1E1E20" : "#F7F7F8")
                          : (isDarkTheme ? "#19191B" : "#FFFFFF"))

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    // Name + Icon
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 320
                        spacing: 8

                        Image {
                            width: 16
                            height: 16
                            fillMode: Image.PreserveAspectFit
                            source: (model.bundleIcon && model.bundleIcon !== "")
                                    ? ("file://" + model.bundleIcon)
                                    : ("image://icon/" + model.iconName)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: model.name
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            color: rowDelegate.isSelected ? "#FFFFFF" : (isDarkTheme ? "#E5E5EA" : "#1D1D1F")
                        }
                    }

                    // Date Modified
                    Text {
                        Layout.preferredWidth: 150
                        text: model.modifiedFormatted
                        font.pixelSize: 11
                        color: rowDelegate.isSelected ? "#FFFFFF" : (isDarkTheme ? "#8E8E93" : "#6E6E73")
                    }

                    // Size
                    Text {
                        Layout.preferredWidth: 90
                        text: model.sizeFormatted
                        font.pixelSize: 11
                        color: rowDelegate.isSelected ? "#FFFFFF" : (isDarkTheme ? "#8E8E93" : "#6E6E73")
                    }

                    // Kind
                    Text {
                        Layout.preferredWidth: 140
                        text: model.isAppBundle ? "Application" : (model.isDir ? "Folder" : model.mimeType)
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        color: rowDelegate.isSelected ? "#FFFFFF" : (isDarkTheme ? "#8E8E93" : "#6E6E73")
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: (mouse) => {
                        root.selectedIndex = index;
                        listView.forceActiveFocus();
                        if (mouse.button === Qt.RightButton) {
                            listContextMenu.popup();
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
                    id: listContextMenu

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
}
