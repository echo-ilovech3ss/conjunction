import QtQuick
import QtQuick.Layouts
import Conjunction.Design

// SPEC §4.5 App Switcher HUD (Cmd+Tab): 72 pt tiles, 10 pt selection highlight box, 11 pt active name
Item {
    id: root
    property Item backdropItem: null

    readonly property var items: ShellState.dockItems || []
    width: Math.max(220, switcherRow.implicitWidth + 44)
    height: 138

    GlassSurface {
        anchors.fill: parent
        variant: "clear"
        cornerRadius: 26
        shadowPreset: "window"
        backdropItem: root.backdropItem

        Row {
            id: switcherRow
            anchors.centerIn: parent
            spacing: 12

            Repeater {
                model: root.items
                delegate: Column {
                    width: 86
                    spacing: 6
                    readonly property bool selected: index === ShellState.appSwitcherIndex

                    Item {
                        width: 82; height: 82
                        anchors.horizontalCenter: parent.horizontalCenter

                        // SPEC §4.5: 10 pt highlight box
                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            visible: selected
                            color: Appearance.isDark ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.12)
                            border.width: 2
                            border.color: Theme.systemBlue
                        }

                        // 72 pt app icon tile
                        Rectangle {
                            anchors.centerIn: parent
                            width: 72; height: 72; radius: 16
                            color: modelData.id === "org.conjunction.files" ? "#1E88E5"
                                : modelData.id === "org.conjunction.terminal" ? "#26282C"
                                : modelData.id === "org.conjunction.settings" ? "#6E737D"
                                : Theme.systemBlue
                            Icon { anchors.centerIn: parent; name: modelData.icon || "applications"; size: 38; color: "#FFFFFF" }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                ShellState.appSwitcherIndex = index;
                                ShellState.commitAppSwitcher();
                            }
                        }
                    }

                    Text {
                        visible: selected
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.name || modelData.id
                        color: Theme.labelColor
                        font: Typography.subheadlineBold
                        elide: Text.ElideRight
                        width: 86
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
