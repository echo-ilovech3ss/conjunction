pragma Singleton
import QtQuick

QtObject {
    id: root

    // SPEC §3.1 Transition Timing & Spring Constants (ms)
    readonly property int instant: 0
    readonly property int hoverSwap: 25
    readonly property int menuOpen: 65
    readonly property int fast: 80
    readonly property int menuClose: 133
    readonly property int controlCenterOpen: 148
    readonly property int popoverClose: 150
    readonly property int popoverOpen: 158
    readonly property int windowClose: 167
    readonly property int quickSearchOpen: 170
    readonly property int reducedMotionFade: 180
    readonly property int dockMagnifyExit: 183
    readonly property int normal: 200
    readonly property int unminimizeScale: 200
    readonly property int minimizeScale: 203
    readonly property int dockMagnifyEnter: 208
    readonly property int quickSearchClose: 217
    readonly property int windowOpen: 240
    readonly property int notificationClose: 242
    readonly property int controlCenterClose: 260
    readonly property int dockHide: 292
    readonly property int notificationOpen: 300
    readonly property int dockShow: 303
    readonly property int genieUnminimize: 310
    readonly property int sheetClose: 333
    readonly property int sheetOpen: 335
    readonly property int slow: 350
    readonly property int genieMinimize: 425
    readonly property int missionControlExit: 492
    readonly property int missionControlEnter: 525
    readonly property int spacesSwipe: 550
    readonly property int dockBouncePeriod: 680

    // Spring Parameters (mass = 1.0, stiffness, damping)
    readonly property real windowOpenStiffness: 380
    readonly property real windowOpenDamping: 32
    readonly property real dockShowStiffness: 340
    readonly property real dockShowDamping: 34
    readonly property real dockMagnifyStiffness: 420
    readonly property real dockMagnifyDamping: 34
    readonly property real sheetStiffness: 280
    readonly property real sheetDamping: 33
    readonly property real popoverOpenStiffness: 450
    readonly property real popoverOpenDamping: 35
    readonly property real controlCenterStiffness: 460
    readonly property real controlCenterDamping: 36
    readonly property real notificationStiffness: 300
    readonly property real notificationDamping: 33
    readonly property real quickSearchStiffness: 440
    readonly property real quickSearchDamping: 35
    readonly property real missionControlStiffness: 220
    readonly property real missionControlDamping: 29

    // Standard Easing Curves
    readonly property int easingStandard: Easing.OutCubic
    readonly property int easingDecelerate: Easing.OutQuad
    readonly property int easingAccelerate: Easing.InQuad
    readonly property int easingReduced: Easing.InOutQuad
    readonly property var curveWindowClose: [0.22, 0.61, 0.36, 1.0, 1.0, 1.0]
    readonly property var curveGenie: [0.42, 0.0, 0.58, 1.0, 1.0, 1.0]
    readonly property var curveScaleMinimize: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0]
    readonly property var curveScaleUnminimize: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]
    readonly property var curvePanelClose: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]

    function duration(baseDuration) {
        if (Appearance.reducedMotion) {
            return baseDuration <= hoverSwap ? instant : reducedMotionFade;
        }
        return baseDuration;
    }

    function spatialDuration(baseDuration) {
        return Appearance.reducedMotion ? instant : baseDuration;
    }

    // SPEC §3.2 Cosine Half-Wave Dock Magnification Formula
    function dockScaleAtDistance(distPx, baseTileSize, maxTileSize, slotPitch) {
        if (Appearance.reducedMotion) return baseTileSize;
        var R = 3.0 * slotPitch;
        if (Math.abs(distPx) >= R || maxTileSize <= baseTileSize) {
            return baseTileSize;
        }
        return baseTileSize + (maxTileSize - baseTileSize) * Math.cos((Math.PI * 0.5) * (Math.abs(distPx) / R));
    }
}
