import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Conjunction.Design 1.0
import Conjunction.Controls 1.0

Rectangle {
    id: root
    visible: false
    anchors.fill: parent
    color: "#80000000"

    property string targetPath: ""
    property var previewData: ({})

    function show(path) {
        targetPath = path;
        previewData = QuickLook.inspect(path);
        visible = true;
        card.forceActiveFocus();
    }

    function hide() {
        visible = false;
        targetPath = "";
        previewData = ({});
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.hide()
    }

    Rectangle {
        id: card
        width: 640
        height: 480
        anchors.centerIn: parent
        radius: 12
        color: isDarkTheme ? "#242426" : "#F5F5F7"
        border.color: isDarkTheme ? "#3C3C3E" : "#D2D2D7"
        border.width: 1
        clip: true

        focus: true
        Keys.onSpacePressed: root.hide()
        Keys.onEscapePressed: root.hide()

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Header bar
            Rectangle {
                Layout.fillWidth: true
                height: 42
                color: isDarkTheme ? "#1E1E20" : "#EBEBF0"

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: isDarkTheme ? "#2F2F32" : "#DCDCDE"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10

                    Text {
                        Layout.fillWidth: true
                        text: root.previewData.name || ""
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideMiddle
                        color: isDarkTheme ? "#FFFFFF" : "#1D1D1F"
                    }

                    Text {
                        text: root.previewData.sizeFormatted || ""
                        font.pixelSize: 11
                        color: isDarkTheme ? "#8E8E93" : "#86868B"
                    }

                    Button {
                        text: "Open with..."
                        sizeClass: "compact"
                        onClicked: {
                            QuickLook.openWithDefault(root.targetPath);
                            root.hide();
                        }
                    }

                    Button {
                        text: "✕"
                        sizeClass: "compact"
                        implicitWidth: 26
                        onClicked: root.hide()
                    }
                }
            }

            // Preview Content Body
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // Image Preview
                Item {
                    visible: root.previewData.previewType === "image"
                    anchors.fill: parent
                    anchors.margins: 16

                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        source: root.previewData.previewType === "image" ? ("file://" + root.targetPath) : ""
                        smooth: true
                    }
                }

                // Text / Code Preview
                Item {
                    visible: root.previewData.previewType === "text"
                    anchors.fill: parent
                    anchors.margins: 12

                    QQC2.ScrollView {
                        anchors.fill: parent
                        clip: true

                        QQC2.TextArea {
                            readOnly: true
                            text: root.previewData.textContent || ""
                            font.family: "monospace"
                            font.pixelSize: 11
                            color: isDarkTheme ? "#E5E5EA" : "#1D1D1F"
                            wrapMode: Text.WrapAnywhere
                        }
                    }
                }

                // App Bundle Preview
                Item {
                    visible: root.previewData.previewType === "app"
                    anchors.fill: parent

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12
                        width: parent.width - 64

                        Image {
                            Layout.alignment: Qt.AlignHCenter
                            width: 96
                            height: 96
                            fillMode: Image.PreserveAspectFit
                            source: (root.previewData.bundleIcon && root.previewData.bundleIcon !== "")
                                    ? ("file://" + root.previewData.bundleIcon)
                                    : "image://icon/application-x-executable"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.previewData.bundleName || root.previewData.name || ""
                            font.pixelSize: 18
                            font.weight: Font.Bold
                            color: isDarkTheme ? "#FFFFFF" : "#1D1D1F"
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            height: 22
                            width: bIdText.implicitWidth + 16
                            radius: 11
                            color: isDarkTheme ? "#333336" : "#E2E2E6"

                            Text {
                                id: bIdText
                                anchors.centerIn: parent
                                text: root.previewData.bundleId || ""
                                font.pixelSize: 11
                                color: isDarkTheme ? "#A1A1A6" : "#6E6E73"
                            }
                        }

                        Button {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Open Application"
                            isDefault: true
                            onClicked: {
                                FileOps.openItem(root.targetPath);
                                root.hide();
                            }
                        }
                    }
                }

                // Generic / Fallback Document Preview
                Item {
                    visible: root.previewData.previewType === "generic" || root.previewData.previewType === "pdf" || root.previewData.previewType === "directory"
                    anchors.fill: parent

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12
                        width: parent.width - 64

                        Image {
                            Layout.alignment: Qt.AlignHCenter
                            width: 80
                            height: 80
                            fillMode: Image.PreserveAspectFit
                            source: root.previewData.previewType === "directory"
                                    ? "image://icon/folder"
                                    : (root.previewData.previewType === "pdf"
                                       ? "image://icon/application-pdf"
                                       : "image://icon/text-x-generic")
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.previewData.name || ""
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            color: isDarkTheme ? "#FFFFFF" : "#1D1D1F"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.previewData.mimeType || ""
                            font.pixelSize: 12
                            color: isDarkTheme ? "#8E8E93" : "#86868B"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Last modified: " + (root.previewData.modifiedFormatted || "--")
                            font.pixelSize: 11
                            color: isDarkTheme ? "#8E8E93" : "#86868B"
                        }
                    }
                }
            }
        }
    }
}
