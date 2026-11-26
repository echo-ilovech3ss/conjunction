pragma Singleton
import QtQuick

QtObject {
    id: root

    // SPEC §2.4 Open Substitute Font Families
    readonly property string sansTextFamily: "Inter"
    readonly property string sansDisplayFamily: "Inter Display"
    readonly property string monoFamily: "JetBrains Mono"
    readonly property string symbolFamily: "Material Symbols Rounded"

    // Legacy aliases
    readonly property string sansFamily: sansTextFamily

    readonly property real scale: Appearance.fontScale

    // SPEC §2.4 Option A Optical Cap-Height Scaling (0.9685x Inter / 0.9652x JetBrains Mono)
    readonly property real capScaleSans: Appearance.useOpticalCapScaling ? 0.9685 : 1.0
    readonly property real capScaleMono: Appearance.useOpticalCapScaling ? 0.9652 : 1.0

    function makeSpecFont(targetPt, weight, trackingEm, useMono, tabularNums) {
        var fam = useMono ? monoFamily : (targetPt >= 20 ? sansDisplayFamily : sansTextFamily);
        var capScale = useMono ? capScaleMono : capScaleSans;
        var renderedPx = Math.max(8, targetPt * capScale * scale);
        var spec = {
            family: fam,
            pixelSize: renderedPx,
            weight: weight,
            letterSpacing: trackingEm * renderedPx
        };
        if (tabularNums) {
            spec.features = { "tnum": 1 };
        }
        return Qt.font(spec);
    }

    function makeFont(ptSize, weight, isMono) {
        var trk = isMono ? 0.0 : (ptSize >= 26 ? -0.0034 : (ptSize >= 22 ? -0.0024 : -0.0010));
        return makeSpecFont(ptSize, weight, trk, isMono, false);
    }

    // SPEC §2.4 Semantic Type Scale
    readonly property font largeTitle: makeSpecFont(26, Font.Normal, -0.0034, false, false)
    readonly property font title1: makeSpecFont(22, Font.Normal, -0.0024, false, false)
    readonly property font title2: makeSpecFont(17, Font.Normal, -0.0010, false, false)
    readonly property font title2Bold: makeSpecFont(17, Font.Bold, -0.0010, false, false)
    readonly property font title3: makeSpecFont(15, Font.Normal, -0.0010, false, false)
    readonly property font title3SemiBold: makeSpecFont(15, Font.DemiBold, -0.0010, false, false)
    readonly property font headline: makeSpecFont(13, Font.DemiBold, -0.0010, false, false)
    readonly property font headlineBold: makeSpecFont(13, Font.Bold, -0.0010, false, false)
    readonly property font body: makeSpecFont(13, Font.Normal, -0.0010, false, false)
    readonly property font bodyMedium: makeSpecFont(13, Font.Medium, -0.0010, false, false)
    readonly property font callout: makeSpecFont(12, Font.Normal, -0.0010, false, false)
    readonly property font subheadline: makeSpecFont(11, Font.Normal, -0.0010, false, false)
    readonly property font subheadlineBold: makeSpecFont(11, Font.Bold, -0.0010, false, false)
    readonly property font subheadlineTnum: makeSpecFont(11, Font.Normal, -0.0010, false, true)
    readonly property font footnote: makeSpecFont(10, Font.Normal, -0.0010, false, false)
    readonly property font caption1: footnote
    readonly property font caption2: makeSpecFont(10, Font.Medium, -0.0010, false, false)
    readonly property font miniControl: makeSpecFont(9, Font.Normal, -0.0010, false, false)
    readonly property font codeMono: makeSpecFont(13, Font.Normal, 0.0, true, true)
    readonly property font terminalMono: makeSpecFont(12, Font.Normal, 0.0, true, true)
    readonly property font menuBarClock: makeSpecFont(13, Font.Normal, -0.0010, false, true)

    // Legacy compatibility roles
    readonly property font display: largeTitle
    readonly property font windowTitle: title3SemiBold
    readonly property font sectionHeading: headline
    readonly property font secondaryBody: callout
    readonly property font caption: caption2
    readonly property font controlLabel: body
    readonly property font monospace: codeMono
    readonly property font title: title1

    // Line-height helpers (SPEC §2.4)
    function lineHeightFor(roleName) {
        if (roleName === "largeTitle") return 39 * scale;
        if (roleName === "title1") return 33 * scale;
        if (roleName === "title2") return 27 * scale;
        if (roleName === "title3") return 24 * scale;
        if (roleName === "callout") return 18 * scale;
        if (roleName === "subheadline") return 17 * scale;
        if (roleName === "footnote" || roleName === "caption1" || roleName === "caption2") return 16 * scale;
        if (roleName === "miniControl") return 11 * scale;
        return 19 * scale;
    }
}
