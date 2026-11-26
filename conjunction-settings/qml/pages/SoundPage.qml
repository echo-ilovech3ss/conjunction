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
        width: Math.min(root.availableWidth - 36, 480)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 20

        Item { height: 12 }

        Text {
            Layout.fillWidth: true
            text: "Sound"
            font: Typography.title
            color: Theme.textPrimary
            Layout.leftMargin: 4
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: "Output volume, alert sounds, and playback device selection."
            font: Typography.body
            color: Theme.textSecondary
            Layout.leftMargin: 4
            wrapMode: Text.Wrap
        }

        // Sound Output Card
        Rectangle {
            Layout.fillWidth: true
            radius: 12
            color: Theme.isDark ? "#14FFFFFF" : "#08000000"
            border.color: Theme.separator
            border.width: 1
            implicitHeight: soundColumn.implicitHeight + 24

            ColumnLayout {
                id: soundColumn
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                // 1. Output Volume Slider
                Rectangle {
                    Layout.fillWidth: true
                    radius: 8
                    color: (SettingsManager.highlightedSetting === "sound.volume") ? (Theme.isDark ? "#2A3478F6" : "#1A0066CC") : "transparent"
                    border.color: (SettingsManager.highlightedSetting === "sound.volume") ? Theme.accent : "transparent"
                    border.width: 1
                    implicitHeight: volRow.implicitHeight + 12

                    RowLayout {
                        id: volRow
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 16

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: "Output Volume"
                                font: Typography.headline
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: "Master audio volume level (" + SettingsManager.soundVolume + "%)"
                                font: Typography.caption
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                            }
                        }

                        Controls.Slider {
                            Layout.preferredWidth: Math.min(180, Math.round(soundColumn.width * 0.42))
                            from: 0
                            to: 100
                            stepSize: 1
                            value: SettingsManager.soundVolume
                            onMoved: {
                                SettingsManager.setSoundVolume(Math.round(value))
                                AudioBackend.setVolume(Math.round(value))
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.separator }

                // 2. Mute Toggle
                Rectangle {
                    Layout.fillWidth: true
                    radius: 8
                    color: (SettingsManager.highlightedSetting === "sound.muted") ? (Theme.isDark ? "#2A3478F6" : "#1A0066CC") : "transparent"
                    border.color: (SettingsManager.highlightedSetting === "sound.muted") ? Theme.accent : "transparent"
                    border.width: 1
                    implicitHeight: muteRow.implicitHeight + 12

                    RowLayout {
                        id: muteRow
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 16

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: "Mute Audio"
                                font: Typography.headline
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: "Silence all audio output channels"
                                font: Typography.caption
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                            }
                        }

                        Controls.Switch {
                            checked: SettingsManager.soundMuted
                            onToggled: {
                                SettingsManager.setSoundMuted(checked)
                                AudioBackend.setMuted(checked)
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.separator }

                // 3. Output Device
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "Output Device"
                        font: Typography.headline
                        color: Theme.textPrimary
                    }

                    Repeater {
                        model: AudioBackend.outputDevices
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            radius: 6
                            property bool active: AudioBackend.currentDevice === modelData
                            color: active ? (Theme.isDark ? "#2A3478F6" : "#1A0066CC") : (Theme.isDark ? "#14FFFFFF" : "#08000000")
                            border.color: active ? Theme.accent : Theme.separator
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12

                                Text {
                                    text: modelData
                                    font: Typography.body
                                    color: Theme.textPrimary
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "✓"
                                    font.bold: true
                                    color: Theme.accent
                                    visible: active
                                }
                            }

                            TapHandler {
                                onTapped: AudioBackend.setCurrentDevice(modelData)
                            }
                        }
                    }
                }
            }
        }

        Item { height: 20 }
    }
}
