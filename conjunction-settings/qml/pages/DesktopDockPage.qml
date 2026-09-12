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
            text: "Desktop & Dock"
            font: Typography.title
            color: Theme.textPrimary
            Layout.leftMargin: 4
        }

        Text {
            text: "Configure the floating Dock, magnification behavior, and multi-monitor placement."
            font: Typography.body
            color: Theme.textSecondary
            Layout.leftMargin: 4
        }

        // Dock Settings Card
        Rectangle {
            Layout.fillWidth: true
            radius: 12
            color: Theme.isDark ? "#14FFFFFF" : "#08000000"
            border.color: Theme.separator
            border.width: 1
            implicitHeight: dockColumn.implicitHeight + 24

            ColumnLayout {
                id: dockColumn
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                // 1. Dock Size Slider
                Rectangle {
                    Layout.fillWidth: true
                    radius: 8
                    color: (SettingsManager.highlightedSetting === "dock.size") ? (Theme.isDark ? "#2A3478F6" : "#1A0066CC") : "transparent"
                    border.color: (SettingsManager.highlightedSetting === "dock.size") ? Theme.accent : "transparent"
                    border.width: 1
                    implicitHeight: sizeRow.implicitHeight + 12

                    RowLayout {
                        id: sizeRow
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 16

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Dock Size"
                                font: Typography.headline
                                color: Theme.textPrimary
                            }
                            Text {
                                text: "Base icon and bar height (" + SettingsManager.dockSize + " px)"
                                font: Typography.caption
                                color: Theme.textSecondary
                            }
                        }

                        Controls.Slider {
                            Layout.preferredWidth: 180
                            from: 36
                            to: 96
                            stepSize: 2
                            value: SettingsManager.dockSize
                            onMoved: SettingsManager.setDockSize(Math.round(value))
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.separator }

                // 2. Dock Magnification Toggle
                Rectangle {
                    Layout.fillWidth: true
                    radius: 8
                    color: (SettingsManager.highlightedSetting === "dock.magnification") ? (Theme.isDark ? "#2A3478F6" : "#1A0066CC") : "transparent"
                    border.color: (SettingsManager.highlightedSetting === "dock.magnification") ? Theme.accent : "transparent"
                    border.width: 1
                    implicitHeight: magRow.implicitHeight + 12

                    RowLayout {
                        id: magRow
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 16

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Dock Magnification"
                                font: Typography.headline
                                color: Theme.textPrimary
                            }
                            Text {
                                text: "Magnify icons smoothly on pointer hover"
                                font: Typography.caption
                                color: Theme.textSecondary
                            }
                        }

                        Controls.Switch {
                            checked: SettingsManager.dockMagnification
                            onToggled: SettingsManager.setDockMagnification(checked)
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.separator }

                // 3. Magnification Scale Max
                Rectangle {
                    Layout.fillWidth: true
                    radius: 8
                    opacity: SettingsManager.dockMagnification ? 1.0 : 0.5
                    color: (SettingsManager.highlightedSetting === "dock.magnificationScale") ? (Theme.isDark ? "#2A3478F6" : "#1A0066CC") : "transparent"
                    border.color: (SettingsManager.highlightedSetting === "dock.magnificationScale") ? Theme.accent : "transparent"
                    border.width: 1
                    implicitHeight: scaleRow.implicitHeight + 12

                    RowLayout {
                        id: scaleRow
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 16

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Magnification Scale"
                                font: Typography.headline
                                color: Theme.textPrimary
                            }
                            Text {
                                text: "Maximum scale factor (" + SettingsManager.dockMagnificationScale.toFixed(2) + "x)"
                                font: Typography.caption
                                color: Theme.textSecondary
                            }
                        }

                        Controls.Slider {
                            Layout.preferredWidth: 180
                            from: 1.1
                            to: 2.0
                            stepSize: 0.05
                            enabled: SettingsManager.dockMagnification
                            value: SettingsManager.dockMagnificationScale
                            onMoved: SettingsManager.setDockMagnificationScale(value)
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.separator }

                // 4. Multi-Monitor Display Policy
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Display Placement"
                            font: Typography.headline
                            color: Theme.textPrimary
                        }
                        Text {
                            text: "Which connected displays render the Dock"
                            font: Typography.caption
                            color: Theme.textSecondary
                        }
                    }

                    RowLayout {
                        spacing: 8

                        Rectangle {
                            width: 100
                            height: 32
                            radius: 6
                            color: SettingsManager.dockDisplayPolicy === "primary" ? Theme.accent : (Theme.isDark ? "#22FFFFFF" : "#15000000")
                            Text {
                                anchors.centerIn: parent
                                text: "Primary Only"
                                font: Typography.caption
                                color: SettingsManager.dockDisplayPolicy === "primary" ? "#FFFFFF" : Theme.textPrimary
                            }
                            TapHandler {
                                onTapped: SettingsManager.setDockDisplayPolicy("primary")
                            }
                        }

                        Rectangle {
                            width: 100
                            height: 32
                            radius: 6
                            color: SettingsManager.dockDisplayPolicy === "all" ? Theme.accent : (Theme.isDark ? "#22FFFFFF" : "#15000000")
                            Text {
                                anchors.centerIn: parent
                                text: "All Displays"
                                font: Typography.caption
                                color: SettingsManager.dockDisplayPolicy === "all" ? "#FFFFFF" : Theme.textPrimary
                            }
                            TapHandler {
                                onTapped: SettingsManager.setDockDisplayPolicy("all")
                            }
                        }
                    }
                }
            }
        }

        Item { height: 20 }
    }
}
