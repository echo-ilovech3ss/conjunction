import QtQuick

Item {
    id: ring

    property Item target: parent
    property bool isTextInput: false
    property bool active: target ? FocusModel.shouldShowRing(target, isTextInput) : false
    property real offset: Geometry.focusRingOffset
    property real ringThickness: Geometry.focusRingThickness
    property color ringColor: Theme.keyboardFocusIndicatorColor
    property color innerColor: Theme.keyboardFocusInnerColor

    visible: active
    enabled: false
    z: 999

    anchors.fill: target ? target : parent
    anchors.margins: -offset

    readonly property real baseRadius: (target && target.radius !== undefined) ? target.radius : Geometry.radiusSmall
    readonly property bool isPill: target && baseRadius >= Math.min(target.width, target.height) * 0.49
    readonly property real haloRadius: isPill ? (Math.min(width, height) * 0.5) : (baseRadius + offset)
    readonly property real crispRadius: isPill ? (target ? Math.min(target.width, target.height) * 0.5 : haloRadius) : baseRadius

    // Outer 3.5 pt soft halo (SPEC §2.7)
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: ring.haloRadius
        border.color: ring.ringColor
        border.width: ring.ringThickness
    }

    // Inner 0.75-1.0 pt crisp line at high accent saturation
    Rectangle {
        anchors.fill: parent
        anchors.margins: ring.offset
        color: "transparent"
        radius: ring.crispRadius
        border.color: Qt.rgba(ring.innerColor.r, ring.innerColor.g, ring.innerColor.b, 0.90)
        border.width: Appearance.shouldIncreaseContrast ? 1.0 : Geometry.focusRingInnerThickness
    }
}
