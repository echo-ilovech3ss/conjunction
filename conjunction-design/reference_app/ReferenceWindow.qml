import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls as Controls

Window {
    id: window
    width: 600
    height: 400
    visible: true
    title: "Desktop Reference"

    property string markerStatus: "No marker created yet"

    Rectangle {
        anchors.fill: parent
        color: Theme.background

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 20

            Text {
                text: "Conjunction Reference Application"
                font: Typography.windowTitle
                color: Theme.textPrimary
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Global menu 'File -> Create Test Marker' and the button below trigger the same logical Action."
                font: Typography.body
                color: Theme.textSecondary
                Layout.alignment: Qt.AlignHCenter
            }

            Controls.Button {
                text: "Create Test Marker"
                isDefault: true
                Layout.alignment: Qt.AlignHCenter
                onClicked: {
                    ReferenceBridge.createTestMarker("in_window_button");
                    window.markerStatus = "Test Marker Created via In-Window Button!";
                }
            }

            Text {
                text: window.markerStatus
                font: Typography.controlLabel
                color: Theme.accent
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
