import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls as Controls

// SPEC §4.8 232 pt Glass Sidebar: SearchField, User Profile Row, 4 grouped Navigation sections
Item {
    id: root

    GlassSurface {
        anchors.fill: parent
        variant: "regular"
        cornerRadius: 0
        shadowPreset: "none"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // Top SearchField
        Controls.SearchField {
            Layout.fillWidth: true
            placeholderText: "Search"
            text: SettingsManager.searchQuery
            onTextChanged: SettingsManager.searchQuery = text
        }

        // User Profile Summary Row
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 54
            radius: Geometry.radiusSidebarPill
            color: profHover.hovered ? Theme.controlFillHover : "transparent"
            HoverHandler { id: profHover }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 10

                Rectangle {
                    width: 36; height: 36; radius: 18
                    color: Theme.systemBlue
                    Icon { anchors.centerIn: parent; name: "user"; size: 22; color: "#FFFFFF" }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text { text: "Conjunction User"; font: Typography.headline; color: Theme.labelColor; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { text: "Local Account"; font: Typography.caption1; color: Theme.secondaryLabelColor; elide: Text.ElideRight; Layout.fillWidth: true }
                }
            }
        }

        // Grouped Navigation List
        ListView {
            id: navList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: SettingsManager.pages
            spacing: 2

            section.property: "section"
            section.criteria: ViewSection.FullString
            section.delegate: Item {
                width: navList.width
                height: 18
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    height: 1
                    color: Theme.separatorColor
                }
            }

            delegate: Rectangle {
                width: navList.width
                height: 32
                radius: Geometry.radiusSidebarPill

                property bool isSelected: (SettingsManager.activePage === modelData.id) && (SettingsManager.searchQuery.length === 0)
                color: isSelected ? Theme.systemBlue : (itemHover.hovered ? Theme.controlFillHover : "transparent")
                HoverHandler { id: itemHover }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 9

                    Image {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        sourceSize: Qt.size(20, 20)
                        source: "image://icon/" + modelData.icon
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.title
                        font: isSelected ? Typography.headline : Typography.body
                        color: isSelected ? "#FFFFFF" : Theme.labelColor
                        elide: Text.ElideRight
                    }
                }

                TapHandler {
                    onTapped: {
                        SettingsManager.searchQuery = "";
                        SettingsManager.setActivePage(modelData.id);
                    }
                }
            }
        }
    }
}
