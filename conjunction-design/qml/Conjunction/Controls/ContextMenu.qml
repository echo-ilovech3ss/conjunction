import QtQuick
import Conjunction.Design

MouseArea {
    id: root

    property Menu menu: null
    anchors.fill: parent
    acceptedButtons: Qt.RightButton

    onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton && menu) {
            menu.popup(mouse.x, mouse.y);
        }
    }
}
