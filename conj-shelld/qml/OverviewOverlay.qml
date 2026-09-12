import QtQuick
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls as Controls

Item {
    id: root
    anchors.fill: parent
    visible: ShellState.overviewActive
    z: 150

    property int selectedIndex: 0

    onVisibleChanged: {
        if (visible) {
            selectedIndex = 0;
            root.forceActiveFocus();
        }
    }

    focus: visible
    Keys.onEscapePressed: ShellState.overviewActive = false
    Keys.onLeftPressed: {
        if (selectedIndex > 0) selectedIndex--;
    }
    Keys.onRightPressed: {
        if (selectedIndex < openWindowsModel.count - 1) selectedIndex++;
    }
    Keys.onReturnPressed: {
        if (selectedIndex >= 0 && selectedIndex < openWindowsModel.count) {
            var item = openWindowsModel.get(selectedIndex);
            ShellState.activateWindow(item.winId);
            ShellState.overviewActive = false;
        }
    }

    // Dark frosted backdrop
    Rectangle {
        anchors.fill: parent
        color: Theme.isDark ? "#D914151B" : "#D92D3748"
        TapHandler {
            onTapped: ShellState.overviewActive = false
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20

        // Spaces Bar Across Top
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            Rectangle {
                width: 140
                height: 32
                radius: 8
                color: Theme.accent
                Text {
                    anchors.centerIn: parent
                    text: "Desktop 1"
                    font: Typography.controlLabel
                    color: "#FFFFFF"
                }
            }

            Rectangle {
                width: 140
                height: 32
                radius: 8
                color: Theme.isDark ? "#28FFFFFF" : "#1AFFFFFF"
                border.color: Theme.separator
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "+ New Space"
                    font: Typography.controlLabel
                    color: Theme.textSecondary
                }
            }
        }

        // Window Cards Grid
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Row {
                anchors.centerIn: parent
                spacing: 24

                Repeater {
                    id: winRepeater
                    model: openWindowsModel

                    Rectangle {
                        id: windowCard
                        width: 340
                        height: 240
                        radius: 12
                        color: Theme.isDark ? "#2A202228" : "#F8FAFC"
                        border.color: root.selectedIndex === index ? Theme.accent : (cardHover.hovered ? Theme.textSecondary : Theme.separator)
                        border.width: root.selectedIndex === index ? 3 : 1

                        property bool isSelected: root.selectedIndex === index

                        // Header with App Icon & Title
                        Rectangle {
                            id: cardHeader
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 38
                            radius: 12
                            color: "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 8

                                Rectangle {
                                    width: 22
                                    height: 22
                                    radius: 5
                                    color: Theme.accent
                                    Icon {
                                        anchors.centerIn: parent
                                        name: model.icon || "application-x-executable"
                                        size: 14
                                        color: "#FFFFFF"
                                    }
                                }

                                Text {
                                    text: model.title
                                    font: Typography.controlLabel
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        // Window Live Thumbnail Canvas Area
                        Rectangle {
                            anchors.top: cardHeader.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 10
                            radius: 8
                            color: Theme.isDark ? "#16171B" : "#E2E8F0"
                            clip: true

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                Icon {
                                    Layout.alignment: Qt.AlignHCenter
                                    name: "window"
                                    size: 36
                                    color: Theme.textSecondary
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: model.appName
                                    font: Typography.caption
                                    color: Theme.textSecondary
                                }
                            }
                        }

                        HoverHandler {
                            id: cardHover
                            onHoveredChanged: {
                                if (hovered) root.selectedIndex = index;
                            }
                        }

                        TapHandler {
                            onTapped: {
                                ShellState.activateWindow(model.winId);
                                ShellState.overviewActive = false;
                            }
                        }
                    }
                }
            }
        }
    }

    ListModel {
        id: openWindowsModel

        ListElement {
            winId: "1001"
            appName: "Desktop Reference"
            title: "Conjunction Reference App — Main Window"
            icon: "preferences-desktop-theme"
        }
        ListElement {
            winId: "1002"
            appName: "Firefox"
            title: "Mozilla Firefox — Start Page"
            icon: "network"
        }
    }
}
