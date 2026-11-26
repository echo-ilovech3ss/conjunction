import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Conjunction.Design
import Conjunction.Controls

// SPEC §4.7 Files Unified 54 pt Glass Toolbar + ScrollPocket separation
Item {
    id: root
    height: 54
    property Item backdropItem: null
    property int currentViewIndex: 0 // 0: Icon, 1: List, 2: Column, 3: Gallery
    property bool inspectorOpen: false
    property bool canEject: FilesModel.currentPath.indexOf("/mnt/conj-") === 0 || FilesModel.currentPath.indexOf("/run/media") === 0

    signal viewModeChanged(int mode)
    signal newFolderRequested()
    signal getInfoRequested()
    signal ejectRequested()
    signal toggleInspectorRequested()

    GlassSurface {
        anchors.fill: parent
        variant: "regular"
        cornerRadius: 0
        shadowPreset: "none"
        scrollPocketMode: "soft"
        pocketAtTop: true
        backdropItem: root.backdropItem
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.toolbarPocketHairline
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 10

        // Back / Forward navigation
        RowLayout {
            spacing: 4
            Button {
                iconName: "go-previous"
                sizeClass: "compact"
                enabled: FilesModel.canGoBack
                onClicked: FilesModel.goBack()
                implicitWidth: 28; implicitHeight: 28
            }
            Button {
                iconName: "go-next"
                sizeClass: "compact"
                enabled: FilesModel.canGoForward
                onClicked: FilesModel.goForward()
                implicitWidth: 28; implicitHeight: 28
            }
        }

        // Current Folder Title + Inline Path Jump
        Text {
            Layout.fillWidth: true
            text: {
                var c = FilesModel.pathComponents;
                return (c && c.length > 0) ? c[c.length - 1].name : "Files";
            }
            color: Theme.labelColor
            font: Typography.headlineBold
            elide: Text.ElideRight
        }

        // View Mode Switcher: Icon (Cmd+1), List (Cmd+2), Column (Cmd+3), Gallery (Cmd+4)
        SegmentedControl {
            id: viewSwitcher
            currentIndex: root.currentViewIndex
            onCurrentIndexChanged: {
                if (root.currentViewIndex !== currentIndex) {
                    root.currentViewIndex = currentIndex;
                    root.viewModeChanged(currentIndex);
                }
            }
            Segment { text: "Icons" }
            Segment { text: "List" }
            Segment { text: "Columns" }
            Segment { text: "Gallery" }
        }

        ToolButton {
            visible: root.canEject
            iconName: "media-eject"
            tooltipText: "Eject (Cmd+E)"
            onClicked: root.ejectRequested()
            implicitWidth: 30; implicitHeight: 28
        }

        ToolButton {
            iconName: "folder-new"
            tooltipText: "New Folder"
            onClicked: root.newFolderRequested()
            implicitWidth: 30; implicitHeight: 28
        }

        ToolButton {
            iconName: "document-properties"
            tooltipText: "Get Info (Cmd+I)"
            onClicked: root.getInfoRequested()
            implicitWidth: 30; implicitHeight: 28
        }

        ToolButton {
            iconName: "view-preview"
            tooltipText: "Toggle Preview Inspector"
            onClicked: root.toggleInspectorRequested()
            implicitWidth: 30; implicitHeight: 28
        }

        SearchField {
            id: searchField
            placeholderText: "Search"
            Layout.preferredWidth: 160
            Layout.preferredHeight: 28
            text: FilesModel.searchFilter
            onTextChanged: FilesModel.searchFilter = text
        }
    }
}
