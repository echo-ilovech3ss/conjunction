pragma Singleton
import QtQuick

QtObject {
    id: root

    // Appearance mode: light, dark, system
    property string mode: "light"

    // Effective theme derived from mode or system preference: light or dark
    readonly property string effectiveTheme: {
        if (mode === "dark") return "dark";
        if (mode === "light") return "light";
        // Default fallback
        return "light";
    }

    readonly property bool isDark: effectiveTheme === "dark"

    // Accent palette: blue, teal, amber, violet, graphite
    property string accent: "blue"

    // Reduced motion accessibility preference
    property bool reducedMotion: false

    // Font scaling factor (1.0 = standard 100%)
    property real fontScale: 1.0

    // Layout direction (Qt.LeftToRight or Qt.RightToLeft)
    property int layoutDirection: Qt.LeftToRight

    readonly property bool isRTL: layoutDirection === Qt.RightToLeft

    function setMode(newMode) {
        if (newMode === "light" || newMode === "dark" || newMode === "system") {
            mode = newMode;
        }
    }

    function toggleTheme() {
        if (effectiveTheme === "light") {
            setMode("dark");
        } else {
            setMode("light");
        }
    }

    function setAccent(newAccent) {
        accent = newAccent;
    }

    function setReducedMotion(enabled) {
        reducedMotion = enabled;
    }

    function setFontScale(scale) {
        fontScale = Math.max(0.75, Math.min(2.5, scale));
    }

    function setLayoutDirection(dir) {
        layoutDirection = dir;
    }

    function toggleRTL() {
        if (layoutDirection === Qt.LeftToRight) {
            layoutDirection = Qt.RightToLeft;
        } else {
            layoutDirection = Qt.LeftToRight;
        }
    }
}
