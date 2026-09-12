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
            text: "Default Applications"
            font: Typography.title
            color: Theme.textPrimary
            Layout.leftMargin: 4
        }

        Text {
            text: "Choose the default applications for web browsing, terminal, files, and media."
            font: Typography.body
            color: Theme.textSecondary
            Layout.leftMargin: 4
        }

        // Card containing categories
        Rectangle {
            Layout.fillWidth: true
            radius: 12
            color: Theme.isDark ? "#14FFFFFF" : "#08000000"
            border.color: Theme.separator
            border.width: 1
            implicitHeight: categoriesColumn.implicitHeight + 24

            ColumnLayout {
                id: categoriesColumn
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Repeater {
                    model: SettingsManager.defaultAppCategories

                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            // Category Icon & Name
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Image {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    sourceSize: Qt.size(24, 24)
                                    source: "image://icon/" + modelData.icon
                                    fillMode: Image.PreserveAspectFit
                                }

                                ColumnLayout {
                                    spacing: 2
                                    Text {
                                        text: modelData.title
                                        font: Typography.headline
                                        color: Theme.textPrimary
                                    }
                                    Text {
                                        text: modelData.mime
                                        font: Typography.caption
                                        color: Theme.textSecondary
                                    }
                                }
                            }

                            // Current Selection Button / Menu
                            Rectangle {
                                id: selectorButton
                                Layout.preferredWidth: 180
                                Layout.preferredHeight: 32
                                radius: 6
                                color: selectHover.hovered ? (Theme.isDark ? "#2AFFFFFF" : "#1A000000") : (Theme.isDark ? "#1AFFFFFF" : "#10000000")
                                border.color: Theme.separator
                                border.width: 1

                                HoverHandler { id: selectHover }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Text {
                                        text: modelData.currentName
                                        font: Typography.caption
                                        color: Theme.textPrimary
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: "▼"
                                        font.pixelSize: 8
                                        color: Theme.textSecondary
                                    }
                                }

                                TapHandler {
                                    onTapped: {
                                        appMenu.targetMime = modelData.mime
                                        appMenu.appHandlers = SettingsManager.getAvailableHandlers(modelData.mime)
                                        appMenu.open()
                                    }
                                }
                            }
                        }

                        // Separator between categories
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.separator
                            visible: index < (SettingsManager.defaultAppCategories.length - 1)
                        }
                    }
                }
            }
        }

        Item { height: 20 }
    }

    // Popup menu for app selection
    Menu {
        id: appMenu
        property string targetMime: ""
        property var appHandlers: []

        Repeater {
            model: appMenu.appHandlers
            delegate: MenuItem {
                text: modelData.name
                icon.name: modelData.icon
                onTriggered: {
                    SettingsManager.setDefaultHandler(appMenu.targetMime, modelData.desktopId)
                }
            }
        }
    }
}
