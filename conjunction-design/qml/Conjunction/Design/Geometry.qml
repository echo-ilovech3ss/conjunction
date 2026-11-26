pragma Singleton
import QtQuick

QtObject {
    id: root

    // Continuous superellipse extension factor (SPEC §2.1: 1.528665 * r)
    readonly property real continuousCornerFactor: 1.528665
    readonly property real minConcentricRadius: 4.0

    function concentricRadius(outerRadius, padding) {
        return Math.max(minConcentricRadius, outerRadius - padding);
    }

    function continuousTangentExtent(r) {
        return continuousCornerFactor * r;
    }

    // SPEC §2.1 Radii
    readonly property real radiusWindow: 16.0
    readonly property real radiusSheet: 16.0
    readonly property real radiusSheetLarge: 26.0
    readonly property real radiusPopover: 14.0
    readonly property real radiusMenu: 12.0
    readonly property real radiusMenuItem: 8.0
    readonly property real radiusSidebarPill: 10.0
    readonly property real radiusCard: 12.0
    readonly property real radiusControlCenterModule: 24.0
    readonly property real radiusCheckbox: 5.0
    readonly property real radiusTextField: 8.0
    readonly property real radiusTableRow: 8.0

    // SPEC §2.3 Control Size Scale lookup ("mini", "small", "regular", "large", "extraLarge")
    function pushButtonHeight(sizeClass) {
        if (sizeClass === "mini") return 16;
        if (sizeClass === "small" || sizeClass === "compact") return 27;
        if (sizeClass === "large" || sizeClass === "extraLarge") return 40;
        return 32; // regular
    }

    function segmentedHeight(sizeClass, isToolbar) {
        if (isToolbar) {
            if (sizeClass === "mini") return 18;
            if (sizeClass === "small" || sizeClass === "compact") return 21;
            if (sizeClass === "large" || sizeClass === "extraLarge") return 40;
            return 25;
        }
        if (sizeClass === "mini") return 16;
        if (sizeClass === "small" || sizeClass === "compact") return 21;
        if (sizeClass === "large" || sizeClass === "extraLarge") return 40;
        return 24;
    }

    function textFieldHeight(sizeClass) {
        if (sizeClass === "mini") return 16;
        if (sizeClass === "small" || sizeClass === "compact") return 19;
        if (sizeClass === "large") return 28;
        if (sizeClass === "extraLarge") return 36;
        return 24;
    }

    function popUpHeight(sizeClass) {
        if (sizeClass === "mini") return 16;
        if (sizeClass === "small" || sizeClass === "compact") return 21;
        if (sizeClass === "large") return 28;
        if (sizeClass === "extraLarge") return 36;
        return 24;
    }

    function comboBoxHeight(sizeClass) {
        if (sizeClass === "mini") return 16;
        if (sizeClass === "small" || sizeClass === "compact") return 21;
        if (sizeClass === "large" || sizeClass === "extraLarge") return 28;
        return 24;
    }

    function switchSize(sizeClass) {
        if (sizeClass === "mini") return Qt.size(26, 15);
        if (sizeClass === "small" || sizeClass === "compact") return Qt.size(32, 18);
        return Qt.size(42, 25); // regular & large
    }

    function checkBoxSize(sizeClass) {
        if (sizeClass === "mini") return 14;
        if (sizeClass === "small" || sizeClass === "compact") return 16;
        if (sizeClass === "large" || sizeClass === "extraLarge") return 20;
        return 18;
    }

    function sliderTrackHeight(sizeClass) {
        return (sizeClass === "mini") ? 3 : 4;
    }

    function sliderKnobSize(sizeClass) {
        if (sizeClass === "large" || sizeClass === "extraLarge") return Qt.size(24, 28);
        return Qt.size(20, 28);
    }

    readonly property int alertPillHeight: 28
    readonly property int toolbarButtonSize: 36
    readonly property int toolbarButtonSmallSize: 28
    readonly property int toolbarHeightUnified: 54
    readonly property int toolbarHeightCompact: 38
    readonly property int toolbarHeightPreference: 80
    readonly property int toolbarHeightPlain: 28

    // Traffic light metrics (SPEC §4.6)
    readonly property int trafficLightDiameter: 14
    readonly property int trafficLightCompactDiameter: 12
    readonly property int trafficLightPitch: 23
    readonly property int trafficLightCompactPitch: 20

    // Scrollbar widths (SPEC §2.3)
    readonly property int scrollBarIdleWidth: 12
    readonly property int scrollBarHoverWidth: 16

    // Window Shadow Padding & Metrics (SPEC §2.5)
    readonly property int shadowPadBottom: 74
    readonly property int shadowPadSide: 56
    readonly property int shadowPadTop: 38

    // SPEC §2.7 Focus ring
    readonly property real focusRingOffset: 3.5
    readonly property real focusRingThickness: 3.5
    readonly property real focusRingInnerThickness: 0.75

    // Legacy compatibility aliases
    readonly property int controlHeightSmall: 27
    readonly property int controlHeightMedium: 32
    readonly property int controlHeightLarge: 40
    readonly property int minTargetSize: 32

    readonly property int radiusSmall: 8
    readonly property int radiusMedium: 12
    readonly property int radiusLarge: 16
    readonly property int radiusPill: 999

    readonly property real separatorThickness: 1.0
    readonly property real hairlineThickness: 0.5

    readonly property int windowMargin: 20
    readonly property int contentPadding: 16
}
