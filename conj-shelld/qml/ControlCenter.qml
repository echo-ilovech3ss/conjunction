import QtQuick
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls as Controls

Item {
    id: root
    anchors.fill: parent
    visible: ShellState.controlCenterVisible
    z: 200

    // Dismiss when tapping outside the drawer
    TapHandler {
        onTapped: ShellState.controlCenterVisible = false
    }

    focus: visible
    Keys.onEscapePressed: ShellState.controlCenterVisible = false

    Rectangle {
        id: drawerCard
        width: 330
        height: 390
        anchors.top: parent.top
        anchors.topMargin: 36
        anchors.right: parent.right
        anchors.rightMargin: 12
        radius: 18

        color: Theme.isDark ? "#E61F2026" : "#F2F7FAFC"
        border.color: Theme.separator
        border.width: 1

        // Drop shadow illusion
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: 19
            color: "transparent"
            border.color: Theme.isDark ? "#33FFFFFF" : "#1A000000"
            border.width: 1
            z: -1
        }

        // Prevent tap-through closing drawer
        TapHandler {
            // Eat click inside card
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // Title
            Text {
                text: "Control Center"
                font: Typography.sectionHeading
                color: Theme.textPrimary
                Layout.leftMargin: 2
            }

            // Top Row: Wi-Fi & Bluetooth Pills
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Wi-Fi Tile
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    radius: 12
                    color: ShellState.wifiEnabled ? (Theme.isDark ? "#2A3478F6" : "#200066CC") : (Theme.isDark ? "#1AFFFFFF" : "#0D000000")
                    border.color: ShellState.wifiEnabled ? Theme.accent : Theme.separator
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: ShellState.wifiEnabled ? Theme.accent : (Theme.isDark ? "#33FFFFFF" : "#20000000")
                            Icon {
                                anchors.centerIn: parent
                                name: "network"
                                size: 16
                                color: ShellState.wifiEnabled ? "#FFFFFF" : Theme.textSecondary
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: "Wi-Fi"
                                font: Typography.controlLabel
                                color: Theme.textPrimary
                            }
                            Text {
                                text: ShellState.wifiSsid
                                font: Typography.caption
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    HoverHandler { id: wifiHover }
                    TapHandler { onTapped: ShellState.toggleWifi() }
                }

                // Bluetooth Tile
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    radius: 12
                    color: ShellState.bluetoothEnabled ? (Theme.isDark ? "#2A3478F6" : "#200066CC") : (Theme.isDark ? "#1AFFFFFF" : "#0D000000")
                    border.color: ShellState.bluetoothEnabled ? Theme.accent : Theme.separator
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: ShellState.bluetoothEnabled ? Theme.accent : (Theme.isDark ? "#33FFFFFF" : "#20000000")
                            Icon {
                                anchors.centerIn: parent
                                name: "bluetooth"
                                size: 16
                                color: ShellState.bluetoothEnabled ? "#FFFFFF" : Theme.textSecondary
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: "Bluetooth"
                                font: Typography.controlLabel
                                color: Theme.textPrimary
                            }
                            Text {
                                text: ShellState.bluetoothEnabled ? "On" : "Off"
                                font: Typography.caption
                                color: Theme.textSecondary
                            }
                        }
                    }

                    HoverHandler { id: btHover }
                    TapHandler { onTapped: ShellState.toggleBluetooth() }
                }
            }

            // Middle Row: Do Not Disturb & Dark Mode
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Do Not Disturb Tile
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    radius: 10
                    color: ShellState.doNotDisturb ? (Theme.isDark ? "#2A5856D6" : "#205856D6") : (Theme.isDark ? "#1AFFFFFF" : "#0D000000")
                    border.color: ShellState.doNotDisturb ? "#5856D6" : Theme.separator
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Icon {
                            name: "info"
                            size: 16
                            color: ShellState.doNotDisturb ? "#5856D6" : Theme.textSecondary
                        }
                        Text {
                            text: "Focus / DND"
                            font: Typography.controlLabel
                            color: Theme.textPrimary
                            Layout.fillWidth: true
                        }
                    }
                    TapHandler { onTapped: ShellState.toggleDoNotDisturb() }
                }

                // Dark Mode Tile
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    radius: 10
                    color: ShellState.isDark ? (Theme.isDark ? "#2AFFFFFF" : "#1A000000") : (Theme.isDark ? "#1AFFFFFF" : "#0D000000")
                    border.color: Theme.separator
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Icon {
                            name: ShellState.isDark ? "eye" : "close"
                            size: 16
                            color: Theme.accent
                        }
                        Text {
                            text: ShellState.isDark ? "Dark Theme" : "Light Theme"
                            font: Typography.controlLabel
                            color: Theme.textPrimary
                            Layout.fillWidth: true
                        }
                    }
                    TapHandler { onTapped: ShellState.toggleTheme() }
                }
            }

            // Display Brightness Slider Module
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                radius: 12
                color: Theme.isDark ? "#1AFFFFFF" : "#0D000000"
                border.color: Theme.separator
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Display Brightness"
                            font: Typography.caption
                            color: Theme.textSecondary
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: ShellState.brightness + "%"
                            font: Typography.caption
                            color: Theme.textPrimary
                        }
                    }

                    // Interactive slider track
                    Rectangle {
                        id: brightTrack
                        Layout.fillWidth: true
                        Layout.preferredHeight: 18
                        radius: 9
                        color: Theme.isDark ? "#33FFFFFF" : "#20000000"
                        clip: true

                        Rectangle {
                            height: parent.height
                            width: parent.width * (ShellState.brightness / 100.0)
                            radius: 9
                            color: Theme.accent
                        }

                        TapHandler {
                            onTapped: function(event) {
                                var ratio = Math.max(0.0, Math.min(1.0, event.position.x / brightTrack.width));
                                ShellState.brightness = Math.round(ratio * 100);
                            }
                        }
                        DragHandler {
                            target: null
                            onActiveChanged: {
                                if (active) {
                                    var ratio = Math.max(0.0, Math.min(1.0, centroid.position.x / brightTrack.width));
                                    ShellState.brightness = Math.round(ratio * 100);
                                }
                            }
                            onCentroidChanged: {
                                var ratio = Math.max(0.0, Math.min(1.0, centroid.position.x / brightTrack.width));
                                ShellState.brightness = Math.round(ratio * 100);
                            }
                        }
                    }
                }
            }

            // Sound Volume Slider Module
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                radius: 12
                color: Theme.isDark ? "#1AFFFFFF" : "#0D000000"
                border.color: Theme.separator
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Sound Output"
                            font: Typography.caption
                            color: Theme.textSecondary
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: ShellState.volume + "%"
                            font: Typography.caption
                            color: Theme.textPrimary
                        }
                    }

                    // Interactive volume track
                    Rectangle {
                        id: volumeTrack
                        Layout.fillWidth: true
                        Layout.preferredHeight: 18
                        radius: 9
                        color: Theme.isDark ? "#33FFFFFF" : "#20000000"
                        clip: true

                        Rectangle {
                            height: parent.height
                            width: parent.width * (ShellState.volume / 100.0)
                            radius: 9
                            color: "#28CD41"
                        }

                        TapHandler {
                            onTapped: function(event) {
                                var ratio = Math.max(0.0, Math.min(1.0, event.position.x / volumeTrack.width));
                                ShellState.volume = Math.round(ratio * 100);
                            }
                        }
                        DragHandler {
                            target: null
                            onCentroidChanged: {
                                var ratio = Math.max(0.0, Math.min(1.0, centroid.position.x / volumeTrack.width));
                                ShellState.volume = Math.round(ratio * 100);
                            }
                        }
                    }
                }
            }
        }
    }
}
