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
        spacing: 16

        Item { height: 12 }

        Text {
            Layout.fillWidth: true
            text: "Search Results (" + SettingsManager.searchResults.length + ")"
            font: Typography.title
            color: Theme.textPrimary
            Layout.leftMargin: 4
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: "Showing matching system settings for \"" + SettingsManager.searchQuery + "\""
            font: Typography.body
            color: Theme.textSecondary
            Layout.leftMargin: 4
            wrapMode: Text.Wrap
        }

        // Empty state
        Rectangle {
            Layout.fillWidth: true
            height: 120
            radius: 12
            color: Theme.isDark ? "#14FFFFFF" : "#08000000"
            border.color: Theme.separator
            border.width: 1
            visible: SettingsManager.searchResults.length === 0

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: "No Settings Found"
                    font: Typography.headline
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    Layout.fillWidth: true
                    text: "Try searching for \"dark\", \"wifi\", \"dock zoom\", or \"volume\"."
                    font: Typography.caption
                    color: Theme.textSecondary
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // Results list
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: SettingsManager.searchResults.length > 0

            Repeater {
                model: SettingsManager.searchResults
                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 56
                    radius: 10
                    color: itemHover.hovered ? (Theme.isDark ? "#22FFFFFF" : "#12000000") : (Theme.isDark ? "#14FFFFFF" : "#08000000")
                    border.color: Theme.separator
                    border.width: 1

                    HoverHandler { id: itemHover }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 14

                        Image {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            sourceSize: Qt.size(28, 28)
                            source: "image://icon/" + modelData.icon
                            fillMode: Image.PreserveAspectFit
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: modelData.title
                                font: Typography.headline
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                            }
                            Text {
                                text: modelData.section + " • " + modelData.description
                                font: Typography.caption
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: "→"
                            font.bold: true
                            color: Theme.accent
                        }
                    }

                    TapHandler {
                        onTapped: {
                            SettingsManager.searchQuery = ""
                            SettingsManager.navigateTo(modelData.page, modelData.id)
                        }
                    }
                }
            }
        }

        Item { height: 20 }
    }
}
