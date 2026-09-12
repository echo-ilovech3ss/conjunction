import QtQuick
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls as Controls

Item {
    id: root
    anchors.fill: parent
    visible: ShellState.spotlightVisible
    z: 200

    property int selectedIndex: 0

    onVisibleChanged: {
        if (visible) {
            searchInput.text = ShellState.searchQuery;
            searchInput.forceActiveFocus();
            selectedIndex = 0;
        }
    }

    // Semi-transparent backdrop to focus attention on search
    Rectangle {
        anchors.fill: parent
        color: "#40000000"
        opacity: root.visible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
        TapHandler {
            onTapped: ShellState.spotlightVisible = false
        }
    }

    // Floating Spotlight Dialog
    Rectangle {
        id: searchCard
        width: 620
        height: Math.min(520, headerRow.height + resultsList.contentHeight + 24)
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.16
        radius: 16

        color: Theme.isDark ? "#E61F2026" : "#F2FFFFFF"
        border.color: Theme.separator
        border.width: 1

        // Drop shadow illusion
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: 17
            color: "transparent"
            border.color: Theme.isDark ? "#33FFFFFF" : "#1A000000"
            border.width: 1
            z: -1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Top Search Input Box
            RowLayout {
                id: headerRow
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                spacing: 10

                Icon {
                    name: "search"
                    size: 20
                    color: Theme.accent
                    Layout.leftMargin: 6
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    font: Typography.title
                    color: Theme.textPrimary
                    clip: true
                    focus: true
                    selectByMouse: true

                    Text {
                        anchors.fill: parent
                        text: "Search apps, settings, actions, and files..."
                        font: searchInput.font
                        color: Theme.textPlaceholder
                        visible: !searchInput.text && !searchInput.inputMethodComposing
                    }

                    onTextChanged: {
                        ShellState.searchQuery = text;
                        root.selectedIndex = 0;
                    }

                    Keys.onDownPressed: {
                        if (root.selectedIndex < ShellState.searchResults.length - 1) {
                            root.selectedIndex++;
                        }
                    }
                    Keys.onUpPressed: {
                        if (root.selectedIndex > 0) {
                            root.selectedIndex--;
                        }
                    }
                    Keys.onReturnPressed: {
                        ShellState.activateSearchResult(root.selectedIndex);
                    }
                    Keys.onEscapePressed: {
                        ShellState.spotlightVisible = false;
                    }
                }

                // Clear button
                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    color: clearHover.hovered ? (Theme.isDark ? "#33FFFFFF" : "#20000000") : "transparent"
                    visible: searchInput.text.length > 0
                    Layout.rightMargin: 4

                    Icon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 12
                        color: Theme.textSecondary
                    }
                    HoverHandler { id: clearHover }
                    TapHandler {
                        onTapped: {
                            searchInput.text = "";
                            ShellState.searchQuery = "";
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.separator
            }

            // Results List
            ListView {
                id: resultsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: ShellState.searchResults
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: resultDelegate
                    width: resultsList.width
                    height: 48
                    radius: 8

                    property bool isSelected: root.selectedIndex === index
                    color: isSelected ? (Theme.isDark ? "#2AFFFFFF" : "#1A0066CC") : (delegateHover.hovered ? (Theme.isDark ? "#1AFFFFFF" : "#0D000000") : "transparent")

                    // Selection left accent bar
                    Rectangle {
                        width: 3
                        height: 24
                        radius: 1.5
                        color: Theme.accent
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        visible: resultDelegate.isSelected
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 14
                        spacing: 12

                        // Icon Container
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 7
                            color: {
                                if (modelData.category === "Applications") return "#3478F6";
                                if (modelData.category === "Settings & Actions") return "#5856D6";
                                return "#8E8E93";
                            }
                            Layout.alignment: Qt.AlignVCenter

                            Icon {
                                anchors.centerIn: parent
                                name: modelData.icon || "application-x-executable"
                                size: 18
                                color: "#FFFFFF"
                            }
                        }

                        // Title & Subtitle
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                text: modelData.title || ""
                                font: Typography.controlLabel
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: modelData.subtitle || ""
                                font: Typography.caption
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Category Pill Badge
                        Rectangle {
                            height: 20
                            width: catText.implicitWidth + 12
                            radius: 10
                            color: Theme.isDark ? "#26FFFFFF" : "#1A000000"
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                id: catText
                                anchors.centerIn: parent
                                text: modelData.category || ""
                                font: Typography.caption
                                color: Theme.textSecondary
                            }
                        }
                    }

                    HoverHandler {
                        id: delegateHover
                        onHoveredChanged: {
                            if (hovered) root.selectedIndex = index;
                        }
                    }

                    TapHandler {
                        onTapped: {
                            ShellState.activateSearchResult(index);
                        }
                    }
                }
            }
        }
    }
}
