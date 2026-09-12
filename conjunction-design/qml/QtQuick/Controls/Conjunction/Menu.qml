import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.Menu {
    id: control

    implicitWidth: Math.max(160, contentItem.implicitWidth)
    implicitHeight: contentItem.implicitHeight + Spacing.xs * 2
    padding: Spacing.xs


    contentItem: ListView {
        implicitHeight: contentHeight
        model: control.contentModel
        currentIndex: control.currentIndex
        clip: true
    }

    background: Surface {
        elevation: "popover"
    }
}
