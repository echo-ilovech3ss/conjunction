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
            text: "Network"
            font: Typography.title
            color: Theme.textPrimary
            Layout.leftMargin: 4
        }

        Text {
            text: "Wi-Fi connections, network status, and IP configuration."
            font: Typography.body
            color: Theme.textSecondary
            Layout.leftMargin: 4
        }

        // Wi-Fi Master Toggle Card
        Rectangle {
            Layout.fillWidth: true
            radius: 12
            color: Theme.isDark ? "#14FFFFFF" : "#08000000"
            border.color: (SettingsManager.highlightedSetting === "network.wifi.enabled") ? Theme.accent : Theme.separator
            border.width: (SettingsManager.highlightedSetting === "network.wifi.enabled") ? 2 : 1
            implicitHeight: 84

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Wi-Fi"
                        font: Typography.headline
                        color: Theme.textPrimary
                    }
                    Text {
                        text: NetworkBackend.isWirelessEnabled ? ("Connected to " + NetworkBackend.activeSsid + " (" + NetworkBackend.ipAddress + ")") : "Wi-Fi adapter is turned off"
                        font: Typography.caption
                        color: Theme.textSecondary
                    }
                }

                Controls.Switch {
                    checked: NetworkBackend.isWirelessEnabled
                    onToggled: {
                        NetworkBackend.setWirelessEnabled(checked)
                        SettingsManager.setWifiEnabled(checked)
                    }
                }
            }
        }

        // Available Networks Section
        Text {
            text: "Available Networks"
            font: Typography.headline
            color: Theme.textPrimary
            Layout.leftMargin: 4
            visible: NetworkBackend.isWirelessEnabled
        }

        Rectangle {
            Layout.fillWidth: true
            radius: 12
            color: Theme.isDark ? "#14FFFFFF" : "#08000000"
            border.color: Theme.separator
            border.width: 1
            visible: NetworkBackend.isWirelessEnabled
            implicitHeight: netCol.implicitHeight + 20

            ColumnLayout {
                id: netCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Repeater {
                    model: NetworkBackend.availableNetworks
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
                                text: "📶"
                                font.pixelSize: 14
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: modelData.ssid
                                    font: Typography.body
                                    color: Theme.textPrimary
                                }
                                Text {
                                    text: modelData.security + " • Signal " + modelData.signal + "%"
                                    font: Typography.caption
                                    color: Theme.textSecondary
                                }
                            }

                            Text {
                                text: modelData.connected ? "Connected" : ""
                                font: Typography.caption
                                color: Theme.accent
                                visible: modelData.connected
                            }

                            Controls.Button {
                                text: "Connect"
                                sizeClass: "compact"
                                visible: !modelData.connected
                                onClicked: NetworkBackend.connectToNetwork(modelData.ssid)
                            }
                        }
                    }
                }
            }
        }

        Item { height: 20 }
    }
}
