import QtQuick

Rectangle {
    id: root

    // Elevation levels: base, raised, popover, dialog
    property string elevation: "base"

    color: (elevation === "base") ? Theme.surface : Theme.surfaceElevated
    radius: (elevation === "dialog") ? Geometry.radiusLarge : Geometry.radiusMedium
    border.color: Theme.separator
    border.width: Geometry.separatorThickness

    // Subtle soft shadow effect for raised surfaces without expensive shader blur
    Rectangle {
        id: shadow
        visible: root.elevation !== "base"
        anchors.fill: parent
        anchors.topMargin: (root.elevation === "raised") ? 1 : ((root.elevation === "popover") ? 2 : 4)
        z: -1
        radius: root.radius
        color: Theme.isDark ? "#10000000" : "#1A000000"
    }
}
