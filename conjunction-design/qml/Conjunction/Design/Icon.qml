import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property string name: ""
    property int size: 16
    property color color: Theme.textPrimary

    width: size
    height: size

    Shape {
        id: shape
        anchors.fill: parent
        asynchronous: true
        layer.enabled: true
        layer.samples: 4

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
