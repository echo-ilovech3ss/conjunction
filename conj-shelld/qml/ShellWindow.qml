import QtQuick
import QtQuick.Window
import Conjunction.Design

// Root Desktop Shell supporting both multi-window Wayland LayerShell panels AND
// single-window Composite Verification Mode with real Clear/Regular Glass backdrop refraction.
Item {
    id: rootContainer

    // Synchronize Conjunction.Design Appearance singleton dynamically from ShellState
    function syncDesignTokens() {
        Appearance.setMode(ShellState.isDark ? "dark" : "light");
        Appearance.setAccent(ShellState.accentColor);
        Appearance.setReducedMotion(ShellState.reducedMotion);
        Appearance.setReduceTransparency(ShellState.reduceTransparency);
        Appearance.setIncreaseContrast(ShellState.increaseContrast);
    }

    Component.onCompleted: syncDesignTokens()

    Connections {
        target: ShellState
        function onThemeChanged() { rootContainer.syncDesignTokens(); }
        function onAccentColorChanged() { rootContainer.syncDesignTokens(); }
        function onReducedMotionChanged() { rootContainer.syncDesignTokens(); }
        function onReduceTransparencyChanged() { rootContainer.syncDesignTokens(); }
        function onIncreaseContrastChanged() { rootContainer.syncDesignTokens(); }
    }

    // ---- 1. COMPOSITE WINDOW MODE (screenshot, headless/Xvfb check, or --composite) ----
    Window {
        id: compositeWindow
        visible: !ShellState.layerShellMode
        width: 1280
        height: 800
        title: "Conjunction Desktop Shell"
        color: Appearance.isDark ? "#0D1526" : "#CFE4F7"
        flags: Qt.FramelessWindowHint | Qt.Window

        // Crisp procedural Light/Dark Conjunction Desktop Wallpaper (Backdrop for Liquid Glass shader)
        Item {
            id: wallpaperBackdrop
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: Appearance.isDark ? "#0A1A36" : "#4CA5E8" }
                    GradientStop { position: 0.45; color: Appearance.isDark ? "#132E52" : "#80C7F2" }
                    GradientStop { position: 0.85; color: Appearance.isDark ? "#1F1D48" : "#F3D3B8" }
                    GradientStop { position: 1.0; color: Appearance.isDark ? "#0F1224" : "#E59876" }
                }
            }

            // Abstract layered coastal/ridge organic contours for natural refraction detail
            Canvas {
                anchors.fill: parent
                property bool dark: Appearance.isDark
                onDarkChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    ctx.fillStyle = dark ? "rgba(38, 125, 195, 0.28)" : "rgba(255, 255, 255, 0.26)";
                    ctx.beginPath();
                    ctx.moveTo(0, height * 0.62);
                    ctx.bezierCurveTo(width * 0.28, height * 0.44, width * 0.55, height * 0.72, width, height * 0.48);
                    ctx.lineTo(width, height);
                    ctx.lineTo(0, height);
                    ctx.closePath();
                    ctx.fill();

                    ctx.fillStyle = dark ? "rgba(18, 42, 82, 0.45)" : "rgba(48, 128, 196, 0.22)";
                    ctx.beginPath();
                    ctx.moveTo(0, height * 0.78);
                    ctx.bezierCurveTo(width * 0.35, height * 0.65, width * 0.72, height * 0.86, width, height * 0.68);
                    ctx.lineTo(width, height);
                    ctx.lineTo(0, height);
                    ctx.closePath();
                    ctx.fill();
                }
            }
        }

        TopBar {
            id: topBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            backdropItem: wallpaperBackdrop
            z: 50
        }

        Dock {
            id: dockBar
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            backdropItem: wallpaperBackdrop
            z: 45
        }

        ControlCenter {
            visible: ShellState.controlCenterVisible
            anchors.top: topBar.bottom
            anchors.topMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 12
            backdropItem: wallpaperBackdrop
            z: 70
        }

        NotificationCenter {
            visible: ShellState.notificationCenterVisible
            anchors.top: topBar.bottom
            anchors.topMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 12
            backdropItem: wallpaperBackdrop
            z: 72
        }

        NotificationBanner {
            visible: ShellState.activeBanners.length > 0 && !ShellState.notificationCenterVisible
            anchors.top: topBar.bottom
            anchors.topMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 14
            backdropItem: wallpaperBackdrop
            z: 74
        }

        Spotlight {
            visible: ShellState.spotlightVisible
            anchors.horizontalCenter: parent.horizontalCenter
            y: 165
            backdropItem: wallpaperBackdrop
            z: 80
        }

        AppLauncher {
            visible: ShellState.appLauncherVisible
            anchors.centerIn: parent
            backdropItem: wallpaperBackdrop
            z: 82
        }

        AppSwitcherHUD {
            visible: ShellState.appSwitcherVisible
            anchors.centerIn: parent
            backdropItem: wallpaperBackdrop
            z: 85
        }

        QuickNoteOverlay {
            visible: ShellState.quickNoteVisible
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 112
            backdropItem: wallpaperBackdrop
            z: 76
        }

        OverviewOverlay {
            visible: ShellState.overviewActive
            anchors.fill: parent
            backdropItem: wallpaperBackdrop
            z: 90
        }
    }

    // ---- 2. WAYLAND LAYERSHELL MULTI-WINDOW MODE (Native KWin 6 Desktop Session) ----
    Window {
        id: lsTopBarWindow
        visible: ShellState.layerShellMode
        width: Screen.width
        height: ShellState.notchBar ? 39 : 28
        color: "transparent"
        flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
        Component.onCompleted: if (ShellState.layerShellMode) ShellState.bindLayerShell(lsTopBarWindow, "topbar", ShellState.notchBar ? 39 : 28)

        TopBar {
            anchors.fill: parent
        }
    }

    Window {
        id: lsDockWindow
        visible: ShellState.layerShellMode
        width: Math.max(480, lsDock.width)
        height: lsDock.height
        color: "transparent"
        flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
        Component.onCompleted: if (ShellState.layerShellMode) ShellState.bindLayerShell(lsDockWindow, "dock", 0)

        Dock {
            id: lsDock
            anchors.centerIn: parent
        }
    }

    readonly property bool anyLayerOverlayActive: ShellState.controlCenterVisible
        || ShellState.notificationCenterVisible
        || ShellState.spotlightVisible
        || ShellState.appLauncherVisible
        || ShellState.appSwitcherVisible
        || ShellState.quickNoteVisible
        || ShellState.overviewActive
        || ShellState.activeBanners.length > 0

    Window {
        id: lsOverlayWindow
        visible: ShellState.layerShellMode && rootContainer.anyLayerOverlayActive
        width: Screen.width
        height: Screen.height
        color: "transparent"
        flags: Qt.FramelessWindowHint
        Component.onCompleted: if (ShellState.layerShellMode) ShellState.bindLayerShell(lsOverlayWindow, "overlay", -1)

        MouseArea {
            anchors.fill: parent
            onClicked: {
                ShellState.controlCenterVisible = false;
                ShellState.notificationCenterVisible = false;
                ShellState.spotlightVisible = false;
                ShellState.appLauncherVisible = false;
            }
        }

        ControlCenter {
            visible: ShellState.controlCenterVisible
            anchors.top: parent.top
            anchors.topMargin: (ShellState.notchBar ? 39 : 28) + 10
            anchors.right: parent.right
            anchors.rightMargin: 12
        }

        NotificationCenter {
            visible: ShellState.notificationCenterVisible
            anchors.top: parent.top
            anchors.topMargin: (ShellState.notchBar ? 39 : 28) + 10
            anchors.right: parent.right
            anchors.rightMargin: 12
        }

        NotificationBanner {
            visible: ShellState.activeBanners.length > 0 && !ShellState.notificationCenterVisible
            anchors.top: parent.top
            anchors.topMargin: (ShellState.notchBar ? 39 : 28) + 12
            anchors.right: parent.right
            anchors.rightMargin: 14
        }

        Spotlight {
            visible: ShellState.spotlightVisible
            anchors.horizontalCenter: parent.horizontalCenter
            y: 165
        }

        AppLauncher {
            visible: ShellState.appLauncherVisible
            anchors.centerIn: parent
        }

        AppSwitcherHUD {
            visible: ShellState.appSwitcherVisible
            anchors.centerIn: parent
        }

        QuickNoteOverlay {
            visible: ShellState.quickNoteVisible
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 112
        }

        OverviewOverlay {
            visible: ShellState.overviewActive
            anchors.fill: parent
        }
    }
}
