import QtQuick
import QtQuick.Window
import Conjunction.Design

Window {
    id: rootWindow
    width: 1024
    height: 768
    visible: true
    title: "Conjunction Desktop Shell"
    flags: Qt.FramelessWindowHint

    // Synchronize design system theme with shell state
    Connections {
        target: ShellState
        function onThemeChanged() {
            Appearance.setMode(ShellState.isDark ? "dark" : "light");
        }
    }
    Component.onCompleted: {
        Appearance.setMode(ShellState.isDark ? "dark" : "light");
        if (typeof isReducedMotion !== "undefined" && isReducedMotion) {
            Appearance.reducedMotion = true;
        }
    }

    // Desktop Background Wallpaper (Clean original subtle gradient)
    Rectangle {
        id: desktopWallpaper
        anchors.fill: parent

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Theme.isDark ? "#141519" : "#D4DCE8"
            }
            GradientStop {
                position: 0.5
                color: Theme.isDark ? "#1A1B22" : "#E2E8F0"
            }
            GradientStop {
                position: 1.0
                color: Theme.isDark ? "#101115" : "#CBD5E1"
            }
        }

        // Subtle desktop ambient accent
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.7
            height: parent.height * 0.7
            radius: width / 2
            opacity: Theme.isDark ? 0.08 : 0.15
            color: Theme.accent
        }
    }

    // Top Bar across the top of the display
    TopBar {
        id: topBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        z: 100
    }

    // Floating Centered Application Dock near the bottom
    Dock {
        id: dock
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        z: 100
    }

    // Spotlight Global Search Dialog
    Spotlight {
        id: spotlight
    }

    // Control Center Drawer
    ControlCenter {
        id: controlCenter
    }

    // Mission Control / Exposé Overview Overlay
    OverviewOverlay {
        id: overviewOverlay
    }

    // Global keyboard shortcut to focus the Dock (Ctrl+Alt+D)
    Shortcut {
        sequence: "Ctrl+Alt+D"
        onActivated: {
            dock.focus = true;
            dock.focusedIndex = 0;
        }
    }

    // Global keyboard shortcut for Spotlight Search (Ctrl+Space)
    Shortcut {
        sequence: "Ctrl+Space"
        onActivated: ShellState.toggleSpotlight()
    }

    // Global keyboard shortcut for Mission Control / Overview (Ctrl+Up)
    Shortcut {
        sequence: "Ctrl+Up"
        onActivated: ShellState.toggleOverview()
    }
}
