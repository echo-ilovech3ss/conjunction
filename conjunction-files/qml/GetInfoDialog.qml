import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Conjunction.Design 1.0
import Conjunction.Controls 1.0

Rectangle {
    id: root
    visible: false
    anchors.fill: parent
    color: "#70000000"

    property string targetPath: ""
    property var infoData: ({})

    function show(path) {
        targetPath = path;
        infoData = FileOps.getFileInfo(path);
        visible = true;
    }

    function hide() {
        visible = false;
        targetPath = "";
        infoData = ({});
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.hide()
    }

    Rectangle {
        id: card
        width: 340
        height: 460
        anchors.centerIn: parent
        radius: 10
        color: isDarkTheme ? "#242426" : "#F5F5F7"
        border.color: isDarkTheme ? "#3C3C3E" : "#D2D2D7"
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Header
            Rectangle {
                Layout.fillWidth: true
                height: 36
                color: isDarkTheme ? "#1E1E20" : "#EBEBF0"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12

                    Text {
                        Layout.fillWidth: true
                        text: (root.infoData.name || "") + " Info"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideMiddle
                        color: isDarkTheme ? "#FFFFFF" : "#1D1D1F"
                    }

                    Button {
                        text: "✕"
                        sizeClass: "compact"
                        implicitWidth: 24
                        onClicked: root.hide()
                    }
                }
            }

            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: card.width - 32
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    Item { height: 4 }

                    // Icon & Primary Details
                    RowLayout {
                        spacing: 12
                        Image {
                            width: 56
                            height: 56
                            fillMode: Image.PreserveAspectFit
                            source: (root.infoData.bundleIcon && root.infoData.bundleIcon !== "")
                                    ? ("file://" + root.infoData.bundleIcon)
                                    : (root.infoData.isDir ? "image://icon/folder" : "image://icon/text-x-generic")
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: root.infoData.name || ""
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                elide: Text.ElideMiddle
                                color: isDarkTheme ? "#FFFFFF" : "#1D1D1F"
                            }

                            Text {
                                text: root.infoData.sizeFormatted ? (root.infoData.sizeFormatted + " on disk") : ""
                                font.pixelSize: 11
                                color: isDarkTheme ? "#8E8E93" : "#86868B"
                            }

                            Text {
                                text: "Modified: " + (root.infoData.modified || "--")
                                font.pixelSize: 11
                                color: isDarkTheme ? "#8E8E93" : "#86868B"
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: isDarkTheme ? "#333336" : "#E5E5EA"
                    }

                    // General Section
                    Text {
                        text: "General:"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: isDarkTheme ? "#FFFFFF" : "#1D1D1F"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            Text { text: "Kind:"; font.pixelSize: 11; color: isDarkTheme ? "#8E8E93" : "#86868B"; Layout.preferredWidth: 60 }
                            Text { text: root.infoData.isAppBundle ? "Application" : (root.infoData.isDir ? "Folder" : (root.infoData.mimeType || "Document")); font.pixelSize: 11; color: isDarkTheme ? "#DDD" : "#333" }
                        }
                        RowLayout {
                            Text { text: "Where:"; font.pixelSize: 11; color: isDarkTheme ? "#8E8E93" : "#86868B"; Layout.preferredWidth: 60 }
                            Text { text: root.infoData.dir || ""; font.pixelSize: 11; color: isDarkTheme ? "#DDD" : "#333"; elide: Text.ElideMiddle; Layout.fillWidth: true }
                        }
                        RowLayout {
                            Text { text: "Created:"; font.pixelSize: 11; color: isDarkTheme ? "#8E8E93" : "#86868B"; Layout.preferredWidth: 60 }
                            Text { text: root.infoData.created || "--"; font.pixelSize: 11; color: isDarkTheme ? "#DDD" : "#333" }
                        }
                    }

                    // Application Section (if app bundle)
                    ColumnLayout {
                        visible: root.infoData.isAppBundle === true
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: isDarkTheme ? "#333336" : "#E5E5EA"
                        }

                        Text {
                            text: "Application Lifecycle:"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: isDarkTheme ? "#FFFFFF" : "#1D1D1F"
                        }

                        RowLayout {
                            Text { text: "Identifier:"; font.pixelSize: 11; color: isDarkTheme ? "#8E8E93" : "#86868B"; Layout.preferredWidth: 60 }
                            Text { text: root.infoData.bundleId || ""; font.pixelSize: 11; color: isDarkTheme ? "#DDD" : "#333" }
                        }

                        RowLayout {
                            spacing: 8
                            Button {
                                Layout.fillWidth: true
                                text: "Remove App"
                                sizeClass: "compact"
                                isDestructive: true
                                onClicked: {
                                    FileOps.removeApplication(root.targetPath, false);
                                    root.hide();
                                }
                            }

                            Button {
                                Layout.fillWidth: true
                                text: "Remove App & Data"
                                sizeClass: "compact"
                                isDestructive: true
                                onClicked: {
                                    FileOps.removeApplication(root.targetPath, true);
                                    root.hide();
                                }
                            }
                        }
                    }

                    Item { height: 8 }
                }
            }
        }
    }
}
