import QtQuick
import QtQuick.Layouts
import Conjunction.Design

// SPEC §4.3 Notification Center: 344 pt top-right drawer with 24 pt widget cards + stacked notifications
Item {
    id: root
    property Item backdropItem: null

    width: Math.min(344, parent ? parent.width - 24 : 344)
    height: Math.min(ncColumn.implicitHeight + 16, parent ? parent.height - 124 : ncColumn.implicitHeight + 16)
    clip: true

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: ncColumn.implicitHeight + 8
        clip: true

        ColumnLayout {
            id: ncColumn
            width: parent.width
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
                        Layout.fillWidth: true
                        spacing: 6
                        Icon { name: "sun"; size: 16; color: Theme.systemOrange }
                        Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: "TODAY"; color: Theme.systemOrange; font: Typography.caption2; elide: Text.ElideRight }
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: Qt.formatDate(new Date(), "dddd")
                        color: Theme.secondaryLabelColor
                        font: Typography.callout
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: Qt.formatDate(new Date(), "d")
                        color: Theme.labelColor
                        font: Typography.makeSpecFont(36, Font.DemiBold, -0.01, false, true)
                        elide: Text.ElideRight
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: Qt.formatDate(new Date(), "MMMM yyyy")
                        color: Theme.secondaryLabelColor
                        font: Typography.subheadline
                        elide: Text.ElideRight
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
                        Layout.fillWidth: true
                        spacing: 6
                        Icon { name: "battery"; size: 16; color: Theme.systemGreen }
                        Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: "SYSTEM"; color: Theme.systemGreen; font: Typography.caption2; elide: Text.ElideRight }
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: "100%"
                        color: Theme.labelColor
                        font: Typography.makeSpecFont(30, Font.DemiBold, -0.01, false, true)
                        elide: Text.ElideRight
                    }
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Icon { name: "wifi"; size: 14; color: Theme.systemBlue }
                        Text { text: ShellState.wifiEnabled ? ShellState.wifiSsid : "Offline"; color: Theme.secondaryLabelColor; font: Typography.subheadline; elide: Text.ElideRight; Layout.fillWidth: true; Layout.minimumWidth: 0 }
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
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }
            GlassSurface {
                visible: ShellState.notificationHistory.length > 0
                Layout.preferredWidth: Math.max(56, clearLabel.implicitWidth + 18)
                Layout.preferredHeight: Math.max(22, clearLabel.implicitHeight + 6)
                variant: "clear"
                cornerRadius: Layout.preferredHeight * 0.5
                shadowPreset: "none"
                backdropItem: root.backdropItem
                Text { id: clearLabel; anchors.centerIn: parent; text: "Clear"; color: Theme.labelColor; font: Typography.caption2 }
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
                            Layout.fillWidth: true
                            Text { text: modelData.appName || "Notification"; color: Theme.secondaryLabelColor; font: Typography.subheadline; elide: Text.ElideRight; Layout.fillWidth: true; Layout.minimumWidth: 0 }
                            Text { text: "now"; color: Theme.tertiaryLabelColor; font: Typography.caption1 }
                        }
                        Text { text: modelData.summary || ""; color: Theme.labelColor; font: Typography.headline; elide: Text.ElideRight; Layout.fillWidth: true; Layout.minimumWidth: 0 }
                        Text { text: modelData.body || ""; color: Theme.secondaryLabelColor; font: Typography.callout; wrapMode: Text.Wrap; elide: Text.ElideRight; maximumLineCount: 2; Layout.fillWidth: true; Layout.minimumWidth: 0 }
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
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 8
                Icon { name: ShellState.doNotDisturb ? "bell-off" : "bell"; size: 18; color: Theme.secondaryLabelColor }
                Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: ShellState.doNotDisturb ? "Focus On — Notifications Paused" : "No New Notifications"; color: Theme.secondaryLabelColor; font: Typography.callout; elide: Text.ElideRight }
            }
        }

        // Footer Centered "Edit Widgets" Pill
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(32, editWidgetsTxt.implicitHeight + 12)
            GlassSurface {
                anchors.centerIn: parent
                width: Math.min(280, Math.max(112, editWidgetsTxt.implicitWidth + 28))
                height: Math.max(28, editWidgetsTxt.implicitHeight + 10)
                variant: "clear"
                cornerRadius: height * 0.5
                shadowPreset: "pill"
                backdropItem: root.backdropItem
                Text {
                    id: editWidgetsTxt
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - 16)
                    text: "Edit Widgets"
                    color: Theme.labelColor
                    font: Typography.callout
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
                MouseArea { anchors.fill: parent; onClicked: ShellState.OpenSetting("notifications") }
            }
        }
        }
    }
}
