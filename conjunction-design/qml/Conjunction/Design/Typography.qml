pragma Singleton
import QtQuick

QtObject {
    id: root

    readonly property string sansFamily: "DejaVu Sans, Liberation Sans, Noto Sans, sans-serif"
    readonly property string monoFamily: "DejaVu Sans Mono, Liberation Mono, Noto Sans Mono, monospace"

    readonly property real scale: Appearance.fontScale

    // Helper functions returning font objects
    function makeFont(ptSize, weight, isMono) {
        var f = Qt.font({
            family: isMono ? monoFamily : sansFamily,
            pointSize: Math.round(ptSize * scale),
            weight: weight
        });
        return f;
    }

    readonly property font display: makeFont(24, Font.Bold, false)
    readonly property font windowTitle: makeFont(16, Font.DemiBold, false)
    readonly property font sectionHeading: makeFont(13, Font.DemiBold, false)
    readonly property font body: makeFont(11, Font.Normal, false)
    readonly property font secondaryBody: makeFont(10, Font.Normal, false)
    readonly property font caption: makeFont(9, Font.Normal, false)
    readonly property font controlLabel: makeFont(11, Font.Medium, false)
    readonly property font monospace: makeFont(10, Font.Normal, true)
    readonly property font title: makeFont(16, Font.DemiBold, false)
    readonly property font headline: makeFont(13, Font.DemiBold, false)
}
