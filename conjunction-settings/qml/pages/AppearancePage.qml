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
            text: "Appearance"
            font: Typography.title
            color: Theme.textPrimary
            Layout.leftMargin: 4
        }

        Text {
            text: "Customize the look and feel of Conjunction desktop and applications."
            font: Typography.body
            color: Theme.textSecondary
            Layout.leftMargin: 4
        }

        // Appearance Mode Section
        Rectangle {
            id: modeCard
            Layout.fillWidth: true
            radius: 12
            color: Theme.isDark ? "#14FFFFFF" : "#08000000"
            border.color: (SettingsManager.highlightedSetting === "appearance.mode") ? Theme.accent : Theme.separator
            border.width: (SettingsManager.highlightedSetting === "appearance.mode") ? 2 : 1
            implicitHeight: 90

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Appearance Mode"
                        font: Typography.headline
                        color: Theme.textPrimary
                    }
                    Text {
                        text: "Select Light or Dark desktop theme"
                        font: Typography.caption
                        color: Theme.textSecondary
                    }
                }

                RowLayout {
                    spacing: 12

                    // Dark option card
                    Rectangle {
                        width: 70
                        height: 52
                        radius: 8
                        color: SettingsManager.appearanceMode === "dark" ? (Theme.isDark ? "#333478F6" : "#200066CC") : (Theme.isDark ? "#22FFFFFF" : "#15000000")
                        border.color: SettingsManager.appearanceMode === "dark" ? Theme.accent : Theme.separator
                        border.width: SettingsManager.appearanceMode === "dark" ? 2 : 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Rectangle { width: 24; height: 16; radius: 3; color: "#1F2026"; Layout.alignment: Qt.AlignHCenter }
                            Text { text: "Dark"; font: Typography.caption; color: Theme.textPrimary; Layout.alignment: Qt.AlignHCenter }
                        }

                        TapHandler {
                            onTapped: SettingsManager.setAppearanceMode("dark")
                        }
                    }

                    // Light option card
                    Rectangle {
                        width: 70
                        height: 52
                        radius: 8
                        color: SettingsManager.appearanceMode === "light" ? (Theme.isDark ? "#333478F6" : "#200066CC") : (Theme.isDark ? "#22FFFFFF" : "#15000000")
                        border.color: SettingsManager.appearanceMode === "light" ? Theme.accent : Theme.separator
                        border.width: SettingsManager.appearanceMode === "light" ? 2 : 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Rectangle { width: 24; height: 16; radius: 3; color: "#FFFFFF"; border.color: "#CCCCCC"; border.width: 1; Layout.alignment: Qt.AlignHCenter }
                            Text { text: "Light"; font: Typography.caption; color: Theme.textPrimary; Layout.alignment: Qt.AlignHCenter }
                        }

                        TapHandler {
                            onTapped: SettingsManager.setAppearanceMode("light")
                        }
                    }
                }
            }
        }

        // Accent Color Section
        Rectangle {
            id: accentCard
            Layout.fillWidth: true
            radius: 12
            color: Theme.isDark ? "#14FFFFFF" : "#08000000"
            border.color: (SettingsManager.highlightedSetting === "appearance.accent") ? Theme.accent : Theme.separator
            border.width: (SettingsManager.highlightedSetting === "appearance.accent") ? 2 : 1
            implicitHeight: 84

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Accent Color"
                        font: Typography.headline
                        color: Theme.textPrimary
                    }
                    Text {
                        text: "Choose system focus and control highlight tint"
                        font: Typography.caption
                        color: Theme.textSecondary
                    }
                }

                RowLayout {
                    spacing: 10

                    readonly property var colors: ["#0066CC", "#5856D6", "#34C759", "#FF9500", "#FF2D55"]

                    Repeater {
                        model: accentCard.parent ? ["#0066CC", "#5856D6", "#34C759", "#FF9500", "#FF2D55"] : []
                        delegate: Rectangle {
                            width: 28
                            height: 28
                            radius: 14
                            color: modelData
                            border.color: SettingsManager.appearanceAccent === modelData ? (Theme.isDark ? "#FFFFFF" : "#000000") : "transparent"
                            border.width: 2

                            Rectangle {
                                anchors.centerIn: parent
                                width: 8
                                height: 8
                                radius: 4
                                color: "#FFFFFF"
                                visible: SettingsManager.appearanceAccent === modelData
                            }

                            TapHandler {
                                onTapped: SettingsManager.setAppearanceAccent(modelData)
                            }
                        }
                    }
                }
            }
        }

        // Accessibility & Motion Section
        Rectangle {
            id: motionCard
            Layout.fillWidth: true
            radius: 12
            color: Theme.isDark ? "#14FFFFFF" : "#08000000"
            border.color: (SettingsManager.highlightedSetting === "accessibility.reducedMotion") ? Theme.accent : Theme.separator
            border.width: (SettingsManager.highlightedSetting === "accessibility.reducedMotion") ? 2 : 1
            implicitHeight: 74

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Reduced Motion"
                        font: Typography.headline
                        color: Theme.textPrimary
                    }
                    Text {
                        text: "Minimize animations and transitions across the desktop and apps"
                        font: Typography.caption
                        color: Theme.textSecondary
                    }
                }

                Controls.Switch {
                    checked: SettingsManager.reducedMotion
                    onToggled: SettingsManager.setReducedMotion(checked)
                }
            }
        }

        Item { height: 20 }
    }
}
