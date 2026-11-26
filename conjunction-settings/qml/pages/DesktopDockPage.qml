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
            text: "Desktop & Dock"
            font: Typography.title
            color: Theme.textPrimary
            Layout.leftMargin: 4
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: "Configure the floating Dock, magnification behavior, and multi-monitor placement."
            font: Typography.body
            color: Theme.textSecondary
            Layout.leftMargin: 4
            wrapMode: Text.Wrap
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
                            Layout.minimumWidth: 0
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: "Dock Size"
                                font: Typography.headline
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: "Base icon and bar height (" + SettingsManager.dockSize + " px)"
                                font: Typography.caption
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                            }
                        }

                        Controls.Slider {
                            Layout.preferredWidth: Math.min(180, Math.round(dockColumn.width * 0.42))
                            from: 16
                            to: 128
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
                            Layout.minimumWidth: 0
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: "Dock Magnification"
                                font: Typography.headline
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: "Magnify icons smoothly on pointer hover"
                                font: Typography.caption
                                color: Theme.textSecondary
                                elide: Text.ElideRight
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
                        Layout.minimumWidth: 0
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: "Display Placement"
                            font: Typography.headline
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: "Which connected displays render the Dock"
                            font: Typography.caption
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                        }
                    }

                    RowLayout {
                        spacing: 8

                        Rectangle {
                            width: Math.min(110, Math.max(88, priTxt.implicitWidth + 16))
                            height: Math.max(32, priTxt.implicitHeight + 12)
                            radius: 6
                            color: SettingsManager.dockDisplayPolicy === "primary" ? Theme.accent : (Theme.isDark ? "#22FFFFFF" : "#15000000")
                            Text {
                                id: priTxt
                                anchors.centerIn: parent
                                width: Math.min(implicitWidth, parent.width - 10)
                                text: "Primary Only"
                                font: Typography.caption
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                color: SettingsManager.dockDisplayPolicy === "primary" ? "#FFFFFF" : Theme.textPrimary
                            }
                            TapHandler {
                                onTapped: SettingsManager.setDockDisplayPolicy("primary")
                            }
                        }

                        Rectangle {
                            width: Math.min(110, Math.max(88, allTxt.implicitWidth + 16))
                            height: Math.max(32, allTxt.implicitHeight + 12)
                            radius: 6
                            color: SettingsManager.dockDisplayPolicy === "all" ? Theme.accent : (Theme.isDark ? "#22FFFFFF" : "#15000000")
                            Text {
                                id: allTxt
                                anchors.centerIn: parent
                                width: Math.min(implicitWidth, parent.width - 10)
                                text: "All Displays"
                                font: Typography.caption
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                color: SettingsManager.dockDisplayPolicy === "all" ? "#FFFFFF" : Theme.textPrimary
                            }
                            TapHandler {
                                onTapped: SettingsManager.setDockDisplayPolicy("all")
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.separator }

                // 5. Minimize Effect (Genie Effect vs Scale Effect, SPEC §3.1)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: 2
                        Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: "Minimize Windows Using"; font: Typography.headline; color: Theme.textPrimary; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: "Genie Effect (425 ms mesh) or Scale Effect (203 ms)"; font: Typography.caption; color: Theme.textSecondary; elide: Text.ElideRight }
                    }
                    Controls.SegmentedControl {
                        Layout.maximumWidth: 160
                        currentIndex: SettingsManager.dockMinimizeEffect === "scale" ? 1 : 0
                        onCurrentIndexChanged: SettingsManager.setDockMinimizeEffect(currentIndex === 1 ? "scale" : "genie")
                        Controls.Segment { text: "Genie" }
                        Controls.Segment { text: "Scale" }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.separator }

                // 6. Hot Corner Bottom-Right (SPEC §5.3 Quick Note default = 14)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: "Bottom-Right Hot Corner"; font: Typography.headline; color: Theme.textPrimary; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: "Action triggered when moving pointer to bottom-right"; font: Typography.caption; color: Theme.textSecondary; elide: Text.ElideRight }
                    }
                    Controls.SegmentedControl {
                        Layout.fillWidth: true
                        currentIndex: SettingsManager.hotCornerBottomRight === 14 ? 0 : (SettingsManager.hotCornerBottomRight === 2 ? 1 : 2)
                        onCurrentIndexChanged: {
                            var codes = [14, 2, 0];
                            SettingsManager.setHotCornerBottomRight(codes[currentIndex] || 0);
                        }
                        Controls.Segment { text: "Quick Note" }
                        Controls.Segment { text: "Mission Control" }
                        Controls.Segment { text: "Off" }
                    }
                }
            }
        }

        Item { height: 20 }
    }
}
