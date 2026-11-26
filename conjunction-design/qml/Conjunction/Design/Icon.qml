import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

Item {
    id: root

    property string name: ""
    property int size: 16
    property color color: Theme.textPrimary

    // SPEC §2.4 Material Symbols Rounded variable axes
    property real fill: 0        // 0 = outline, 1 = filled
    property int weight: 400     // 300..600
    property int grade: 0        // -25..25 (+25 dark bg)
    property int opsz: 20        // 20 / 24 / 48
    property bool preferPhosphor: false

    readonly property string phosphorPath: Icons.getPhosphorUrl(name, weight >= 500)
    readonly property bool usePhosphor: phosphorPath !== "" && (preferPhosphor || Icons.preferPhosphorFallback(name))
    readonly property string materialGlyph: Icons.getMaterialGlyph(name)
    readonly property string effectiveGlyph: (materialGlyph !== "" && Icons.getPath(name) === "") ? materialGlyph : ((!usePhosphor && Icons.getPath(name) === "" && name !== "") ? "\ue5c3" : "")

    width: size
    height: size
    implicitWidth: size
    implicitHeight: size
    clip: true

    // Phosphor SVG renderer when specifically requested or missing from Material
    Item {
        id: phosphorLayer
        anchors.fill: parent
        visible: root.usePhosphor

        Image {
            id: phosphorImg
            anchors.fill: parent
            source: root.usePhosphor ? ("file://" + root.phosphorPath) : ""
            sourceSize.width: Math.max(16, root.size * 2)
            sourceSize.height: Math.max(16, root.size * 2)
            fillMode: Image.PreserveAspectFit
            visible: false
        }

        MultiEffect {
            anchors.fill: phosphorImg
            source: phosphorImg
            colorization: 1.0
            colorizationColor: root.color
            brightness: 1.0
        }
    }

    // Material Symbols Rounded variable-font symbol renderer (SPEC §2.4)
    Text {
        id: symbolText
        visible: !root.usePhosphor && root.effectiveGlyph !== ""
        anchors.centerIn: parent
        text: root.effectiveGlyph
        color: root.color
        font.family: Typography.symbolFamily
        font.pixelSize: Math.max(10, root.size)
        font.weight: root.weight
        font.variableAxes: ({
            "FILL": root.fill,
            "wght": root.weight,
            "GRAD": root.grade,
            "opsz": root.opsz
        })
        renderType: Text.QtRendering
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
    }

    // Fallback SVG path if requested icon exists in pathMap
    Shape {
        id: shapeFallback
        visible: !root.usePhosphor && Icons.getPath(root.name) !== ""
        anchors.fill: parent

        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            strokeWidth: 0
            scale: Qt.size(root.width / 24.0, root.height / 24.0)

            PathSvg {
                path: Icons.getPath(root.name)
            }
        }
    }
}
