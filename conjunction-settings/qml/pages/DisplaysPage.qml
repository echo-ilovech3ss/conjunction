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
            text: "Displays"
            font: Typography.title
            color: Theme.textPrimary
            Layout.leftMargin: 4
        }

        Text {
            text: "Resolution, UI scaling, and multi-monitor output configuration."
            font: Typography.body
            color: Theme.textSecondary
            Layout.leftMargin: 4
        }

        // Active Display Info Card
        Rectangle {
            Layout.fillWidth: true
            radius: 12
            color: Theme.isDark ? "#14FFFFFF" : "#08000000"
            border.color: Theme.separator
            border.width: 1
            implicitHeight: displayColumn.implicitHeight + 24

            ColumnLayout {
                id: displayColumn
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    Rectangle {
                        width: 48
                        height: 36
                        radius: 6
                        color: Theme.isDark ? "#22FFFFFF" : "#15000000"
                        border.color: Theme.accent
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "1"
                            font.bold: true
                            color: Theme.accent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Primary Display"
                            font: Typography.headline
                            color: Theme.textPrimary
                        }
                        Text {
                            text: DisplayBackend.primaryResolution + " @ " + DisplayBackend.primaryRefreshRate
                            font: Typography.caption
                            color: Theme.textSecondary
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.separator }

                // Scale Selection
                Rectangle {
                    Layout.fillWidth: true
                    radius: 8
                    color: (SettingsManager.highlightedSetting === "displays.scale") ? (Theme.isDark ? "#2A3478F6" : "#1A0066CC") : "transparent"
                    border.color: (SettingsManager.highlightedSetting === "displays.scale") ? Theme.accent : "transparent"
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
                                text: "Display Scale"
                                font: Typography.headline
                                color: Theme.textPrimary
                            }
                            Text {
                                text: "Scale text and controls for high-density monitors"
                                font: Typography.caption
                                color: Theme.textSecondary
                            }
                        }

                        RowLayout {
                            spacing: 8

                            readonly property var scales: [
                                { label: "100%", val: 1.0 },
                                { label: "125%", val: 1.25 },
                                { label: "150%", val: 1.5 },
                                { label: "200%", val: 2.0 }
                            ]

                            Repeater {
                                model: [
                                    { label: "100%", val: 1.0 },
                                    { label: "125%", val: 1.25 },
                                    { label: "150%", val: 1.5 },
                                    { label: "200%", val: 2.0 }
                                ]
                                delegate: Rectangle {
                                    width: 58
                                    height: 32
                                    radius: 6
                                    property bool selected: Math.abs(DisplayBackend.currentScale - modelData.val) < 0.05
                                    color: selected ? Theme.accent : (Theme.isDark ? "#22FFFFFF" : "#15000000")

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font: Typography.caption
                                        color: parent.selected ? "#FFFFFF" : Theme.textPrimary
                                    }

                                    TapHandler {
                                        onTapped: {
                                            if (Math.abs(DisplayBackend.currentScale - modelData.val) >= 0.05) {
                                                DisplayBackend.applyScaleWithTimeout(modelData.val, 15);
                                                SettingsManager.setDisplayScale(modelData.val);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Timed Revert Dialog Modal
        Rectangle {
            Layout.fillWidth: true
            radius: 12
            color: Theme.isDark ? "#E61F2026" : "#F2FFFFFF"
            border.color: Theme.accent
            border.width: 2
            visible: DisplayBackend.revertDialogVisible
            implicitHeight: revertCol.implicitHeight + 24

            ColumnLayout {
                id: revertCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Text {
                    text: "Confirm Display Scale Change"
                    font: Typography.headline
                    color: Theme.textPrimary
                }

                Text {
                    text: "Reverting to previous resolution/scale in " + DisplayBackend.revertCountdown + " seconds if not confirmed."
                    font: Typography.body
                    color: Theme.textSecondary
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 10

                    Controls.Button {
                        text: "Revert Now"
                        onClicked: DisplayBackend.revertScaleChange()
                    }

                    Controls.Button {
                        text: "Keep Changes"
                        isDefault: true
                        onClicked: DisplayBackend.confirmScaleChange()
                    }
                }
            }
        }

        Item { height: 20 }
    }
}
