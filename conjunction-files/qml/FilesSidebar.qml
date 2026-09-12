import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Conjunction.Design 1.0
import Conjunction.Controls 1.0

Rectangle {
    id: root
    width: 200
    color: isDarkTheme ? "#19191B" : "#EBEBF0"

    signal locationSelected(string path)

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: isDarkTheme ? "#2A2A2D" : "#D2D2D7"
    }

    ListView {
        id: sidebarList
        anchors.fill: parent
        anchors.margins: 8
        model: SidebarModel
        spacing: 2
        clip: true

        section.property: "section"
        section.criteria: ViewSection.FullString
        section.delegate: Item {
            width: sidebarList.width
            height: 26

            Text {
                text: section.toUpperCase()
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: isDarkTheme ? "#8E8E93" : "#86868B"
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
            }
        }

        delegate: Rectangle {
            id: rowItem
            width: sidebarList.width
            height: 28
            radius: 5

            property bool isCurrent: (FilesModel.currentPath === model.path)
            property bool isHovered: mouseArea.containsMouse

            color: isCurrent
                   ? (isDarkTheme ? "#0058D0" : "#007AFF")
                   : (isHovered ? (isDarkTheme ? "#2C2C2E" : "#DCDCE0") : "transparent")

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                // Icon
                Image {
                    source: "image://icon/" + model.iconName
                    width: 16
                    height: 16
                    fillMode: Image.PreserveAspectFit
                    opacity: rowItem.isCurrent ? 1.0 : 0.85
                }

                Text {
                    Layout.fillWidth: true
                    text: model.name
                    font.pixelSize: 13
                    font.weight: rowItem.isCurrent ? Font.DemiBold : Font.Normal
                    color: rowItem.isCurrent ? "#FFFFFF" : (isDarkTheme ? "#FFFFFF" : "#1D1D1F")
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    FilesModel.setPath(model.path);
                    root.locationSelected(model.path);
                }
            }
        }
    }
}
