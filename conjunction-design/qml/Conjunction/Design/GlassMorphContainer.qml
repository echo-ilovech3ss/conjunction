import QtQuick

Item {
    id: root

    // SPEC §1.4 Smooth-min EffectContainer (spacing = 24 pt, k = 0.60 * spacing)
    property real spacing: 24.0
    property string variant: "clear"
    property bool darkMode: Appearance.isDark
    property bool reduceTransparency: Appearance.shouldReduceTransparency
    property bool highContrast: Appearance.shouldIncreaseContrast
    property Item backdropItem: null

    // Up to 4 pill rectangles encoded as Qt.rect(x, y, w, h) with matching radii list
    property var pillRects: []
    property var pillRadii: []

    readonly property real captureMargin: 48.0
    readonly property bool isClear: variant === "clear"
    readonly property real sigmaPt: isClear ? 20.0 : (darkMode ? 10.5 : 14.0)
    readonly property bool hasLiveBackdrop: backdropItem !== null && !reduceTransparency && width > 1 && height > 1

    function rectVec(idx) {
        if (!pillRects || idx >= pillRects.length) return Qt.vector4d(0, 0, 1, 1);
        var r = pillRects[idx];
        return Qt.vector4d(r.x + r.width * 0.5, r.y + r.height * 0.5, r.width * 0.5, r.height * 0.5);
    }

    function radAt(idx) {
        if (pillRadii && idx < pillRadii.length) return pillRadii[idx];
        if (pillRects && idx < pillRects.length) return Math.min(pillRects[idx].width, pillRects[idx].height) * 0.5;
        return 16.0;
    }

    function computeCaptureRect() {
        if (!backdropItem || width <= 0 || height <= 0) return Qt.rect(0, 0, 1, 1);
        var pt = root.mapToItem(backdropItem, 0, 0);
        return Qt.rect(pt.x - captureMargin, pt.y - captureMargin, width + 2.0 * captureMargin, height + 2.0 * captureMargin);
    }

    readonly property rect captureRect: {
        var _a = root.width + root.height + root.x + root.y;
        return computeCaptureRect();
    }
    readonly property int blurTexW: Math.max(4, Math.round(captureRect.width * 0.5))
    readonly property int blurTexH: Math.max(4, Math.round(captureRect.height * 0.5))

    ShaderEffectSource {
        id: rawCapture
        visible: false
        live: root.hasLiveBackdrop
        sourceItem: root.hasLiveBackdrop ? root.backdropItem : null
        sourceRect: root.captureRect
        textureSize: Qt.size(root.blurTexW, root.blurTexH)
        smooth: true
    }

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

    ShaderEffect {
        id: morphShader
        anchors.fill: parent
        visible: root.width > 0 && root.height > 0 && status !== ShaderEffect.Error
        readonly property variant u_backdropBlur: root.hasLiveBackdrop ? blurVSource : dummyTex
        readonly property vector4d u_params0: Qt.vector4d(root.isClear ? 1.0 : 0.0, root.darkMode ? 1.0 : 0.0, root.reduceTransparency ? 1.0 : 0.0, root.highContrast ? 1.0 : 0.0)
        readonly property vector4d u_geom: Qt.vector4d(root.width, root.height, root.spacing, Math.min(4, root.pillRects ? root.pillRects.length : 0))
        readonly property vector4d u_bgInfo: Qt.vector4d(root.captureRect.width, root.captureRect.height, root.captureMargin, root.hasLiveBackdrop ? 1.0 : 0.0)
        readonly property vector4d u_pill0: root.rectVec(0)
        readonly property vector4d u_pill1: root.rectVec(1)
        readonly property vector4d u_pill2: root.rectVec(2)
        readonly property vector4d u_pill3: root.rectVec(3)
        readonly property vector4d u_radii: Qt.vector4d(root.radAt(0), root.radAt(1), root.radAt(2), root.radAt(3))

        vertexShader: Qt.resolvedUrl("shaders/morph_glass.vert.qsb")
        fragmentShader: Qt.resolvedUrl("shaders/morph_glass.frag.qsb")
    }
}
