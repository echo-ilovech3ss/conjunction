import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls as Controls

Item {
    id: root
    width: 360
    anchors.top: parent.top
    anchors.topMargin: 38
    anchors.right: parent.right
    anchors.rightMargin: 16
    z: 999
    visible: ShellState.activeBanners.length > 0

    Column {
        width: parent.width
        spacing: 10

        Repeater {
            model: ShellState.activeBanners

            delegate: Rectangle {
                id: bannerCard
                width: 360
                implicitHeight: cardLayout.implicitHeight + 20
                radius: 12
                color: Theme.isDark ? "#EB222329" : "#EBF8FAFC"
                border.color: Theme.isDark ? "#33FFFFFF" : "#20000000"
                border.width: 1

                Behavior on opacity {
                    NumberAnimation { duration: ShellState.reducedMotion ? 50 : 200 }
                }

                ColumnLayout {
                    id: cardLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    // App Name & Close row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Image {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            sourceSize: Qt.size(18, 18)
                            source: modelData.appIcon && modelData.appIcon.length > 0
                                    ? "image://icon/" + modelData.appIcon
                                    : "image://icon/dialog-information"
                            fillMode: Image.PreserveAspectFit
                        }

                        Text {
                            text: modelData.appName || "Notification"
                            font: Typography.caption
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Dismiss button
                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: closeHover.hovered ? (Theme.isDark ? "#33FFFFFF" : "#22000000") : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "?"
                                font.pixelSize: 10
                                color: Theme.textSecondary
                            }

                            HoverHandler { id: closeHover }
                            TapHandler {
                                onTapped: ShellState.dismissNotification(modelData.id)
                            }
                        }
                    }

                    // Summary / Title
                    Text {
                        text: modelData.summary || ""
                        font: Typography.headline
                        color: Theme.textPrimary
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    // Body
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

                    // Action buttons
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: modelData.actions && modelData.actions.length > 1

                        Repeater {
                            model: {
                                var res = [];
                                if (modelData.actions) {
                                    for (var i = 0; i + 1 < modelData.actions.length; i += 2) {
                                        res.push({ key: modelData.actions[i], label: modelData.actions[i + 1] });
                                    }
                                }
                                return res;
                            }

                            delegate: Controls.Button {
                                text: modelData.label
                                sizeClass: "small"
                                onClicked: ShellState.invokeNotificationAction(bannerCard.modelData.id, modelData.key)
                            }
                        }
                    }
                }

                // Click body to trigger default action
                TapHandler {
                    onTapped: ShellState.invokeNotificationAction(modelData.id, "default")
                }
            }
        }
    }
}
