import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Conjunction.Design 1.0
import Conjunction.Controls 1.0

Rectangle {
    id: root
    height: 48
    color: isDarkTheme ? "#202022" : "#ECECEC"

    property int currentViewIndex: 0 // 0: Icon, 1: List, 2: Column
    signal viewModeChanged(int mode)
    signal newFolderRequested()
    signal getInfoRequested()
    signal actionRequested(string action)

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: isDarkTheme ? "#2F2F32" : "#D4D4D4"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        // Back / Forward navigation
        RowLayout {
            spacing: 2

            Button {
                id: backBtn
                iconName: "go-previous"
                sizeClass: "compact"
                enabled: FilesModel.canGoBack
                onClicked: FilesModel.goBack()
                implicitWidth: 28
                implicitHeight: 28
            }

            Button {
                id: fwdBtn
                iconName: "go-next"
                sizeClass: "compact"
                enabled: FilesModel.canGoForward
                onClicked: FilesModel.goForward()
                implicitWidth: 28
                implicitHeight: 28
            }
        }

        // Breadcrumb Path Navigation Bar
        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.maximumHeight: 32
            contentHeight: 32
            clip: true
            QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

            Row {
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: FilesModel.pathComponents
                    delegate: Row {
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            height: 24
                            width: segText.implicitWidth + 12
                            radius: 4
                            color: segMouse.containsMouse ? (isDarkTheme ? "#333336" : "#DDD") : "transparent"

                            Text {
                                id: segText
                                anchors.centerIn: parent
                                text: modelData.name
                                font.pixelSize: 12
                                font.weight: (index === FilesModel.pathComponents.length - 1) ? Font.DemiBold : Font.Normal
                                color: isDarkTheme ? "#F0F0F0" : "#1D1D1F"
                            }

                            MouseArea {
                                id: segMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: FilesModel.setPath(modelData.path)
                            }
                        }

                        Text {
                            visible: index < FilesModel.pathComponents.length - 1
                            text: "›"
                            font.pixelSize: 14
                            color: isDarkTheme ? "#666" : "#999"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        // View Mode Switcher
        SegmentedControl {
            id: viewSwitcher
            currentIndex: root.currentViewIndex
            onCurrentIndexChanged: {
                if (root.currentViewIndex !== currentIndex) {
                    root.currentViewIndex = currentIndex;
                    root.viewModeChanged(currentIndex);
                }
            }

            Segment { text: "Icons" }
            Segment { text: "List" }
            Segment { text: "Columns" }
        }

        // Actions
        ToolButton {
            iconName: "folder-new"
            tooltipText: "New Folder"
            onClicked: root.newFolderRequested()
            implicitWidth: 30
            implicitHeight: 28
        }

        ToolButton {
            iconName: "document-properties"
            tooltipText: "Get Info (Ctrl+I)"
            onClicked: root.getInfoRequested()
            implicitWidth: 30
            implicitHeight: 28
        }

        // In-folder search
        SearchField {
            id: searchField
            placeholderText: "Search"
            Layout.preferredWidth: 160
            Layout.preferredHeight: 28
            text: FilesModel.searchFilter
            onTextChanged: FilesModel.searchFilter = text
        }
    }
}
