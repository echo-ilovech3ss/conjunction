import QtQuick

Item {
    id: root

    property real radius: Geometry.radiusMedium
    property color color: Theme.surface
    property color borderColor: "transparent"
    property real borderWidth: 0

    implicitWidth: 100
    implicitHeight: 40

    readonly property url fragUrl: Qt.resolvedUrl("shaders/squircle_shape.frag.qsb")
    readonly property url vertUrl: Qt.resolvedUrl("shaders/squircle_shape.vert.qsb")

    // GPU Continuous superellipse SDF shader (SPEC §2.1: 1.528665x corner tangent)
    ShaderEffect {
        id: sdfEffect
        anchors.fill: parent
        visible: root.width > 0 && root.height > 0 && status !== ShaderEffect.Error

        readonly property vector4d u_fillColor: Qt.vector4d(root.color.r, root.color.g, root.color.b, root.color.a)
        readonly property vector4d u_borderColor: Qt.vector4d(root.borderColor.r, root.borderColor.g, root.borderColor.b, root.borderColor.a)
        readonly property vector4d u_geom: Qt.vector4d(root.width, root.height, root.radius, root.borderWidth)

        vertexShader: root.vertUrl
        fragmentShader: root.fragUrl
    }

    // Clean Rectangle fallback only on shader error
    Rectangle {
        anchors.fill: parent
        visible: sdfEffect.status === ShaderEffect.Error
        radius: root.radius
        color: root.color
        border.color: root.borderColor
        border.width: root.borderWidth
    }
}
