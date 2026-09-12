pragma Singleton
import QtQuick

QtObject {
    id: root

    readonly property int instant: 0
    readonly property int fast: 100
    readonly property int normal: 200
    readonly property int slow: 350

    // Easing curves
    readonly property int easingStandard: Easing.OutCubic
    readonly property int easingDecelerate: Easing.OutQuad
    readonly property int easingAccelerate: Easing.InQuad

    function duration(baseDuration) {
        if (Appearance.reducedMotion) {
            return instant;
        }
        return baseDuration;
    }
}
