import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Conjunction.Design

Item {
    id: root
    property Item backdropItem: null
    height: ShellState.notchBar ? 39 : 28 // SPEC §4.1: 39 pt notched / 28 pt standard

    property int openMenuIndex: -2 // -1 = System Menu, 0..N = Global Menu
    property var activeMenuChildren: []
    property real activeMenuX: 16

    function closeMenus() {
        openMenuIndex = -2;
        activeMenuChildren = [];
    }

    Timer {
        id: menuHideDelay
        interval: 200 // SPEC §4.1: 200 ms hide delay
        onTriggered: {
            if (!menuPopupHover.containsMouse && !barHover.containsMouse) {
                root.closeMenus();
            }
        }
    }

    MouseArea {
        id: barHover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onExited: menuHideDelay.restart()
    }

    // SPEC §4.1 Liquid Glass Menu Bar backdrop
    GlassSurface {
        anchors.fill: parent
        variant: "regular"
        cornerRadius: 0
        shadowPreset: "none"
        backdropItem: root.backdropItem

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.separatorColor
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 2

        // 1. Conjunction System Mark Button (SPEC §4.1: 20x20 monochrome emblem)
        Item {
            id: systemBtn
            Layout.preferredWidth: 36
            Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: root.openMenuIndex === -1
                    ? (Appearance.isDark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.10))
                    : (sysArea.containsMouse ? (Appearance.isDark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)) : "transparent")
                Behavior on color { ColorAnimation { duration: Motion.hoverSwap } }
            }

            Image {
                id: markImg
                anchors.centerIn: parent
                width: 18
                height: 18
                sourceSize.width: 36
                sourceSize.height: 36
                source: Qt.resolvedUrl("assets/conjunction-mark.svg")
                visible: false
            }

            MultiEffect {
                anchors.fill: markImg
                source: markImg
                colorization: 1.0
                colorizationColor: Theme.labelColor
                brightness: 1.0
            }

            MouseArea {
                id: sysArea
                anchors.fill: parent
                hoverEnabled: true
                onEntered: {
                    if (root.openMenuIndex !== -2 && root.openMenuIndex !== -1) {
                        root.openSystemMenu();
                    }
                }
                onClicked: {
                    if (root.openMenuIndex === -1) root.closeMenus();
                    else root.openSystemMenu();
                }
            }
        }

        // 2. Active Application Title (Bold 13pt, 16pt padding visual separation)
        Item {
            id: appTitleBtn
            Layout.preferredWidth: appTitleText.implicitWidth + 20
            Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: appTitleArea.containsMouse
                    ? (Appearance.isDark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06))
                    : "transparent"
            }

            Text {
                id: appTitleText
                anchors.centerIn: parent
                text: ShellState.activeAppName
                color: Theme.labelColor
                font: Typography.headlineBold
            }

            MouseArea {
                id: appTitleArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: ShellState.openMenuIndex = -2
            }
        }

        // 3. Global Menus ("File", "Edit", "View", "Go", "Window", "Help")
        Repeater {
            model: ShellState.globalMenus.length > 0 ? ShellState.globalMenus : [
                { "id": 1, "label": "File",   "children": [{"id": 101, "label": "New Window", "shortcut": "⌘N", "enabled": true}, {"id": 102, "label": "Close Window", "shortcut": "⌘W", "enabled": true}] },
                { "id": 2, "label": "Edit",   "children": [{"id": 201, "label": "Copy", "shortcut": "⌘C", "enabled": true}, {"id": 202, "label": "Paste", "shortcut": "⌘V", "enabled": true}] },
                { "id": 3, "label": "View",   "children": [{"id": 301, "label": "as Icons", "shortcut": "⌘1", "enabled": true}, {"id": 302, "label": "as List", "shortcut": "⌘2", "enabled": true}] },
                { "id": 4, "label": "Window", "children": [{"id": 401, "label": "Minimize", "shortcut": "⌘M", "enabled": true}] },
                { "id": 5, "label": "Help",   "children": [{"id": 501, "label": "Conjunction Help", "shortcut": "", "enabled": true}] }
            ]

            delegate: Item {
                id: menuBtn
                Layout.preferredWidth: menuLabel.implicitWidth + 16
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: root.openMenuIndex === index
                        ? Theme.systemBlue
                        : (mHover.containsMouse ? (Appearance.isDark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)) : "transparent")
                    Behavior on color { ColorAnimation { duration: Motion.hoverSwap } }
                }

                Text {
                    id: menuLabel
                    anchors.centerIn: parent
                    text: modelData.label || ""
                    color: root.openMenuIndex === index ? "#FFFFFF" : Theme.labelColor
                    font: Typography.body
                }

                MouseArea {
                    id: mHover
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        if (root.openMenuIndex >= -1) {
                            root.openGlobalMenu(index, menuBtn.x + 8, modelData.children || []);
                        }
                    }
                    onClicked: {
                        if (root.openMenuIndex === index) root.closeMenus();
                        else root.openGlobalMenu(index, menuBtn.x + 8, modelData.children || []);
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        // 4. Right Status Tray (Search, Wi-Fi, Bluetooth, Control Center, Clock + Notifications)
        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            // Search / Quick Search Trigger
            Item {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 22
                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: ShellState.spotlightVisible
                        ? (Appearance.isDark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.10))
                        : (spArea.containsMouse ? (Appearance.isDark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)) : "transparent")
                }
                Icon { anchors.centerIn: parent; name: "search"; size: 15; color: Theme.labelColor }
                MouseArea { id: spArea; anchors.fill: parent; hoverEnabled: true; onClicked: ShellState.toggleSpotlight() }
            }

            // Wi-Fi Status
            Item {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 22
                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: wfArea.containsMouse ? (Appearance.isDark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)) : "transparent"
                }
                Icon {
                    anchors.centerIn: parent
                    name: ShellState.wifiEnabled ? "wifi" : "wifi-off"
                    size: 15
                    color: ShellState.wifiEnabled ? Theme.labelColor : Theme.secondaryLabelColor
                }
                MouseArea { id: wfArea; anchors.fill: parent; hoverEnabled: true; onClicked: ShellState.toggleControlCenter() }
            }

            // Control Center Toggle
            Item {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 22
                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: ShellState.controlCenterVisible
                        ? (Appearance.isDark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.10))
                        : (ccArea.containsMouse ? (Appearance.isDark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)) : "transparent")
                }
                Icon { anchors.centerIn: parent; name: "sliders"; size: 15; color: Theme.labelColor }
                MouseArea { id: ccArea; anchors.fill: parent; hoverEnabled: true; onClicked: ShellState.toggleControlCenter() }
            }

            // Notification Center + Tabular-Numeral Clock (SPEC §4.1: ~118+ pt w/ tnum)
            Item {
                Layout.preferredWidth: Math.max(122, clockTxt.implicitWidth + 18)
                Layout.preferredHeight: 22
                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: ShellState.notificationCenterVisible
                        ? (Appearance.isDark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.10))
                        : (clkArea.containsMouse ? (Appearance.isDark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)) : "transparent")
                }
                Text {
                    id: clockTxt
                    anchors.centerIn: parent
                    text: ShellState.systemTime
                    color: Theme.labelColor
                    font: Typography.menuBarClock // Inter 13pt tabular figures (tnum)
                }
                MouseArea { id: clkArea; anchors.fill: parent; hoverEnabled: true; onClicked: ShellState.toggleNotificationCenter() }
            }
        }
    }

    // Floating Dropdown Menu (SPEC §4.1: 12 pt radius, 8 pt item highlight #0088FF, 24 pt rows)
    function openSystemMenu() {
        root.openMenuIndex = -1;
        root.activeMenuX = 8;
        root.activeMenuChildren = [
            { "id": -10, "label": "About This Computer", "action": "about", "shortcut": "", "enabled": true },
            { "id": -11, "label": "System Settings...", "action": "settings", "shortcut": "", "enabled": true },
            { "id": -99, "separator": true },
            { "id": -12, "label": "App Launcher...", "action": "launcher", "shortcut": "", "enabled": true },
            { "id": -13, "label": "Sleep", "action": "suspend", "shortcut": "", "enabled": true },
            { "id": -14, "label": "Restart...", "action": "restart", "shortcut": "", "enabled": true },
            { "id": -15, "label": "Shut Down...", "action": "shutdown", "shortcut": "", "enabled": true },
            { "id": -98, "separator": true },
            { "id": -16, "label": "Lock Screen", "action": "lock", "shortcut": "⌃⌘Q", "enabled": true },
            { "id": -17, "label": "Log Out...", "action": "logout", "shortcut": "⇧⌘Q", "enabled": true }
        ];
    }

    function openGlobalMenu(idx, xPos, children) {
        root.openMenuIndex = idx;
        root.activeMenuX = xPos;
        root.activeMenuChildren = children;
    }

    GlassSurface {
        id: menuPopup
        visible: root.openMenuIndex >= -1 && root.activeMenuChildren.length > 0
        x: Math.min(root.activeMenuX, root.width - width - 8)
        y: root.height + 2
        width: 236
        height: menuCol.implicitHeight + 12
        variant: "regular"
        cornerRadius: Geometry.radiusMenu
        shadowPreset: "popover"
        backdropItem: root.backdropItem
        z: 999

        MouseArea {
            id: menuPopupHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onExited: menuHideDelay.restart()
        }

        Column {
            id: menuCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            spacing: 1

            Repeater {
                model: root.activeMenuChildren
                delegate: Item {
                    width: menuCol.width
                    height: modelData.separator ? 9 : 24 // SPEC §4.1: 24 pt item rows

                    Rectangle {
                        visible: !!modelData.separator
                        anchors.centerIn: parent
                        width: parent.width - 16
                        height: 1
                        color: Theme.menuSeparatorColor
                    }

                    Rectangle {
                        visible: !modelData.separator
                        anchors.fill: parent
                        radius: 8 // SPEC §2.1: 8 pt selection highlight
                        color: itemMouse.containsMouse && (modelData.enabled !== false) ? Theme.systemBlue : "transparent"
                    }

                    RowLayout {
                        visible: !modelData.separator
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        Text {
                            text: modelData.label || ""
                            color: itemMouse.containsMouse && (modelData.enabled !== false)
                                ? "#FFFFFF"
                                : (modelData.enabled === false ? Theme.tertiaryLabelColor : Theme.labelColor)
                            font: Typography.body
                            Layout.fillWidth: true
                        }
                        Text {
                            visible: !!(modelData.shortcut && modelData.shortcut !== "")
                            text: modelData.shortcut || ""
                            color: itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.82) : Theme.secondaryLabelColor
                            font: Typography.callout
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        visible: !modelData.separator
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (modelData.enabled === false) return;
                            var act = modelData.action || "";
                            var id = modelData.id;
                            root.closeMenus();
                            if (act === "settings") ShellState.OpenSetting("");
                            else if (act === "launcher") ShellState.toggleAppLauncher();
                            else if (act === "about") ShellState.OpenSetting("about");
                            else if (act !== "") ShellState.requestSystemAction(act);
                            else if (id !== undefined) ShellState.triggerMenuAction(id);
                        }
                    }
                }
            }
        }
    }
}
