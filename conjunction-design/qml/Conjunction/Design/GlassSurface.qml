import QtQuick

Item {
    id: root

    // Material variant: "regular" or "clear" (SPEC §1.2)
    property string variant: "regular"
    property real cornerRadius: Geometry.radiusWindow
    property bool darkMode: Appearance.isDark
    property bool reduceTransparency: Appearance.shouldReduceTransparency
    property bool highContrast: Appearance.shouldIncreaseContrast

    // Optional sRGB tint (alpha = 0 disables tint; Regular forces monochrome luminance)
    property color tintColor: Qt.rgba(0, 0, 0, 0)

    // Shadow preset: "none", "pill" (0.14), "popover" (0.24), "window" (0.34), "inactiveWindow" (0.18)
    property string shadowPreset: "pill"

    // Optional live backdrop Item behind this surface (must be a sibling/background layer, NOT an ancestor containing root)
    property Item backdropItem: null

    // Scroll-edge pocket (SPEC §1.3): "none", "soft", "hard"
    property string scrollPocketMode: "none"
    property real pocketHeight: 54.0
    property bool pocketAtTop: false
    property real rimIntensityScale: 1.0

    // Margin around glass bounds captured for inward radial refraction (max dr = 45.21 pt -> 48 pt)
    readonly property real captureMargin: 48.0
    readonly property real minDim: Math.min(Math.max(width, 1), Math.max(height, 1))
    readonly property bool isClear: variant === "clear"

    // SPEC §1.2 Primary Blur sigma_pt formula
    readonly property real sigmaPt: {
        if (reduceTransparency) return 0.0;
        if (isClear) {
            var t = Math.max(0.0, Math.min(1.0, (minDim - 48.0) / 72.0));
            return 2.0 * (5.0 + 5.0 * t); // 10..20 pt (20.0 pt for m >= 120)
        }
        return darkMode ? 10.5 : 14.0;
    }

    function concentricInnerRadius(padding) {
        return Geometry.concentricRadius(cornerRadius, padding);
    }

    readonly property bool hasLiveBackdrop: backdropItem !== null && !reduceTransparency && width > 1 && height > 1

    // Map root's bounds into backdropItem coordinates expanded by captureMargin
    function computeCaptureRect() {
        if (!backdropItem || width <= 0 || height <= 0) {
            return Qt.rect(0, 0, 1, 1);
        }
        var pt = root.mapToItem(backdropItem, 0, 0);
        return Qt.rect(pt.x - captureMargin, pt.y - captureMargin, width + 2.0 * captureMargin, height + 2.0 * captureMargin);
    }

    readonly property rect captureRect: {
        // Trigger re-evaluation cleanly on geometry/position changes
        var _w = root.width;
        var _h = root.height;
        var _x = root.x;
        var _y = root.y;
        return computeCaptureRect();
    }

    // Half-res blur target dims (1 texel = 2 pt -> stepPt = 2.0 pt)
    readonly property int blurTexW: Math.max(4, Math.round(captureRect.width * 0.5))
    readonly property int blurTexH: Math.max(4, Math.round(captureRect.height * 0.5))

    // SPEC §2.5 Outer Drop Shadow layers
    readonly property real shadowScale: shadowPreset === "inactiveWindow" ? 0.52 : 1.0
    readonly property real shadowY: shadowPreset === "window" || shadowPreset === "inactiveWindow" ? 18 : (shadowPreset === "popover" ? 8 : 2)
    readonly property real shadowSpread: shadowPreset === "window" || shadowPreset === "inactiveWindow" ? 26 : (shadowPreset === "popover" ? 14 : 6)
    readonly property real shadowAlpha: shadowPreset === "none" ? 0.0 : ((shadowPreset === "window" || shadowPreset === "inactiveWindow" ? 0.28 : (shadowPreset === "popover" ? 0.20 : 0.12)) * shadowScale)

    Rectangle {
        visible: root.shadowPreset !== "none" && root.width > 0 && root.height > 0
        z: -2
        x: -root.shadowSpread * 0.65
        y: root.shadowY - root.shadowSpread * 0.45
        width: root.width + 1.3 * root.shadowSpread
        height: root.height + 1.3 * root.shadowSpread
        radius: Math.min(root.cornerRadius + root.shadowSpread * 0.5, Math.min(width, height) * 0.5)
        color: Qt.rgba(0, 0, 0, root.shadowAlpha)
    }

    Rectangle {
        visible: root.shadowPreset !== "none" && root.width > 0 && root.height > 0
        z: -1
        x: -1
        y: 1
        width: root.width + 2
        height: root.height + 2
        radius: Math.min(root.cornerRadius + 1, Math.min(width, height) * 0.5)
        color: Qt.rgba(0, 0, 0, (root.shadowPreset === "window" ? 0.22 : 0.10) * root.shadowScale)
    }

    // Pass 0: Backdrop capture
    ShaderEffectSource {
        id: rawCapture
        visible: false
        live: root.hasLiveBackdrop
        sourceItem: root.hasLiveBackdrop ? root.backdropItem : null
        sourceRect: root.captureRect
        textureSize: Qt.size(root.blurTexW, root.blurTexH)
        smooth: true
    }

    // Pass 1: Horizontal Gaussian Blur -> BlurH FBO
    ShaderEffect {
        id: blurHPass
        visible: root.hasLiveBackdrop
        x: 0; y: 0
        width: root.blurTexW
        height: root.blurTexH
        readonly property variant source: rawCapture
        readonly property vector4d u_blurParams: Qt.vector4d(root.sigmaPt, 1.0 / root.blurTexW, 1.0 / root.blurTexH, 2.0)
        vertexShader: Qt.resolvedUrl("shaders/glass_blur.vert.qsb")
        fragmentShader: Qt.resolvedUrl("shaders/glass_blur_h.frag.qsb")
    }

    ShaderEffectSource {
        id: blurHSource
        visible: false
        hideSource: true
        live: root.hasLiveBackdrop
        sourceItem: root.hasLiveBackdrop ? blurHPass : null
        textureSize: Qt.size(root.blurTexW, root.blurTexH)
        smooth: true
    }

    // Pass 2: Vertical Gaussian Blur -> BlurV FBO
    ShaderEffect {
        id: blurVPass
        visible: root.hasLiveBackdrop
        x: 0; y: 0
        width: root.blurTexW
        height: root.blurTexH
        readonly property variant source: blurHSource
        readonly property vector4d u_blurParams: Qt.vector4d(root.sigmaPt, 1.0 / root.blurTexW, 1.0 / root.blurTexH, 2.0)
        vertexShader: Qt.resolvedUrl("shaders/glass_blur.vert.qsb")
        fragmentShader: Qt.resolvedUrl("shaders/glass_blur_v.frag.qsb")
    }

    ShaderEffectSource {
        id: blurVSource
        visible: false
        hideSource: true
        live: root.hasLiveBackdrop
        sourceItem: root.hasLiveBackdrop ? blurVPass : null
        textureSize: Qt.size(root.blurTexW, root.blurTexH)
        smooth: true
    }

    // Pass 3: Liquid Glass Optical Composition (SPEC §1.1 & §1.6)
    ShaderEffect {
        id: glassShader
        anchors.fill: parent
        visible: root.width > 0 && root.height > 0 && status !== ShaderEffect.Error

        readonly property variant u_backdropBlur: root.hasLiveBackdrop ? blurVSource : dummyTex
        readonly property vector4d u_tintColor: Qt.vector4d(root.tintColor.r, root.tintColor.g, root.tintColor.b, root.tintColor.a)
        readonly property vector4d u_params0: Qt.vector4d(root.isClear ? 1.0 : 0.0, root.darkMode ? 1.0 : 0.0, root.reduceTransparency ? 1.0 : 0.0, root.highContrast ? 1.0 : 0.0)
        readonly property vector4d u_geom: Qt.vector4d(root.width, root.height, root.cornerRadius, root.captureMargin)
        readonly property vector4d u_bgInfo: Qt.vector4d(root.captureRect.width, root.captureRect.height, root.scrollPocketMode === "hard" ? 2.0 : (root.scrollPocketMode === "soft" ? 1.0 : 0.0), root.pocketHeight)
        readonly property vector4d u_extra: Qt.vector4d(root.hasLiveBackdrop ? 1.0 : 0.0, 0.5, root.rimIntensityScale, root.pocketAtTop ? 1.0 : 0.0)

        vertexShader: Qt.resolvedUrl("shaders/liquid_glass.vert.qsb")
        fragmentShader: Qt.resolvedUrl("shaders/liquid_glass.frag.qsb")
    }

    // Hidden 1x1 dummy item so sampler binding 1 is always bound cleanly when no backdrop exists
    Rectangle {
        id: dummyItem
        visible: false
        width: 2
        height: 2
        color: root.darkMode ? "#282828" : "#ECECEC"
    }
    ShaderEffectSource {
        id: dummyTex
        visible: false
        sourceItem: dummyItem
        live: false
    }

    // Minimal clean fallback only on shader error
    Rectangle {
        anchors.fill: parent
        visible: glassShader.status === ShaderEffect.Error
        radius: root.cornerRadius
        color: root.reduceTransparency
            ? (root.darkMode ? "#282828" : "#ECECEC")
            : (root.darkMode ? Qt.rgba(0.16, 0.16, 0.18, 0.78) : Qt.rgba(0.95, 0.96, 0.98, 0.72))
        border.color: root.highContrast ? Theme.highContrastBorderColor : (root.darkMode ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.65))
        border.width: root.highContrast ? 1.0 : 0.75
    }
}
