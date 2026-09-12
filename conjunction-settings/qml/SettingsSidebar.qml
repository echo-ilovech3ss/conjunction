import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls as Controls

Rectangle {
    id: root
    color: Theme.isDark ? "#E61A1B20" : "#E6F0F4F8"
    border.color: Theme.separator
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // Top Search Field
        Rectangle {
            Layout.fillWidth: true
            height: 34
            radius: 8
            color: Theme.isDark ? "#22FFFFFF" : "#14000000"
            border.color: searchInput.activeFocus ? Theme.accent : Theme.separator
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                Text {
                    text: "🔍"
                    font.pixelSize: 12
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    font: Typography.body
                    color: Theme.textPrimary
                    selectByMouse: true
                    text: SettingsManager.searchQuery
                    onTextChanged: SettingsManager.searchQuery = text

                    Text {
                        anchors.fill: parent
                        text: "Search Settings"
                        font: searchInput.font
                        color: Theme.textPlaceholder
                        visible: !searchInput.text && !searchInput.inputMethodComposing
                    }
                }

                Text {
                    text: "✕"
                    font.pixelSize: 10
                    color: Theme.textSecondary
                    visible: !searchInput.text.length == 0
                    TapHandler {
                        onTapped: searchInput.text = ""
                    }
                }
            }
        }

        // Sidebar Navigation List
        ListView {
            id: navList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: SettingsManager.pages
            spacing: 4

            delegate: Rectangle {
                width: navList.width
                height: 38
                radius: 8

                property bool isSelected: (SettingsManager.activePage === modelData.id) && (SettingsManager.searchQuery.length === 0)
                color: isSelected ? Theme.accent : (itemHover.hovered ? (Theme.isDark ? "#1AFFFFFF" : "#10000000") : "transparent")

                HoverHandler { id: itemHover }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Image {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        sourceSize: Qt.size(22, 22)
                        source: "image://icon/" + modelData.icon
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        text: modelData.title
                        font: Typography.headline
                        color: isSelected ? "#FFFFFF" : Theme.textPrimary
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                TapHandler {
                    onTapped: {
                        SettingsManager.searchQuery = ""
                        SettingsManager.navigateTo(modelData.id)
                    }
                }
            }
        }
    }
}
