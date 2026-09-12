import QtQuick

Rectangle {
    id: ring

    property Item target: parent
    property bool active: target ? (target.activeFocus && FocusModel.keyboardNavigationActive) : false
    property int offset: Geometry.focusRingOffset
    property int ringThickness: Geometry.focusRingThickness
    property color ringColor: Theme.focusRing

    visible: active
    color: "transparent"
    border.color: ringColor
    border.width: ringThickness
    radius: (target && target.radius !== undefined) ? (target.radius + offset) : (Geometry.radiusMedium + offset)

    anchors.fill: target
    anchors.margins: -offset

    // Non-intrusive to input
    enabled: false
}
