import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls as Controls

ScrollView {
    id: root
    clip: true
    contentWidth: availableWidth

    ColumnLayout {
        width: Math.min(root.width - 48, 640)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 20

        Item { height: 12 }

        Text {
            text: "Bluetooth"
            font: Typography.title
            color: Theme.textPrimary
            Layout.leftMargin: 4
        }

        Text {
            text: "Manage wireless Bluetooth controllers, mice, keyboards, and accessories."
            font: Typography.body
            color: Theme.textSecondary
            Layout.leftMargin: 4
        }

        // Adapter State Card
        Rectangle {
            Layout.fillWidth: true
            radius: 12
            color: Theme.isDark ? "#14FFFFFF" : "#08000000"
            border.color: (SettingsManager.highlightedSetting === "bluetooth.enabled") ? Theme.accent : Theme.separator
            border.width: (SettingsManager.highlightedSetting === "bluetooth.enabled") ? 2 : 1
            implicitHeight: 84

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Bluetooth Adapter"
                        font: Typography.headline
                        color: Theme.textPrimary
                    }
                    Text {
                        text: BluetoothBackend.hasAdapter ? (BluetoothBackend.isEnabled ? "Bluetooth is active and discoverable" : "Bluetooth adapter is turned off") : "No Bluetooth hardware detected on this machine"
                        font: Typography.caption
                        color: Theme.textSecondary
                    }
                }

                Controls.Switch {
                    enabled: BluetoothBackend.hasAdapter
                    checked: BluetoothBackend.isEnabled
                    onToggled: {
                        BluetoothBackend.setEnabled(checked)
                        SettingsManager.setBluetoothEnabled(checked)
                    }
                }
            }
        }

        // Graceful No-Adapter Fallback Banner
        Rectangle {
            Layout.fillWidth: true
            radius: 10
            color: Theme.isDark ? "#20FF9500" : "#15FF9500"
            border.color: "#FF9500"
            border.width: 1
            visible: !BluetoothBackend.hasAdapter
            implicitHeight: noBtCol.implicitHeight + 20

            RowLayout {
                id: noBtCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                Text {
                    text: "ℹ️"
                    font.pixelSize: 18
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Bluetooth Not Available"
                        font: Typography.headline
                        color: Theme.textPrimary
                    }
                    Text {
                        text: "No Bluetooth controller or radio was detected. Connect a USB Bluetooth dongle or verify kernel drivers to pair accessories."
                        font: Typography.caption
                        color: Theme.textSecondary
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // My Devices Section (when adapter is active)
        Text {
            text: "My Devices"
            font: Typography.headline
            color: Theme.textPrimary
            Layout.leftMargin: 4
            visible: BluetoothBackend.hasAdapter && BluetoothBackend.isEnabled
        }

        Rectangle {
            Layout.fillWidth: true
            radius: 12
            color: Theme.isDark ? "#14FFFFFF" : "#08000000"
            border.color: Theme.separator
            border.width: 1
            visible: BluetoothBackend.hasAdapter && BluetoothBackend.isEnabled
            implicitHeight: btDevCol.implicitHeight + 20

            ColumnLayout {
                id: btDevCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Repeater {
                    model: BluetoothBackend.pairedDevices
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 48
                        radius: 8
                        color: modelData.connected ? (Theme.isDark ? "#2A3478F6" : "#1A0066CC") : (Theme.isDark ? "#14FFFFFF" : "#08000000")
                        border.color: modelData.connected ? Theme.accent : Theme.separator
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            Text {
                                text: "🎧"
                                font.pixelSize: 14
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: modelData.name
                                    font: Typography.body
                                    color: Theme.textPrimary
                                }
                                Text {
                                    text: modelData.address
                                    font: Typography.caption
                                    color: Theme.textSecondary
                                }
                            }

                            Text {
                                text: modelData.connected ? "Connected" : "Not Connected"
                                font: Typography.caption
                                color: modelData.connected ? Theme.accent : Theme.textSecondary
                            }
                        }
                    }
                }
            }
        }

        Item { height: 20 }
    }
}
