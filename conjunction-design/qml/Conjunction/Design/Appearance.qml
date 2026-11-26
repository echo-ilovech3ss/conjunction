pragma Singleton
import QtQuick

QtObject {
    id: root

    // Appearance mode: light, dark, system
    property string mode: "light"

    readonly property string effectiveTheme: {
        if (mode === "dark") return "dark";
        if (mode === "light") return "light";
        return "light";
    }

    readonly property bool isDark: effectiveTheme === "dark"

    // Accent palette: blue (default #007AFF), teal, amber, violet, graphite, purple, pink, orange, green
    property string accent: "blue"

    // Accessibility state (SPEC §1.5, §2.8, §3.3)
    property bool reducedMotion: false
    property bool reduceTransparency: false
    property bool increaseContrast: false
    readonly property bool shouldReduceTransparency: reduceTransparency
    readonly property bool shouldIncreaseContrast: increaseContrast

    // Font scaling factor & Optical Cap-Height Scaling (SPEC §2.4 Option A = 0.9685x Inter)
    property real fontScale: 1.0
    property bool useOpticalCapScaling: true
    property bool stressMode: false

    readonly property string stressLongTitle: "Conjunction Workstation Control Plane — Donaudampfschifffahrtsgesellschaftskapitän — Ultra-Long Overflow Verification Title"
    readonly property string stressCompoundWord: "Rindfleischetikettierungsüberwachungsaufgabenübertragungsgesetz-Verifikationsmodul"
    readonly property string stressUnbrokenUrl: "https://conjunction.example.org/workstation/api/v2/bundles/org.conjunction.desktop.verification/artifacts/long-unbroken-resource-identifier"

    // Layout direction (Qt.LeftToRight or Qt.RightToLeft)
    property int layoutDirection: Qt.LeftToRight
    readonly property bool isRTL: layoutDirection === Qt.RightToLeft

    function setMode(newMode) {
        if (newMode === "light" || newMode === "dark" || newMode === "system") {
            mode = newMode;
        }
    }

    function toggleTheme() {
        setMode(effectiveTheme === "light" ? "dark" : "light");
    }

    function setAccent(newAccent) {
        accent = newAccent;
    }

    function setReducedMotion(enabled) {
        reducedMotion = !!enabled;
    }

    function setReduceTransparency(enabled) {
        reduceTransparency = !!enabled;
    }

    function setIncreaseContrast(enabled) {
        increaseContrast = !!enabled;
    }

    function setFontScale(scale) {
        fontScale = Math.max(0.75, Math.min(2.5, scale));
    }

    function setStressMode(enabled) {
        stressMode = !!enabled;
    }

    function setLayoutDirection(dir) {
        layoutDirection = dir;
    }

    function toggleRTL() {
        layoutDirection = (layoutDirection === Qt.LeftToRight) ? Qt.RightToLeft : Qt.LeftToRight;
    }
}
