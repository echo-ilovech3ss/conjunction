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

        // Heading & App Icon Hero Card
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 130
            radius: 14
            color: Theme.isDark ? "#1AFFFFFF" : "#0D000000"
            border.color: Theme.separator
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20

                // Operating System Logo / Badge
                Rectangle {
                    width: 72
                    height: 72
                    radius: 18
                    color: Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: "CJ"
                        font.pixelSize: 26
                        font.bold: true
                        color: "#FFFFFF"
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: SystemInfo.osName
                        font: Typography.title
                        color: Theme.textPrimary
                    }

                    Text {
                        text: "Kernel: " + SystemInfo.osKernel
                        font: Typography.body
                        color: Theme.textSecondary
                    }

                    Text {
                        text: "Session: " + SystemInfo.desktopSession
                        font: Typography.caption
                        color: Theme.textSecondary
                    }
                }
            }
        }

        // Hardware Specifications Group
        Text {
            text: "Hardware Specifications"
            font: Typography.headline
            color: Theme.textPrimary
            Layout.leftMargin: 4
        }

        Rectangle {
            Layout.fillWidth: true
            radius: 12
            color: Theme.isDark ? "#14FFFFFF" : "#08000000"
            border.color: Theme.separator
            border.width: 1
            implicitHeight: specColumn.implicitHeight + 20

            ColumnLayout {
                id: specColumn
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // Processor
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Processor"
                        font: Typography.controlLabel
                        color: Theme.textSecondary
                        Layout.preferredWidth: 140
                    }
                    Text {
                        text: SystemInfo.cpuModel
                        font: Typography.body
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.separator }

                // Memory
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Memory"
                        font: Typography.controlLabel
                        color: Theme.textSecondary
                        Layout.preferredWidth: 140
                    }
                    Text {
                        text: SystemInfo.memoryTotal
                        font: Typography.body
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.separator }

                // Graphics
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Graphics"
                        font: Typography.controlLabel
                        color: Theme.textSecondary
                        Layout.preferredWidth: 140
                    }
                    Text {
                        text: SystemInfo.graphicsDevice
                        font: Typography.body
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.separator }

                // Uptime
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "System Uptime"
                        font: Typography.controlLabel
                        color: Theme.textSecondary
                        Layout.preferredWidth: 140
                    }
                    Text {
                        text: SystemInfo.uptime
                        font: Typography.body
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }
                }
            }
        }

        Item { height: 20 }
    }
}
