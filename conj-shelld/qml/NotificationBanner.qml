import QtQuick
import QtQuick.Layouts
import Conjunction.Design

// SPEC §4.3 Top-right 344 pt slide-in Clear Glass Notification Toast Banner
Item {
    id: root
    property Item backdropItem: null

    width: 344
    height: bannerCol.implicitHeight

    Column {
        id: bannerCol
        width: 344
        spacing: 8

        Repeater {
            model: ShellState.activeBanners
            delegate: GlassSurface {
                width: 344
                height: innerRow.implicitHeight + 24
                variant: "clear"
                cornerRadius: 22
                shadowPreset: "popover"
                backdropItem: root.backdropItem

                RowLayout {
                    id: innerRow
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Rectangle {
                        width: 40; height: 40; radius: 11
                        color: Theme.systemBlue
                        Icon { anchors.centerIn: parent; name: "bell"; size: 22; color: "#FFFFFF" }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        RowLayout {
                            Text { text: modelData.appName || "System"; color: Theme.secondaryLabelColor; font: Typography.subheadline; Layout.fillWidth: true }
                            Text { text: "now"; color: Theme.tertiaryLabelColor; font: Typography.caption1 }
                        }
                        Text { text: modelData.summary || ""; color: Theme.labelColor; font: Typography.headline; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: modelData.body || ""; color: Theme.secondaryLabelColor; font: Typography.callout; wrapMode: Text.WordWrap; maximumLineCount: 2; Layout.fillWidth: true }
                    }

                    Item {
                        Layout.preferredWidth: 20; Layout.preferredHeight: 20
                        Icon { anchors.centerIn: parent; name: "close"; size: 14; color: Theme.secondaryLabelColor }
                        MouseArea { anchors.fill: parent; onClicked: ShellState.dismissNotification(modelData.id) }
                    }
                }
            }
        }
    }
}
