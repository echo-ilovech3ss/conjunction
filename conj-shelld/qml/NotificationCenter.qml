import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls as Controls

Rectangle {
    id: root
    width: 380
    anchors.top: parent.top
    anchors.topMargin: 30
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 12
    anchors.right: parent.right
    anchors.rightMargin: ShellState.notificationCenterVisible ? 12 : -width - 20
    radius: 16
    z: 950
    clip: true

    color: Theme.isDark ? "#F01E1F25" : "#F0F8FAFC"
    border.color: Theme.separator
    border.width: 1

    Behavior on anchors.rightMargin {
        NumberAnimation {
            duration: ShellState.reducedMotion ? 50 : 250
            easing.type: Easing.OutCubic
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Notifications"
                font: Typography.title
                color: Theme.textPrimary
                Layout.fillWidth: true
            }

            Controls.Button {
                text: "Clear All"
                sizeClass: "small"
                visible: ShellState.notificationHistory.length > 0
                onClicked: ShellState.clearNotificationHistory()
            }

            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: closeHover.hovered ? (Theme.isDark ? "#33FFFFFF" : "#20000000") : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "?"
                    font.pixelSize: 12
                    color: Theme.textSecondary
                }

                HoverHandler { id: closeHover }
                TapHandler {
                    onTapped: ShellState.toggleNotificationCenter()
                }
            }
        }

        // Focus / Do Not Disturb quick card
        Rectangle {
            Layout.fillWidth: true
            height: 48
            radius: 10
            color: Theme.isDark ? "#1AFFFFFF" : "#0D000000"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12

                Text {
                    text: "??"
                    font.pixelSize: 16
                }

                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true

                    Text {
                        text: "Do Not Disturb"
                        font: Typography.body
                        color: Theme.textPrimary
                    }
                    Text {
                        text: ShellState.doNotDisturb ? "Banners muted" : "Normal alerts"
                        font: Typography.caption
                        color: Theme.textSecondary
                    }
                }

                Controls.Switch {
                    checked: ShellState.doNotDisturb
                    onToggled: ShellState.toggleDoNotDisturb()
                }
            }
        }

        // Empty state
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: ShellState.notificationHistory.length === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: "??"
                    font.pixelSize: 32
                    Layout.alignment: Qt.AlignHCenter
                    opacity: 0.6
                }

                Text {
                    text: "No New Notifications"
                    font: Typography.body
                    color: Theme.textSecondary
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // History list
        ListView {
            id: historyList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: ShellState.notificationHistory.length > 0
            model: ShellState.notificationHistory
            spacing: 8

            delegate: Rectangle {
                id: itemCard
                width: historyList.width
                implicitHeight: itemLayout.implicitHeight + 20
                radius: 10
                color: Theme.isDark ? "#22FFFFFF" : "#10000000"
                border.color: Theme.separator
                border.width: 1

                ColumnLayout {
                    id: itemLayout
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true

                        Image {
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            sourceSize: Qt.size(16, 16)
                            source: modelData.appIcon && modelData.appIcon.length > 0
                                    ? "image://icon/" + modelData.appIcon
                                    : "image://icon/dialog-information"
                            fillMode: Image.PreserveAspectFit
                        }

                        Text {
                            text: modelData.appName || "Notification"
                            font: Typography.caption
                            color: Theme.textSecondary
                            Layout.fillWidth: true
                        }

                        Text {
                            text: {
                                var elapsed = (Date.now() - modelData.timestamp) / 1000;
                                if (elapsed < 60) return "Just now";
                                if (elapsed < 3600) return Math.floor(elapsed / 60) + "m ago";
                                return Math.floor(elapsed / 3600) + "h ago";
                            }
                            font: Typography.caption
                            color: Theme.textSecondary
                        }

                        Rectangle {
                            width: 16
                            height: 16
                            radius: 8
                            color: delHover.hovered ? (Theme.isDark ? "#33FFFFFF" : "#22000000") : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "?"
                                font.pixelSize: 9
                                color: Theme.textSecondary
                            }

                            HoverHandler { id: delHover }
                            TapHandler {
                                onTapped: ShellState.dismissNotification(modelData.id)
                            }
                        }
                    }

                    Text {
                        text: modelData.summary || ""
                        font: Typography.headline
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }

                    Text {
                        text: modelData.body || ""
                        font: Typography.body
                        color: Theme.textPrimary
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        visible: modelData.body && modelData.body.length > 0
                    }
                }

                TapHandler {
                    onTapped: ShellState.invokeNotificationAction(modelData.id, "default")
                }
            }
        }
    }
}
