import QtQuick
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls as C

// SPEC §5.3 Bottom-Right Hot Corner (14): Floating Clear Glass Quick Note sheet
Item {
    id: root
    property Item backdropItem: null

    width: 340
    height: 240

    GlassSurface {
        anchors.fill: parent
        variant: "clear"
        cornerRadius: 22
        shadowPreset: "window"
        backdropItem: root.backdropItem

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                TrafficLights {
                    onCloseClicked: ShellState.quickNoteVisible = false
                    onMinimizeClicked: ShellState.quickNoteVisible = false
                    canZoom: false
                }
                Text {
                    Layout.fillWidth: true
                    text: "Quick Note"
                    color: Theme.labelColor
                    font: Typography.headline
                    horizontalAlignment: Text.AlignHCenter
                }
                Icon { name: "note"; size: 16; color: Theme.systemOrange }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.separatorColor
            }

            C.TextArea {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: ShellState.quickNoteText
                onTextChanged: {
                    if (ShellState.quickNoteText !== text) {
                        ShellState.quickNoteText = text;
                    }
                }
            }
        }
    }
}
