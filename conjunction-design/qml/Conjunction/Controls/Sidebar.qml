import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Item {
    id: root

    property int currentIndex: 0
    property Item backdropItem: null
    default property alias data: contentCol.data

    implicitWidth: 216
    implicitHeight: 400

    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.List
    Accessible.name: "Sidebar Navigation"

    GlassSurface {
        anchors.fill: parent
        variant: "regular"
        cornerRadius: 0
        backdropItem: root.backdropItem
        shadowPreset: "none"
        rimIntensityScale: 0.4
    }

    Flickable {
        id: sidebarFlick
        anchors.fill: parent
        anchors.margins: Spacing.inset // 10 pt inset matching cr=10 pills
        contentHeight: Math.max(height, contentCol.implicitHeight)
        clip: true

        ColumnLayout {
            id: contentCol
            width: parent.width
            height: Math.max(sidebarFlick.height, implicitHeight)
            spacing: 2
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: Geometry.separatorThickness
        color: Theme.separatorColor
    }

    FocusRing {
        target: root
        isTextInput: false
    }
}
