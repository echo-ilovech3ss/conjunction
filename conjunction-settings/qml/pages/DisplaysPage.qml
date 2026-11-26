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
            text: "Displays"
            font: Typography.title
            color: Theme.textPrimary
            Layout.leftMargin: 4
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: "Resolution, UI scaling, and multi-monitor output configuration."
            font: Typography.body
            color: Theme.textSecondary
            Layout.leftMargin: 4
            wrapMode: Text.Wrap
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
                        Layout.minimumWidth: 0
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: "Primary Display"
                            font: Typography.headline
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: DisplayBackend.primaryResolution + " @ " + DisplayBackend.primaryRefreshRate
                            font: Typography.caption
                            color: Theme.textSecondary
                            elide: Text.ElideRight
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
                            Layout.minimumWidth: 0
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: "Display Scale"
                                font: Typography.headline
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: "Scale text and controls for high-density monitors"
                                font: Typography.caption
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                            }
                        }

                        Flow {
                            Layout.maximumWidth: 260
                            spacing: 6

                            Repeater {
                                model: [
                                    { label: "100%", val: 1.0 },
                                    { label: "125%", val: 1.25 },
                                    { label: "150%", val: 1.5 },
                                    { label: "200%", val: 2.0 }
                                ]
                                delegate: Rectangle {
                                    width: Math.max(54, scaleLbl.implicitWidth + 14)
                                    height: 30
                                    radius: 6
                                    property bool selected: Math.abs(DisplayBackend.currentScale - modelData.val) < 0.05
                                    color: selected ? Theme.accent : (Theme.isDark ? "#22FFFFFF" : "#15000000")

                                    Text {
                                        id: scaleLbl
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
                    Layout.fillWidth: true
                    text: "Confirm Display Scale Change"
                    font: Typography.headline
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: "Reverting to previous resolution/scale in " + DisplayBackend.revertCountdown + " seconds if not confirmed."
                    font: Typography.body
                    color: Theme.textSecondary
                    wrapMode: Text.Wrap
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
