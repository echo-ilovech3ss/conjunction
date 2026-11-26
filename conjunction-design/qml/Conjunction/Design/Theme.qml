pragma Singleton
import QtQuick

QtObject {
    id: root

    readonly property bool isDark: Appearance.isDark
    readonly property bool highContrast: Appearance.shouldIncreaseContrast
    readonly property bool reduceTransparency: Appearance.shouldReduceTransparency

    // System palette tokens (SPEC §2.8 sRGB)
    readonly property color controlAccentColor: "#007AFF"
    readonly property color systemBlue: highContrast
        ? (isDark ? "#35A8FF" : "#0066E8")
        : (isDark ? "#0091FF" : "#0088FF")
    readonly property color systemRed: isDark ? "#FF4245" : "#FF383C"
    readonly property color systemOrange: isDark ? "#FF9230" : "#FF8D28"
    readonly property color systemYellow: isDark ? "#FFD600" : "#FFCC00"
    readonly property color systemGreen: isDark ? "#30D158" : "#34C759"
    readonly property color systemMint: isDark ? "#00DAC3" : "#00C8B3"
    readonly property color systemTeal: isDark ? "#00D2E0" : "#00C3D0"
    readonly property color systemCyan: isDark ? "#3CD3FE" : "#00C0E8"
    readonly property color systemIndigo: isDark ? "#6D7CFF" : "#6155F5"
    readonly property color systemPurple: isDark ? "#DB34F2" : "#CB30E0"
    readonly property color systemPink: isDark ? "#FF375F" : "#FF2D55"
    readonly property color systemBrown: isDark ? "#B78A66" : "#AC7F5E"
    readonly property color systemGray: isDark ? "#98989D" : "#8E8E93"

    // Traffic lights (SPEC §4.6)
    readonly property color trafficLightClose: "#E2685B"
    readonly property color trafficLightCloseHighlight: "#F5C5BA"
    readonly property color trafficLightMinimize: "#F4C32C"
    readonly property color trafficLightMinimizeHighlight: "#FFFF7D"
    readonly property color trafficLightZoom: "#62BD2E"
    readonly property color trafficLightZoomHighlight: "#B7F697"
    readonly property color trafficLightInactive: isDark ? "#4D4D4F" : Qt.rgba(0.863, 0.863, 0.863, 0.50)

    // SPEC §2.8 Window & Surface Colors (+ SPEC §1.5 Reduce Transparency chrome)
    readonly property color windowBackgroundColor: reduceTransparency
        ? (isDark ? "#282828" : "#ECECEC")
        : (isDark ? "#323232" : "#ECECEC")
    readonly property color textBackgroundColor: isDark ? "#1E1E1E" : "#FFFFFF"
    readonly property color controlBackgroundColor: reduceTransparency
        ? (isDark ? "#282828" : "#FFFFFF")
        : (isDark ? "#1E1E1E" : "#FFFFFF")
    readonly property color underPageBackgroundColor: isDark ? "#1A1A1A" : "#C8C8C8"
    readonly property color popoverBackgroundColor: reduceTransparency
        ? (isDark ? "#282828" : "#F4F4F4")
        : (isDark ? "#2C2C2E" : "#F4F4F4")

    readonly property color controlFill: isDark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.05)
    readonly property color controlFillHover: isDark ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color controlFillPressed: isDark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12)

    // Label hierarchy (SPEC §2.8 + §1.5 AX contrast)
    readonly property color labelColor: highContrast
        ? (isDark ? "#FFFFFF" : "#000000")
        : (isDark ? Qt.rgba(1, 1, 1, 0.847) : Qt.rgba(0, 0, 0, 0.847))
    readonly property color secondaryLabelColor: highContrast
        ? (isDark ? "#A3A3A3" : "#595959")
        : (isDark ? Qt.rgba(1, 1, 1, 0.549) : Qt.rgba(0, 0, 0, 0.498))
    readonly property color tertiaryLabelColor: highContrast
        ? (isDark ? Qt.rgba(1, 1, 1, 0.49) : Qt.rgba(0, 0, 0, 0.49))
        : (isDark ? Qt.rgba(1, 1, 1, 0.247) : Qt.rgba(0, 0, 0, 0.259))
    readonly property color quaternaryLabelColor: isDark ? Qt.rgba(1, 1, 1, 0.098) : Qt.rgba(0, 0, 0, 0.098)

    // Selection tokens
    readonly property color selectedContentBackgroundColor: reduceTransparency
        ? (isDark ? "#226BB9" : "#004080")
        : "#0067F4"
    readonly property color unemphasizedSelectedTextBg: reduceTransparency
        ? (isDark ? "#464646" : "#D2D2D2")
        : (isDark ? "#464646" : "#DCDCDC")

    // Separators & Hairlines (SPEC §2.6 + §1.5 Increase Contrast = 65% alpha)
    readonly property color separatorColor: highContrast
        ? (isDark ? Qt.rgba(1, 1, 1, 0.65) : Qt.rgba(0, 0, 0, 0.65))
        : (isDark ? Qt.rgba(1, 1, 1, 0.098) : Qt.rgba(0, 0, 0, 0.098))
    readonly property color menuSeparatorColor: highContrast
        ? (isDark ? Qt.rgba(1, 1, 1, 0.65) : Qt.rgba(0, 0, 0, 0.65))
        : (isDark ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(0, 0, 0, 0.12))
    readonly property color toolbarPocketHairline: highContrast
        ? separatorColor
        : (isDark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.098))
    readonly property color highContrastBorderColor: isDark
        ? Qt.rgba(1, 1, 1, 0.45)
        : Qt.rgba(0, 0, 0, 0.45)

    // Keyboard focus indicator (SPEC §2.7)
    readonly property color keyboardFocusIndicatorColor: highContrast
        ? (isDark ? Qt.rgba(0.102, 0.663, 1.0, 0.82) : Qt.rgba(0.0, 0.404, 0.957, 0.82))
        : (isDark ? Qt.rgba(0.102, 0.663, 1.0, 0.498) : Qt.rgba(0.0, 0.404, 0.957, 0.498))
    readonly property color keyboardFocusInnerColor: isDark ? "#1AA9FF" : "#0067F4"

    // Legacy / Compatibility Aliases (mapped cleanly to SPEC §2.8)
    readonly property color background: windowBackgroundColor
    readonly property color backgroundPrimary: windowBackgroundColor
    readonly property color surface: controlBackgroundColor
    readonly property color surfaceElevated: popoverBackgroundColor
    readonly property color surfaceSecondary: reduceTransparency
        ? (isDark ? "#282828" : "#EDEDED")
        : (isDark ? "#2C2C2E" : "#E5E5E7")

    readonly property color textPrimary: labelColor
    readonly property color textSecondary: secondaryLabelColor
    readonly property color textDisabled: tertiaryLabelColor
    readonly property color textPlaceholder: tertiaryLabelColor

    readonly property color separator: separatorColor

    readonly property color accent: {
        var a = Appearance.accent;
        if (a === "teal") return systemTeal;
        if (a === "amber") return systemOrange;
        if (a === "violet") return systemIndigo;
        if (a === "purple") return systemPurple;
        if (a === "pink") return systemPink;
        if (a === "green") return systemGreen;
        if (a === "graphite") return systemGray;
        return controlAccentColor;
    }

    readonly property color accentHover: Qt.lighter(accent, isDark ? 1.12 : 1.08)
    readonly property color accentPressed: Qt.darker(accent, 1.15)
    readonly property color accentText: "#FFFFFF"

    readonly property color selection: selectedContentBackgroundColor
    readonly property color selectionText: "#FFFFFF"
    readonly property color focusRing: keyboardFocusIndicatorColor

    readonly property color destructive: systemRed
    readonly property color destructiveHover: Qt.darker(systemRed, 1.12)
    readonly property color destructiveText: "#FFFFFF"

    readonly property color warning: systemOrange
    readonly property color warningText: "#FFFFFF"

    readonly property color success: systemGreen
    readonly property color successText: "#FFFFFF"
}
