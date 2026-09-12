import QtQuick
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls as Controls

Rectangle {
    id: root
    height: 30
    color: Theme.isDark ? "#D91C1D22" : "#E6F6F7F9"
    border.color: Theme.separator
    border.width: 1

    // Slide up / hide on true fullscreen
    visible: !ShellState.isFullscreen
    opacity: ShellState.isFullscreen ? 0.0 : 1.0
    Behavior on opacity {
        NumberAnimation { duration: 150 }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 12
        spacing: 4

        // 1. Conjunction System Mark (Diamond icon ◇)
        Rectangle {
            id: systemMarkButton
            width: 24
            height: 24
            radius: 4
            color: markHover.hovered || sysMenu.visible ? (Theme.isDark ? "#28FFFFFF" : "#1A000000") : "transparent"

            Canvas {
                anchors.centerIn: parent
                width: 14
                height: 14
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = Theme.textPrimary;
                    ctx.fillStyle = Theme.accent;
                    ctx.lineWidth = 1.5;

                    // Diamond shape with center node
                    ctx.beginPath();
                    ctx.moveTo(7, 1);
                    ctx.lineTo(13, 7);
                    ctx.lineTo(7, 13);
                    ctx.lineTo(1, 7);
                    ctx.closePath();
                    ctx.stroke();

                    ctx.beginPath();
                    ctx.arc(7, 7, 2, 0, 2 * Math.PI);
                    ctx.fill();
                }
                Connections {
                    target: Theme
                    function onIsDarkChanged() { systemMarkButton.children[0].requestPaint(); }
                }
            }

            HoverHandler { id: markHover }
            TapHandler {
                onTapped: {
                    if (sysMenu.visible) sysMenu.close();
                    else sysMenu.open();
                }
            }

            Controls.Menu {
                id: sysMenu
                y: systemMarkButton.height + 4

                Controls.MenuItem {
                    text: "About Conjunction"
                    iconName: "info"
                    onTriggered: ShellState.requestSystemAction("about")
                }
                Controls.MenuItem {
                    text: "System Settings..."
                    iconName: "gear"
                    onTriggered: ShellState.launchApp("org.conjunction.settings")
                }
                Controls.MenuSeparator {}
                Controls.MenuItem {
                    text: "Lock Screen"
                    iconName: "lock"
                    shortcutText: "Ctrl+Alt+L"
                    onTriggered: ShellState.requestSystemAction("lock")
                }
                Controls.MenuItem {
                    text: "Log Out..."
                    iconName: "logout"
                    shortcutText: "Ctrl+Shift+Q"
                    onTriggered: ShellState.requestSystemAction("logout")
                }
                Controls.MenuSeparator {}
                Controls.MenuItem {
                    text: "Restart..."
                    iconName: "refresh"
                    onTriggered: ShellState.requestSystemAction("restart")
                }
                Controls.MenuItem {
                    text: "Shut Down..."
                    iconName: "power"
                    onTriggered: ShellState.requestSystemAction("shutdown")
                }
            }
        }

        // 2. Active Application Menu (About, Settings, Hide, Quit)
        Rectangle {
            id: appNameBtn
            height: 22
            width: appNameText.implicitWidth + 14
            radius: 4
            color: appNameHover.hovered || appMenu.visible ? (Theme.isDark ? "#28FFFFFF" : "#1A000000") : "transparent"
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: appNameText
                anchors.centerIn: parent
                text: ShellState.activeAppName
                font: Typography.sectionHeading
                color: Theme.textPrimary
            }

            HoverHandler { id: appNameHover }
            TapHandler {
                onTapped: {
                    if (appMenu.visible) appMenu.close();
                    else appMenu.open();
                }
            }

            Controls.Menu {
                id: appMenu
                y: appNameBtn.height + 4

                Controls.MenuItem {
                    text: "About " + ShellState.activeAppName
                    iconName: "info"
                    onTriggered: ShellState.aboutCurrentApp()
                }
                Controls.MenuItem {
                    text: "Settings..."
                    iconName: "gear"
                    shortcutText: "Ctrl+,"
                    onTriggered: ShellState.launchApp("org.conjunction.settings")
                }
                Controls.MenuSeparator {}
                Controls.MenuItem {
                    text: "Hide " + ShellState.activeAppName
                    shortcutText: "Ctrl+H"
                    onTriggered: ShellState.hideCurrentApp()
                }
                Controls.MenuItem {
                    text: "Hide Others"
                    shortcutText: "Ctrl+Alt+H"
                    onTriggered: ShellState.hideOthers()
                }
                Controls.MenuItem {
                    text: "Show All"
                    onTriggered: ShellState.showAll()
                }
                Controls.MenuSeparator {}
                Controls.MenuItem {
                    text: "Quit " + ShellState.activeAppName
                    iconName: "close"
                    shortcutText: "Ctrl+Q"
                    onTriggered: ShellState.quitCurrentApp()
                }
            }
        }

        // 3. Application Global Menus (File, Edit, View, Window, Help)
        Row {
            id: menuBarRow
            spacing: 2
            Layout.fillHeight: true

            Repeater {
                model: ShellState.globalMenus

                Rectangle {
                    id: menuHeadingBtn
                    height: 22
                    width: headingText.implicitWidth + 14
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 4
                    color: headingHover.hovered || headingMenu.visible ? (Theme.isDark ? "#28FFFFFF" : "#1A000000") : "transparent"

                    Text {
                        id: headingText
                        anchors.centerIn: parent
                        text: modelData.label || ""
                        font: Typography.controlLabel
                        color: Theme.textPrimary
                    }

                    HoverHandler { id: headingHover }
                    TapHandler {
                        onTapped: {
                            if (headingMenu.visible) headingMenu.close();
                            else headingMenu.open();
                        }
                    }

                    Controls.Menu {
                        id: headingMenu
                        y: menuHeadingBtn.height + 4

                        Repeater {
                            model: modelData.children || []

                            Controls.MenuItem {
                                text: modelData.label || ""
                                iconName: modelData.iconName || ""
                                enabled: modelData.enabled !== undefined ? modelData.enabled : true
                                onTriggered: {
                                    if (modelData.id !== undefined) {
                                        ShellState.triggerMenuAction(modelData.id);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        // 4. Status Area (Search, Control Center, Theme, Sound, Network, Clock)
        RowLayout {
            spacing: 10
            Layout.alignment: Qt.AlignVCenter

            // Spotlight Search Trigger
            Rectangle {
                width: 22
                height: 22
                radius: 4
                color: searchHover.hovered || ShellState.spotlightVisible ? (Theme.isDark ? "#28FFFFFF" : "#1A000000") : "transparent"
                Icon {
                    anchors.centerIn: parent
                    name: "search"
                    size: 14
                    color: ShellState.spotlightVisible ? Theme.accent : Theme.textPrimary
                }
                HoverHandler { id: searchHover }
                TapHandler { onTapped: ShellState.toggleSpotlight() }
            }

            // Control Center Trigger
            Rectangle {
                width: 22
                height: 22
                radius: 4
                color: ccHover.hovered || ShellState.controlCenterVisible ? (Theme.isDark ? "#28FFFFFF" : "#1A000000") : "transparent"

                // Double slider switch icon representation
                Canvas {
                    anchors.centerIn: parent
                    width: 14
                    height: 12
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.fillStyle = ShellState.controlCenterVisible ? Theme.accent : Theme.textPrimary;
                        // Top track and knob
                        ctx.fillRect(0, 1, 14, 3);
                        ctx.fillRect(8, 0, 4, 5);
                        // Bottom track and knob
                        ctx.fillRect(0, 7, 14, 3);
                        ctx.fillRect(2, 6, 4, 5);
                    }
                }

                HoverHandler { id: ccHover }
                TapHandler { onTapped: ShellState.toggleControlCenter() }
            }

            // Theme toggle helper
            Rectangle {
                width: 20
                height: 20
                radius: 4
                color: themeHover.hovered ? (Theme.isDark ? "#28FFFFFF" : "#1A000000") : "transparent"
                Icon {
                    anchors.centerIn: parent
                    name: Theme.isDark ? "eye" : "close"
                    size: 13
                    color: Theme.textSecondary
                }
                HoverHandler { id: themeHover }
                TapHandler { onTapped: ShellState.toggleTheme() }
            }

            // Volume Status
            Icon {
                name: "sound"
                size: 14
                color: Theme.textPrimary
            }

            // Network Status
            Icon {
                name: "network"
                size: 14
                color: Theme.textPrimary
            }

            // Notification Center toggle button
            Rectangle {
                width: 22
                height: 20
                radius: 4
                color: notifHover.hovered || ShellState.notificationCenterVisible ? (Theme.isDark ? "#28FFFFFF" : "#1A000000") : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "🔔"
                    font.pixelSize: 11
                }

                // Unread indicator dot
                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.accent
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 2
                    anchors.rightMargin: 2
                    visible: ShellState.notificationHistory.length > 0
                }

                HoverHandler { id: notifHover }
                TapHandler { onTapped: ShellState.toggleNotificationCenter() }
            }

            // Clock (clicking toggles Notification Center)
            Rectangle {
                height: 20
                width: clockText.implicitWidth + 8
                radius: 4
                color: clockHover.hovered ? (Theme.isDark ? "#28FFFFFF" : "#1A000000") : "transparent"

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    text: ShellState.systemTime
                    font: Typography.controlLabel
                    color: Theme.textPrimary
                }

                HoverHandler { id: clockHover }
                TapHandler { onTapped: ShellState.toggleNotificationCenter() }
            }
        }
    }
}
