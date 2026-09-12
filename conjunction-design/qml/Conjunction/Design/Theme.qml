pragma Singleton
import QtQuick

QtObject {
    id: root

    readonly property bool isDark: Appearance.isDark

    // Canvas / Root background
    readonly property color background: isDark ? "#1A1B20" : "#F4F5F8"

    // Primary content surface (cards, window background)
    readonly property color surface: isDark ? "#24262E" : "#FFFFFF"

    // Elevated surface (dialogs, popovers, headers)
    readonly property color surfaceElevated: isDark ? "#2D303A" : "#FFFFFF"

    // Secondary / recessed surface
    readonly property color surfaceSecondary: isDark ? "#1F2026" : "#EAECEF"

    // Primary text
    readonly property color textPrimary: isDark ? "#F5F6F8" : "#15161A"

    // Secondary text
    readonly property color textSecondary: isDark ? "#9EA2AD" : "#5A5D66"

    // Disabled text
    readonly property color textDisabled: isDark ? "#5D6069" : "#9DA0A8"

    // Separators & borders
    readonly property color separator: isDark ? "#373A44" : "#D3D6DC"

    // Interactive Accent Color (mapped from Appearance.accent)
    readonly property color accent: {
        var a = Appearance.accent;
        if (a === "teal") return isDark ? "#1A9988" : "#0D7D6C";
        if (a === "amber") return isDark ? "#D97706" : "#B45309";
        if (a === "violet") return isDark ? "#8B5CF6" : "#6D28D9";
        if (a === "graphite") return isDark ? "#9CA3AF" : "#4B5563";
        // Default: blue
        return isDark ? "#2563EB" : "#1D4ED8";
    }

    readonly property color accentHover: {
        var a = Appearance.accent;
        if (a === "teal") return isDark ? "#22AB99" : "#0B6658";
        if (a === "amber") return isDark ? "#F59E0B" : "#92400E";
        if (a === "violet") return isDark ? "#A78BFA" : "#5B21B6";
        if (a === "graphite") return isDark ? "#D1D5DB" : "#374151";
        return isDark ? "#3B82F6" : "#1E40AF";
    }

    readonly property color accentPressed: {
        var a = Appearance.accent;
        if (a === "teal") return isDark ? "#147A6D" : "#084C42";
        if (a === "amber") return isDark ? "#B45309" : "#78350F";
        if (a === "violet") return isDark ? "#7C3AED" : "#4C1D95";
        if (a === "graphite") return isDark ? "#6B7280" : "#1F2937";
        return isDark ? "#1D4ED8" : "#172554";
    }

    readonly property color accentText: "#FFFFFF"

    // Selection
    readonly property color selection: isDark ? "#1E3A5F" : "#DBEAFE"
    readonly property color selectionText: isDark ? "#F5F6F8" : "#15161A"

    // Keyboard Focus Ring
    readonly property color focusRing: isDark ? "#60A5FA" : "#2563EB"

    // Semantic States
    readonly property color destructive: isDark ? "#EF4444" : "#DC2626"
    readonly property color destructiveHover: isDark ? "#F87171" : "#B91C1C"
    readonly property color destructiveText: "#FFFFFF"

    readonly property color warning: isDark ? "#F59E0B" : "#D97706"
    readonly property color warningText: isDark ? "#15161A" : "#FFFFFF"

    readonly property color success: isDark ? "#10B981" : "#059669"
    readonly property color successText: "#FFFFFF"
}
