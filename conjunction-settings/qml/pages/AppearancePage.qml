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

        // Appearance Mode Hero Card (SPEC §4.8 Light / Dark switcher + Preview)
        Rectangle {
            id: modeCard
            Layout.fillWidth: true
            radius: Geometry.radiusCard
            color: Theme.isDark ? Qt.rgba(1,1,1,0.06) : "#FFFFFF"
            border.color: (SettingsManager.highlightedSetting === "appearance.mode") ? Theme.systemBlue : Theme.separatorColor
            border.width: (SettingsManager.highlightedSetting === "appearance.mode") ? 2 : 1
            implicitHeight: 96

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: "Appearance"; font: Typography.headline; color: Theme.labelColor }
                    Text { text: "Select Light or Dark appearance across desktop surfaces"; font: Typography.caption1; color: Theme.secondaryLabelColor }
                }

                RowLayout {
                    spacing: 12

                    Rectangle {
                        width: 72; height: 56; radius: 8
                        color: SettingsManager.appearanceMode === "light" ? Theme.controlFillHover : "transparent"
                        border.color: SettingsManager.appearanceMode === "light" ? Theme.systemBlue : Theme.separatorColor
                        border.width: SettingsManager.appearanceMode === "light" ? 2 : 1
                        ColumnLayout {
                            anchors.centerIn: parent; spacing: 4
                            Rectangle { width: 32; height: 20; radius: 4; color: "#ECECEC"; border.width: 1; border.color: "#CCCCCC"; Layout.alignment: Qt.AlignHCenter }
                            Text { text: "Light"; font: Typography.caption1; color: Theme.labelColor; Layout.alignment: Qt.AlignHCenter }
                        }
                        TapHandler { onTapped: SettingsManager.setAppearanceMode("light") }
                    }

                    Rectangle {
                        width: 72; height: 56; radius: 8
                        color: SettingsManager.appearanceMode === "dark" ? Theme.controlFillHover : "transparent"
                        border.color: SettingsManager.appearanceMode === "dark" ? Theme.systemBlue : Theme.separatorColor
                        border.width: SettingsManager.appearanceMode === "dark" ? 2 : 1
                        ColumnLayout {
                            anchors.centerIn: parent; spacing: 4
                            Rectangle { width: 32; height: 20; radius: 4; color: "#1E1E1E"; border.width: 1; border.color: "#444444"; Layout.alignment: Qt.AlignHCenter }
                            Text { text: "Dark"; font: Typography.caption1; color: Theme.labelColor; Layout.alignment: Qt.AlignHCenter }
                        }
                        TapHandler { onTapped: SettingsManager.setAppearanceMode("dark") }
                    }
                }
            }
        }

        // Accent Color Card
        Rectangle {
            id: accentCard
            Layout.fillWidth: true
            radius: Geometry.radiusCard
            color: Theme.isDark ? Qt.rgba(1,1,1,0.06) : "#FFFFFF"
            border.color: (SettingsManager.highlightedSetting === "appearance.accent") ? Theme.systemBlue : Theme.separatorColor
            border.width: (SettingsManager.highlightedSetting === "appearance.accent") ? 2 : 1
            implicitHeight: 76

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    Text { text: "Accent Color"; font: Typography.headline; color: Theme.labelColor }
                    Text { text: "System highlight and focus indicator tint"; font: Typography.caption1; color: Theme.secondaryLabelColor }
                }
                RowLayout {
                    spacing: 8
                    Repeater {
                        model: [
                            { "id": "blue",     "hex": "#007AFF" },
                            { "id": "purple",   "hex": "#CB30E0" },
                            { "id": "pink",     "hex": "#FF2D55" },
                            { "id": "orange",   "hex": "#FF8D28" },
                            { "id": "green",    "hex": "#34C759" },
                            { "id": "graphite", "hex": "#8E8E93" }
                        ]
                        delegate: Rectangle {
                            width: 24; height: 24; radius: 12
                            color: modelData.hex
                            border.width: SettingsManager.appearanceAccent === modelData.id ? 2 : 0
                            border.color: Theme.labelColor
                            Rectangle {
                                visible: SettingsManager.appearanceAccent === modelData.id
                                anchors.centerIn: parent; width: 7; height: 7; radius: 3.5; color: "#FFFFFF"
                            }
                            TapHandler { onTapped: SettingsManager.setAppearanceAccent(modelData.id) }
                        }
                    }
                }
            }
        }

        // Accessibility Display Group (SPEC §1.5 + §3.3: Reduce Transparency, Increase Contrast, Reduced Motion)
        Rectangle {
            Layout.fillWidth: true
            radius: Geometry.radiusCard
            color: Theme.isDark ? Qt.rgba(1,1,1,0.06) : "#FFFFFF"
            border.color: Theme.separatorColor
            border.width: 1
            implicitHeight: accCol.implicitHeight + 24

            ColumnLayout {
                id: accCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { text: "Reduce Transparency"; font: Typography.headline; color: Theme.labelColor }
                        Text { text: "Replace translucent glass surfaces with opaque fills"; font: Typography.caption1; color: Theme.secondaryLabelColor }
                    }
                    Controls.Switch {
                        checked: SettingsManager.reduceTransparency
                        onToggled: SettingsManager.setReduceTransparency(checked)
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.separatorColor }

                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { text: "Increase Contrast"; font: Typography.headline; color: Theme.labelColor }
                        Text { text: "Strengthen borders, separators, and label legibility"; font: Typography.caption1; color: Theme.secondaryLabelColor }
                    }
                    Controls.Switch {
                        checked: SettingsManager.increaseContrast
                        onToggled: SettingsManager.setIncreaseContrast(checked)
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.separatorColor }

                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { text: "Reduced Motion"; font: Typography.headline; color: Theme.labelColor }
                        Text { text: "Crossfade windows instead of spring & Genie transitions"; font: Typography.caption1; color: Theme.secondaryLabelColor }
                    }
                    Controls.Switch {
                        checked: SettingsManager.reducedMotion
                        onToggled: SettingsManager.setReducedMotion(checked)
                    }
                }
            }
        }

        Item { height: 20 }
    }
}
