import QtQuick
import QtQuick.Layouts
import Conjunction.Design 1.0
import Conjunction.Controls 1.0

Rectangle {
    id: root
    visible: false
    anchors.fill: parent
    color: "#70000000"

    property string title: "Empty Trash"
    property string message: "Are you sure you want to permanently erase the items in the Trash? You cannot undo this action."
    signal confirmed()

    function openDialog() {
        visible = true;
    }

    function closeDialog() {
        visible = false;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.closeDialog()
    }

    Rectangle {
        width: 320
        height: 160
        anchors.centerIn: parent
        radius: 10
        color: isDarkTheme ? "#28282A" : "#FFFFFF"
        border.color: isDarkTheme ? "#3C3C3E" : "#D2D2D7"
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Text {
                text: root.title
                font.pixelSize: 14
                font.weight: Font.Bold
                color: isDarkTheme ? "#FFFFFF" : "#1D1D1F"
            }

            Text {
                Layout.fillWidth: true
                text: root.message
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                color: isDarkTheme ? "#8E8E93" : "#6E6E73"
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8

                Button {
                    text: "Cancel"
                    sizeClass: "compact"
                    onClicked: root.closeDialog()
                }

                Button {
                    text: "Empty Trash"
                    sizeClass: "compact"
                    isDestructive: true
                    onClicked: {
                        root.closeDialog();
                        root.confirmed();
                    }
                }
            }
        }
    }
}
