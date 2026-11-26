import QtQuick
import QtQuick.Layouts
import Conjunction.Design

// SPEC §4.3 Notification Center: 344 pt top-right drawer with 24 pt widget cards + stacked notifications
Item {
    id: root
    property Item backdropItem: null

    width: 344
    height: ncColumn.implicitHeight + 16

    ColumnLayout {
        id: ncColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 12

        // 1. Stacked Widget Row (185 pt height matching SPEC §4.3)
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 164
            spacing: 12

            // Clock / Calendar Widget Card
            GlassSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                variant: "clear"
                cornerRadius: 24
                shadowPreset: "popover"
                backdropItem: root.backdropItem

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 4
                    RowLayout {
                        spacing: 6
                        Icon { name: "sun"; size: 16; color: Theme.systemOrange }
                        Text { text: "TODAY"; color: Theme.systemOrange; font: Typography.caption2 }
                    }
                    Text {
                        text: Qt.formatDate(new Date(), "dddd")
                        color: Theme.secondaryLabelColor
                        font: Typography.callout
                    }
                    Text {
                        text: Qt.formatDate(new Date(), "d")
                        color: Theme.labelColor
                        font: Typography.makeSpecFont(36, Font.DemiBold, -0.01, false, true)
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        text: Qt.formatDate(new Date(), "MMMM yyyy")
                        color: Theme.secondaryLabelColor
                        font: Typography.subheadline
                    }
                }
            }

            // System & Battery Widget Card
            GlassSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                variant: "clear"
                cornerRadius: 24
                shadowPreset: "popover"
                backdropItem: root.backdropItem

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 6
                    RowLayout {
                        spacing: 6
                        Icon { name: "battery"; size: 16; color: Theme.systemGreen }
                        Text { text: "SYSTEM"; color: Theme.systemGreen; font: Typography.caption2 }
                    }
                    Text {
                        text: "100%"
                        color: Theme.labelColor
                        font: Typography.makeSpecFont(30, Font.DemiBold, -0.01, false, true)
                    }
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        spacing: 6
                        Icon { name: "wifi"; size: 14; color: Theme.systemBlue }
                        Text { text: ShellState.wifiEnabled ? ShellState.wifiSsid : "Offline"; color: Theme.secondaryLabelColor; font: Typography.subheadline; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                }
            }
        }

        // 2. Notification Stack Header
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            Text {
                text: "Notifications"
                color: Theme.labelColor
                font: Typography.headline
                Layout.fillWidth: true
            }
            GlassSurface {
                visible: ShellState.notificationHistory.length > 0
                Layout.preferredWidth: 56; Layout.preferredHeight: 22
                variant: "clear"
                cornerRadius: 11
                shadowPreset: "none"
                backdropItem: root.backdropItem
                Text { anchors.centerIn: parent; text: "Clear"; color: Theme.labelColor; font: Typography.caption2 }
                MouseArea { anchors.fill: parent; onClicked: ShellState.clearNotificationHistory() }
            }
        }

        // 3. Stacked Notifications Cards (Clear Glass cr=24)
        Repeater {
            model: ShellState.notificationHistory
            delegate: GlassSurface {
                Layout.fillWidth: true
                Layout.preferredHeight: cardContent.implicitHeight + 24
                variant: "clear"
                cornerRadius: 22
                shadowPreset: "popover"
                backdropItem: root.backdropItem

                RowLayout {
                    id: cardContent
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10
                    Rectangle {
                        width: 38; height: 38; radius: 10
                        color: Theme.systemBlue
                        Icon { anchors.centerIn: parent; name: "bell"; size: 20; color: "#FFFFFF" }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        RowLayout {
                            Text { text: modelData.appName || "Notification"; color: Theme.secondaryLabelColor; font: Typography.subheadline; Layout.fillWidth: true }
                            Text { text: "now"; color: Theme.tertiaryLabelColor; font: Typography.caption1 }
                        }
                        Text { text: modelData.summary || ""; color: Theme.labelColor; font: Typography.headline; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: modelData.body || ""; color: Theme.secondaryLabelColor; font: Typography.callout; wrapMode: Text.WordWrap; maximumLineCount: 2; Layout.fillWidth: true }
                    }
                    Item {
                        Layout.preferredWidth: 22; Layout.preferredHeight: 22
                        Icon { anchors.centerIn: parent; name: "close"; size: 14; color: Theme.secondaryLabelColor }
                        MouseArea { anchors.fill: parent; onClicked: ShellState.dismissNotification(modelData.id) }
                    }
                }
            }
        }

        // Empty State when no pending notifications
        GlassSurface {
            visible: ShellState.notificationHistory.length === 0
            Layout.fillWidth: true
            Layout.preferredHeight: 84
            variant: "clear"
            cornerRadius: 22
            shadowPreset: "pill"
            backdropItem: root.backdropItem
            RowLayout {
                anchors.centerIn: parent
                spacing: 8
                Icon { name: ShellState.doNotDisturb ? "bell-off" : "bell"; size: 18; color: Theme.secondaryLabelColor }
                Text { text: ShellState.doNotDisturb ? "Focus On — Notifications Paused" : "No New Notifications"; color: Theme.secondaryLabelColor; font: Typography.callout }
            }
        }

        // Footer Centered "Edit Widgets" Pill
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            GlassSurface {
                anchors.centerIn: parent
                width: 112; height: 28
                variant: "clear"
                cornerRadius: 14
                shadowPreset: "pill"
                backdropItem: root.backdropItem
                Text { anchors.centerIn: parent; text: "Edit Widgets"; color: Theme.labelColor; font: Typography.callout }
                MouseArea { anchors.fill: parent; onClicked: ShellState.OpenSetting("notifications") }
            }
        }
    }
}
