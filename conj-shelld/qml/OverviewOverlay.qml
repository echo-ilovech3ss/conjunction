import QtQuick
import QtQuick.Layouts
import Conjunction.Design

// SPEC §4.4 Mission Control: 525 ms enter transition, 135 pt Spaces bar, decluttered 16 pt window cards
Item {
    id: root
    property Item backdropItem: null

    opacity: ShellState.overviewActive ? 1.0 : 0.0
    Behavior on opacity {
        NumberAnimation {
            duration: Motion.duration(ShellState.overviewActive ? Motion.missionControlEnter : Motion.missionControlExit)
            easing.type: Easing.OutCubic
        }
    }

    // Subtle dark scrim behind overview
    Rectangle {
        anchors.fill: parent
        color: Appearance.isDark ? Qt.rgba(0.05, 0.06, 0.09, 0.52) : Qt.rgba(0.06, 0.08, 0.14, 0.36)
        MouseArea { anchors.fill: parent; onClicked: ShellState.overviewActive = false }
    }

    // 1. Top 135 pt Spaces Strip (SPEC §4.4)
    GlassSurface {
        id: spacesStrip
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 135
        variant: "regular"
        cornerRadius: 0
        shadowPreset: "pill"
        backdropItem: root.backdropItem

        RowLayout {
            anchors.centerIn: parent
            spacing: 24

            Repeater {
                model: [
                    { "name": "Desktop 1", "active": true },
                    { "name": "Desktop 2", "active": false }
                ]
                delegate: Column {
                    spacing: 6
                    Rectangle {
                        width: 148; height: 88; radius: 10
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Appearance.isDark ? "#1B2E4B" : "#569CD6" }
                            GradientStop { position: 1.0; color: Appearance.isDark ? "#2E1C47" : "#89C4F4" }
                        }
                        border.width: modelData.active ? 2.5 : 1
                        border.color: modelData.active ? "#FFFFFF" : Qt.rgba(1,1,1,0.3)
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 140
                        text: modelData.name
                        color: "#FFFFFF"
                        font: Typography.subheadlineBold
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Add Space button
            Rectangle {
                width: 44; height: 88; radius: 10
                color: Qt.rgba(1, 1, 1, 0.14)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.25)
                Icon { anchors.centerIn: parent; name: "plus"; size: 22; color: "#FFFFFF" }
            }
        }
    }

    // 2. Window Exposé Cards (16 pt continuous corners, SPEC §4.4)
    GridLayout {
        anchors.top: spacesStrip.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 48
        columns: 2
        rowSpacing: 32
        columnSpacing: 32

        Repeater {
            model: ShellState.dockItems
            delegate: Item {
                visible: !!modelData.running
                Layout.fillWidth: true
                Layout.fillHeight: true

                GlassSurface {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, 460)
                    height: Math.min(parent.height, 270)
                    variant: "clear"
                    cornerRadius: 16
                    shadowPreset: "window"
                    backdropItem: root.backdropItem

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        // Simulated clean window chrome preview
                        RowLayout {
                            Layout.fillWidth: true
                            TrafficLights { active: !!modelData.active }
                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: modelData.name || modelData.id
                                color: Theme.labelColor
                                font: Typography.headline
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Item { width: 52 }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 10
                            color: Appearance.isDark ? Qt.rgba(0.14, 0.15, 0.18, 0.88) : Qt.rgba(1, 1, 1, 0.88)
                            Icon {
                                anchors.centerIn: parent
                                name: modelData.icon || "applications"
                                size: 48
                                color: Theme.systemBlue
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: "transparent"
                        border.width: cardHover.containsMouse ? 2 : 0
                        border.color: Theme.systemBlue
                    }

                    MouseArea {
                        id: cardHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            ShellState.overviewActive = false;
                            ShellState.focusApp(modelData.id);
                        }
                    }
                }
            }
        }
    }
}
