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
            text: "Keyboard Shortcuts"
            font: Typography.title
            color: Theme.textPrimary
            Layout.leftMargin: 4
        }

        Text {
            text: "View and customize system shortcuts and window management hotkeys."
            font: Typography.body
            color: Theme.textSecondary
            Layout.leftMargin: 4
        }

        // Shortcuts List Card
        Rectangle {
            Layout.fillWidth: true
            radius: 12
            color: Theme.isDark ? "#14FFFFFF" : "#08000000"
            border.color: Theme.separator
            border.width: 1
            implicitHeight: shortcutsColumn.implicitHeight + 24

            ColumnLayout {
                id: shortcutsColumn
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Repeater {
                    model: SettingsManager.shortcuts

                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: modelData.title
                                    font: Typography.headline
                                    color: Theme.textPrimary
                                }

                                Text {
                                    text: modelData.category
                                    font: Typography.caption
                                    color: Theme.textSecondary
                                }
                            }

                            // Shortcut Badge / Pill
                            Rectangle {
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: Math.max(80, shortcutText.implicitWidth + 20)
                                radius: 6
                                color: Theme.isDark ? "#2AFFFFFF" : "#1A000000"
                                border.color: Theme.separator
                                border.width: 1

                                Text {
                                    id: shortcutText
                                    anchors.centerIn: parent
                                    text: modelData.shortcut
                                    font: Typography.caption
                                    color: Theme.accent
                                }
                            }
                        }

                        // Separator between rows
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.separator
                            visible: index < (SettingsManager.shortcuts.length - 1)
                        }
                    }
                }
            }
        }

        // Restore Defaults Button
        RowLayout {
            Layout.fillWidth: true

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredHeight: 32
                Layout.preferredWidth: 140
                radius: 6
                color: btnHover.hovered ? (Theme.isDark ? "#2AFFFFFF" : "#1A000000") : (Theme.isDark ? "#1AFFFFFF" : "#10000000")
                border.color: Theme.separator
                border.width: 1

                HoverHandler { id: btnHover }

                Text {
                    anchors.centerIn: parent
                    text: "Restore Defaults"
                    font: Typography.caption
                    color: Theme.textPrimary
                }

                TapHandler {
                    onTapped: SettingsManager.resetShortcuts()
                }
            }
        }

        Item { height: 20 }
    }
}
