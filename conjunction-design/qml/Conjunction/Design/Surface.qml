import QtQuick

Item {
    id: root

    // Elevation levels: base, raised, popover, dialog (SPEC §2.5)
    property string elevation: "base"
    property real radius: (elevation === "dialog") ? Geometry.radiusLarge : ((elevation === "popover") ? Geometry.radiusPopover : Geometry.radiusMedium)
    property color color: (elevation === "base") ? Theme.surface : Theme.surfaceElevated
    property color borderColor: Appearance.shouldIncreaseContrast ? Theme.highContrastBorderColor : Theme.separator
    property real borderWidth: Geometry.separatorThickness
    property bool activeWindow: true

    // SPEC §2.5 Multi-tier ambient + contact drop shadow behind raised surfaces
    Rectangle {
        id: ambientShadow
        visible: root.elevation !== "base" && root.width > 0 && root.height > 0
        z: -2
        readonly property real spread: (root.elevation === "dialog") ? 18 : ((root.elevation === "popover") ? 10 : 3)
        readonly property real yOff: (root.elevation === "dialog") ? 12 : ((root.elevation === "popover") ? 6 : 2)
        x: -spread
        y: yOff - spread * 0.35
        width: root.width + 2 * spread
        height: root.height + 2 * spread
        radius: root.radius + spread * 0.5
        color: {
            var baseAlpha = (root.elevation === "dialog") ? 0.14 : ((root.elevation === "popover") ? 0.12 : 0.08);
            if (!root.activeWindow) baseAlpha *= 0.52;
            return Qt.rgba(0, 0, 0, baseAlpha);
        }
    }

    Rectangle {
        id: contactShadow
        visible: root.elevation !== "base" && root.width > 0 && root.height > 0
        z: -1
        x: -1
        y: 1
        width: root.width + 2
        height: root.height + 2
        radius: root.radius + 1
        color: {
            var a = (root.elevation === "dialog") ? 0.18 : 0.12;
            if (!root.activeWindow) a *= 0.52;
            return Qt.rgba(0, 0, 0, a);
        }
    }

    SquircleRect {
        id: bodyShape
        anchors.fill: parent
        radius: root.radius
        color: root.color
        borderColor: root.borderColor
        borderWidth: root.borderWidth
    }
}
