import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Rectangle {
    id: root

    property int currentIndex: 0
    default property alias data: contentCol.data

    implicitWidth: 200
    color: Theme.surfaceSecondary
    border.color: Theme.separator
    border.width: Geometry.separatorThickness

    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.List
    Accessible.name: "Sidebar Navigation"

    Flickable {
        anchors.fill: parent
        anchors.margins: Spacing.xs
        contentHeight: contentCol.implicitHeight
        clip: true

        ColumnLayout {
            id: contentCol
            width: parent.width
            spacing: Spacing.xxs
        }
    }

    FocusRing {
        active: root.activeFocus && FocusModel.keyboardNavigationActive
        target: root
    }
}
