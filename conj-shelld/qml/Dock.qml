import QtQuick
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls as Controls

Rectangle {
    id: root
    height: 68
    width: dockRow.width + 24
    radius: 18

    color: Theme.isDark ? "#D9202229" : "#E6FFFFFF"
    border.color: Theme.separator
    border.width: 1

    // Slide down / hide on true fullscreen
    visible: !ShellState.isFullscreen
    opacity: ShellState.isFullscreen ? 0.0 : 1.0
    Behavior on opacity {
        NumberAnimation { duration: 150 }
    }

    property int focusedIndex: -1

    // Keyboard navigation
    focus: true
    Keys.onLeftPressed: {
        if (focusedIndex > 0) focusedIndex--;
        else focusedIndex = ShellState.dockItems.length - 1;
    }
    Keys.onRightPressed: {
        if (focusedIndex < ShellState.dockItems.length - 1) focusedIndex++;
        else focusedIndex = 0;
    }
    Keys.onReturnPressed: {
        if (focusedIndex >= 0 && focusedIndex < ShellState.dockItems.length) {
            var item = ShellState.dockItems[focusedIndex];
            ShellState.focusApp(item.id);
        }
    }
    Keys.onEscapePressed: {
        root.focus = false;
        focusedIndex = -1;
    }

    Row {
        id: dockRow
        anchors.centerIn: parent
        spacing: 10

        Repeater {
            id: dockRepeater
            model: ShellState.dockItems

            Item {
                id: dockItemDelegate
                width: 52
                height: 58
                property bool isHovered: itemHover.hovered
                property bool isKeySelected: root.focusedIndex === index

                // Magnification preparation: dynamic scale property
                property real targetScale: isHovered ? 1.15 : 1.0
                scale: targetScale
                Behavior on scale {
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                }

                // Keyboard selection focus ring
                Rectangle {
                    anchors.centerIn: parent
                    width: 50
                    height: 50
                    radius: 12
                    color: "transparent"
                    border.color: Theme.accent
                    border.width: 2
                    visible: dockItemDelegate.isKeySelected
                }

                // App Icon Container (Square with smooth rounded corners)
                Rectangle {
                    id: iconBox
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 46
                    height: 46
                    radius: 10
                    color: {
                        if (modelData.id.indexOf("gallery") !== -1) return "#3478F6";
                        if (modelData.id.indexOf("reference") !== -1) return "#28CD41";
                        if (modelData.id.indexOf("files") !== -1) return "#5856D6";
                        if (modelData.id.indexOf("terminal") !== -1) return "#3A3A3C";
                        if (modelData.id.indexOf("firefox") !== -1) return "#FF9500";
                        return Theme.surface;
                    }
                    border.color: Theme.separator
                    border.width: 1

                    Icon {
                        anchors.centerIn: parent
                        name: {
                            var ic = modelData.icon || "";
                            if (ic === "gallery") return "sparkle";
                            if (ic === "desktop") return "check";
                            if (ic === "folder") return "folder";
                            if (ic === "terminal") return "terminal";
                            return "gear";
                        }
                        size: 24
                        color: "#FFFFFF"
                    }
                }

                // Running Indicator (Mac-inspired bottom dot)
                Rectangle {
                    id: runningDot
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 4
                    height: 4
                    radius: 2
                    visible: modelData.running
                    color: modelData.active ? Theme.accent : Theme.textSecondary
                }

                // Multi-window count pill badge
                Rectangle {
                    visible: modelData.windowCount > 1
                    anchors.top: iconBox.top
                    anchors.right: iconBox.right
                    anchors.topMargin: -4
                    anchors.rightMargin: -4
                    width: countText.implicitWidth + 8
                    height: 16
                    radius: 8
                    color: Theme.accent

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: modelData.windowCount.toString()
                        font: Typography.caption
                        color: "#FFFFFF"
                    }
                }

                // Hover / Click Handlers
                HoverHandler { id: itemHover }

                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onTapped: {
                        ShellState.focusApp(modelData.id);
                    }
                }

                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: {
                        dockContextMenu.popup();
                    }
                }

                // Delayed ToolTip with App Name
                Controls.ToolTip {
                    text: modelData.name || modelData.id
                    visible: itemHover.hovered && !dockContextMenu.visible
                    delay: 250
                }

                // Dock Item Context Menu
                Controls.ContextMenu {
                    id: dockContextMenu

                    Controls.MenuItem {
                        text: modelData.running ? "Show" : "Open"
                        iconName: "check"
                        onTriggered: ShellState.focusApp(modelData.id)
                    }

                    Controls.MenuSeparator {}

                    Controls.MenuItem {
                        text: modelData.pinned ? "Remove from Dock" : "Keep in Dock"
                        iconName: modelData.pinned ? "close" : "add"
                        onTriggered: {
                            if (modelData.pinned) ShellState.unpinApp(modelData.id);
                            else ShellState.pinApp(modelData.id);
                        }
                    }

                    Controls.MenuItem {
                        text: "Close Window"
                        iconName: "close"
                        visible: modelData.running
                        isDestructive: true
                        onTriggered: ShellState.quitApp(modelData.id)
                    }
                }
            }
        }
    }
}
