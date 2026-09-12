import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Conjunction.Design 1.0
import Conjunction.Controls 1.0
import Conjunction.Files 1.0

Item {
    id: root

    signal openRequested(var item)
    signal getInfoRequested(var item)
    signal quickLookRequested(var item)

    QQC2.ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AlwaysOff
        QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AsNeeded

        Row {
            id: columnsRow
            height: scroll.height
            spacing: 0

            // Column instances for each directory level
            Repeater {
                model: ColumnModel.columnPaths

                delegate: Rectangle {
                    id: colRect
                    width: 220
                    height: columnsRow.height
                    color: isDarkTheme ? "#1C1C1E" : "#FFFFFF"

                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 1
                        color: isDarkTheme ? "#2C2C2E" : "#E5E5EA"
                    }

                    FilesModel {
                        id: colModel
                        currentPath: modelData
                    }

                    ListView {
                        id: colListView
                        anchors.fill: parent
                        anchors.margins: 4
                        model: colModel
                        clip: true

                        delegate: Rectangle {
                            id: colItemDelegate
                            width: colListView.width
                            height: 26
                            radius: 4

                            property bool isSelected: (colListView.currentIndex === index)
                            property bool isHovered: mouseArea.containsMouse

                            color: isSelected
                                   ? (isDarkTheme ? "#0058D0" : "#007AFF")
                                   : (isHovered ? (isDarkTheme ? "#2C2C2E" : "#EFEFEF") : "transparent")

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 6

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
                                    color: colItemDelegate.isSelected ? "#FFFFFF" : (isDarkTheme ? "#E5E5EA" : "#1D1D1F")
                                }

                                Text {
                                    visible: model.isDir && !model.isAppBundle
                                    text: "›"
                                    font.pixelSize: 14
                                    color: colItemDelegate.isSelected ? "#FFFFFF" : (isDarkTheme ? "#8E8E93" : "#C7C7CC")
                                }
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true

                                onClicked: {
                                    colListView.currentIndex = index;
                                    ColumnModel.selectItem(colRect.index, model.path, model.isDir, model.isAppBundle);
                                }

                                onDoubleClicked: {
                                    var it = colModel.get(index);
                                    root.openRequested(it);
                                }
                            }
                        }
                    }
                }
            }

            // Preview Column when a file is selected
            Rectangle {
                visible: ColumnModel.hasPreview
                width: 260
                height: columnsRow.height
                color: isDarkTheme ? "#161618" : "#F7F7F8"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    // Large Thumbnail
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 128
                        Layout.preferredHeight: 128
                        radius: 8
                        color: isDarkTheme ? "#222225" : "#EBEBF0"

                        Image {
                            anchors.fill: parent
                            anchors.margins: 12
                            fillMode: Image.PreserveAspectFit
                            source: {
                                var p = ColumnModel.previewData;
                                if (p.bundleIcon && p.bundleIcon !== "") return "file://" + p.bundleIcon;
                                if (p.mimeType && p.mimeType.indexOf("image/") === 0) return "file://" + ColumnModel.previewPath;
                                return "image://icon/" + (p.iconName || "text-x-generic");
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: ColumnModel.previewData.name || ""
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        elide: Text.ElideMiddle
                        color: isDarkTheme ? "#FFFFFF" : "#1D1D1F"
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: ColumnModel.previewData.sizeFormatted ? (ColumnModel.previewData.sizeFormatted + " — " + (ColumnModel.previewData.mimeType || "")) : ""
                        font.pixelSize: 11
                        color: isDarkTheme ? "#8E8E93" : "#86868B"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: isDarkTheme ? "#2C2C2E" : "#E5E5EA"
                    }

                    // Metadata details
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            Text { text: "Modified:"; font.pixelSize: 11; color: isDarkTheme ? "#8E8E93" : "#86868B"; Layout.preferredWidth: 60 }
                            Text { text: ColumnModel.previewData.modifiedFormatted || "--"; font.pixelSize: 11; color: isDarkTheme ? "#DDD" : "#333" }
                        }
                        RowLayout {
                            visible: ColumnModel.previewData.bundleId !== undefined && ColumnModel.previewData.bundleId !== ""
                            Text { text: "Bundle ID:"; font.pixelSize: 11; color: isDarkTheme ? "#8E8E93" : "#86868B"; Layout.preferredWidth: 60 }
                            Text { text: ColumnModel.previewData.bundleId || ""; font.pixelSize: 11; color: isDarkTheme ? "#DDD" : "#333"; elide: Text.ElideRight }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Button {
                        Layout.fillWidth: true
                        text: "Quick Look"
                        iconName: "system-search"
                        onClicked: {
                            var it = ColumnModel.previewData;
                            root.quickLookRequested(it);
                        }
                    }

                    Button {
                        Layout.fillWidth: true
                        text: "Open"
                        onClicked: FileOps.openItem(ColumnModel.previewPath)
                    }
                }
            }
        }
    }
}
