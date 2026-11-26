import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Conjunction.Design 1.0
import Conjunction.Controls 1.0

// SPEC §4.7 Conjunction Files Window: 216 pt Glass Sidebar, 54 pt ScrollPocket Toolbar,
// Icon / List / Column / Gallery Views (Cmd+1..4), Inspector (260 pt), Path Bar & Status Bar
Window {
    id: window
    width: (typeof initialWidth !== "undefined" && initialWidth > 0) ? initialWidth : 980
    height: (typeof initialHeight !== "undefined" && initialHeight > 0) ? initialHeight : 620
    minimumWidth: 720
    minimumHeight: 450
    visible: true
    LayoutMirroring.enabled: Appearance.isRTL
    LayoutMirroring.childrenInherit: true
    title: {
        var comp = FilesModel.pathComponents;
        if (comp && comp.length > 0) {
            return comp[comp.length - 1].name;
        }
        return "Files";
    }
    color: isDarkTheme ? "#1E1E1E" : "#ECECEC"

    property int viewMode: {
        if (initialViewMode === "list") return 1;
        if (initialViewMode === "column") return 2;
        if (initialViewMode === "gallery") return 3;
        return 0;
    }
    property bool showPathBar: true
    property bool showStatusBar: true
    property bool showInspector: viewMode === 3

    Component.onCompleted: {
        Appearance.setMode(isDarkTheme ? "dark" : "light");
        if (typeof initialRtl !== "undefined" && initialRtl) Appearance.setLayoutDirection(Qt.RightToLeft);
        if (typeof initialFontScale !== "undefined" && initialFontScale > 0) Appearance.setFontScale(initialFontScale);
        if (typeof initialStressMode !== "undefined" && initialStressMode) Appearance.setStressMode(true);
        if (cliQuickLookTarget && cliQuickLookTarget !== "") {
            quickLookOverlay.show(cliQuickLookTarget);
        } else if (cliGetInfoTarget && cliGetInfoTarget !== "") {
            getInfoDialog.show(cliGetInfoTarget);
        }
    }

    function setViewModeByName(name) {
        if (name === "icon") viewMode = 0;
        else if (name === "list") viewMode = 1;
        else if (name === "column") viewMode = 2;
        else if (name === "gallery") viewMode = 3;
    }

    function getActiveSelectedItem() {
        if (viewMode === 0) return iconView.selectedItem;
        if (viewMode === 1) return listView.selectedItem;
        if (viewMode === 2) return ColumnModel.hasPreview ? ColumnModel.previewData : null;
        if (viewMode === 3) return galleryView.selectedItem;
        return null;
    }

    function triggerQuickLook(item) {
        var it = item || getActiveSelectedItem();
        if (it && it.path) {
            quickLookOverlay.show(it.path);
        }
    }

    function triggerGetInfo(item) {
        var it = item || getActiveSelectedItem();
        if (it && it.path) {
            getInfoDialog.show(it.path);
        }
    }

    function openItem(item) {
        if (!item) return;
        if (item.isDir && !item.isAppBundle) {
            FilesModel.setPath(item.path);
            ColumnModel.resetToPath(item.path);
        } else {
            FileOps.openItem(item.path);
        }
    }

    function showPackageContents(item) {
        if (!item) return;
        var contentsPath = FileOps.openPackageContents(item.path);
        if (contentsPath && contentsPath !== "") {
            FilesModel.setPath(contentsPath);
            ColumnModel.resetToPath(contentsPath);
        }
    }

    function ejectCurrentOrSelected(mountPoint) {
        var tgt = mountPoint || FilesModel.currentPath;
        if (tgt && (tgt.indexOf("/mnt/conj-") === 0 || tgt.indexOf("/run/media") === 0 || tgt.indexOf("/media") === 0)) {
            if (FileOps.ejectVolume(tgt)) {
                SidebarModel.refresh();
                FilesModel.setPath("/");
            }
        }
    }

    Item {
        anchors.fill: parent
        focus: true

        Keys.onSpacePressed: (event) => {
            if (quickLookOverlay.visible) quickLookOverlay.hide();
            else window.triggerQuickLook();
            event.accepted = true;
        }

        Shortcut { sequences: ["Ctrl+1", "Cmd+1"]; onActivated: window.viewMode = 0 }
        Shortcut { sequences: ["Ctrl+2", "Cmd+2"]; onActivated: window.viewMode = 1 }
        Shortcut { sequences: ["Ctrl+3", "Cmd+3"]; onActivated: window.viewMode = 2 }
        Shortcut { sequences: ["Ctrl+4", "Cmd+4"]; onActivated: window.viewMode = 3 }
        Shortcut { sequences: ["Ctrl+I", "Cmd+I"]; onActivated: window.triggerGetInfo() }
        Shortcut { sequences: ["Ctrl+N", "Cmd+N"]; onActivated: FileOps.createFolder(FilesModel.currentPath, "untitled folder") }
        Shortcut { sequences: ["Ctrl+E", "Cmd+E"]; onActivated: window.ejectCurrentOrSelected("") }
        Shortcut { sequences: ["Ctrl+Alt+P", "Cmd+Alt+P"]; onActivated: window.showPathBar = !window.showPathBar }
        Shortcut { sequences: ["Ctrl+/", "Cmd+/"]; onActivated: window.showStatusBar = !window.showStatusBar }
        Shortcut { sequences: ["Alt+Left", "Ctrl+[", "Cmd+["]; onActivated: FilesModel.goBack() }
        Shortcut { sequences: ["Alt+Right", "Ctrl+]", "Cmd+]"]; onActivated: FilesModel.goForward() }
        Shortcut { sequences: ["Ctrl+Up", "Cmd+Up"]; onActivated: FilesModel.cdUp() }
        Shortcut {
            sequences: ["Ctrl+BackSpace", "Ctrl+Delete", "Cmd+Delete"]
            onActivated: {
                var it = window.getActiveSelectedItem();
                if (it && it.path) FileOps.moveToTrash([it.path]);
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Integrated Conjunction Toolbar (54 pt + ScrollPocket)
        FilesToolbar {
            id: toolbar
            Layout.fillWidth: true
            currentViewIndex: window.viewMode
            inspectorOpen: window.showInspector
            onViewModeChanged: (mode) => window.viewMode = mode
            onNewFolderRequested: FileOps.createFolder(FilesModel.currentPath, "untitled folder")
            onGetInfoRequested: window.triggerGetInfo()
            onEjectRequested: window.ejectCurrentOrSelected("")
            onToggleInspectorRequested: window.showInspector = !window.showInspector
        }

        QQC2.SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal

            // Left 216 pt Glass Navigation Sidebar
            FilesSidebar {
                id: sidebar
                QQC2.SplitView.preferredWidth: 216
                QQC2.SplitView.minimumWidth: 180
                QQC2.SplitView.maximumWidth: 280
                onLocationSelected: (path) => ColumnModel.resetToPath(path)
                onEjectRequested: (mp) => window.ejectCurrentOrSelected(mp)
            }

            // Primary Content View Area
            Rectangle {
                QQC2.SplitView.fillWidth: true
                Layout.fillHeight: true
                color: isDarkTheme ? "#1E1E1E" : "#FFFFFF"
                clip: true

                FilesIconView {
                    id: iconView
                    visible: window.viewMode === 0
                    anchors.fill: parent
                    onOpenRequested: (it) => window.openItem(it)
                    onGetInfoRequested: (it) => window.triggerGetInfo(it)
                    onQuickLookRequested: (it) => window.triggerQuickLook(it)
                    onShowPackageContentsRequested: (it) => window.showPackageContents(it)
                }

                FilesListView {
                    id: listView
                    visible: window.viewMode === 1
                    anchors.fill: parent
                    onOpenRequested: (it) => window.openItem(it)
                    onGetInfoRequested: (it) => window.triggerGetInfo(it)
                    onQuickLookRequested: (it) => window.triggerQuickLook(it)
                    onShowPackageContentsRequested: (it) => window.showPackageContents(it)
                }

                FilesColumnView {
                    id: columnView
                    visible: window.viewMode === 2
                    anchors.fill: parent
                    onOpenRequested: (it) => window.openItem(it)
                    onGetInfoRequested: (it) => window.triggerGetInfo(it)
                    onQuickLookRequested: (it) => window.triggerQuickLook(it)
                }

                FilesGalleryView {
                    id: galleryView
                    visible: window.viewMode === 3
                    anchors.fill: parent
                    onOpenRequested: (it) => window.openItem(it)
                    onGetInfoRequested: (it) => window.triggerGetInfo(it)
                    onQuickLookRequested: (it) => window.triggerQuickLook(it)
                }
            }

            // Optional 260 pt Right Preview Inspector Pane (SPEC §4.7)
            Rectangle {
                visible: window.showInspector
                QQC2.SplitView.preferredWidth: 260
                QQC2.SplitView.minimumWidth: 220
                QQC2.SplitView.maximumWidth: 320
                Layout.fillHeight: true
                color: isDarkTheme ? "#252527" : "#F5F5F7"

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Theme.separatorColor
                }

                readonly property var inspItem: window.getActiveSelectedItem()

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 112; height: 112; radius: 14
                        color: isDarkTheme ? Qt.rgba(1,1,1,0.06) : Qt.rgba(0,0,0,0.04)
                        Image {
                            anchors.centerIn: parent
                            width: 72; height: 72
                            source: parent.parent.parent.inspItem ? ("image://icon/" + parent.parent.parent.inspItem.iconName) : "image://icon/folder"
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: parent.parent.inspItem ? parent.parent.inspItem.name : title
                        color: Theme.labelColor
                        font: Typography.headlineBold
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: parent.parent.inspItem ? ((parent.parent.inspItem.mimeType || "") + " — " + (parent.parent.inspItem.sizeFormatted || "")) : (FilesModel.count + " items")
                        color: Theme.secondaryLabelColor
                        font: Typography.caption1
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.separatorColor }

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: parent.parent.inspItem ? ("Modified: " + (parent.parent.inspItem.modifiedFormatted || "--")) : ("Path: " + FilesModel.currentPath)
                        color: Theme.secondaryLabelColor
                        font: Typography.callout
                        wrapMode: Text.Wrap
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }

        // Toggleable Breadcrumb Path Bar (Cmd+Opt+P)
        Rectangle {
            visible: window.showPathBar
            Layout.fillWidth: true
            height: 24
            clip: true
            color: isDarkTheme ? "#222224" : "#F3F3F5"
            Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Theme.separatorColor }
            Flickable {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                contentWidth: pathRow.implicitWidth
                contentHeight: height
                clip: true

                Row {
                    id: pathRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Repeater {
                        model: FilesModel.pathComponents
                        delegate: Row {
                            spacing: 6
                            Text {
                                text: modelData.name
                                color: Theme.secondaryLabelColor
                                font: Typography.caption1
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: FilesModel.setPath(modelData.path) }
                            }
                            Text { visible: index < FilesModel.pathComponents.length - 1; text: "›"; color: Theme.tertiaryLabelColor; font: Typography.caption1 }
                        }
                    }
                }
            }
        }

        // Toggleable Bottom Status Bar (Cmd+/)
        Rectangle {
            visible: window.showStatusBar
            Layout.fillWidth: true
            height: 24
            color: isDarkTheme ? "#1E1E20" : "#ECECEC"
            Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Theme.separatorColor }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                Text { Layout.minimumWidth: 0; elide: Text.ElideRight; text: FilesModel.count + " items"; font: Typography.caption1; color: Theme.secondaryLabelColor }
                Item { Layout.fillWidth: true }
                Text { Layout.minimumWidth: 0; elide: Text.ElideRight; text: "Conjunction Volume"; font: Typography.caption1; color: Theme.secondaryLabelColor }
            }
        }
    }

    QuickLookOverlay { id: quickLookOverlay }
    GetInfoDialog { id: getInfoDialog }
    ConfirmDeleteDialog { id: confirmDeleteDialog; onConfirmed: FileOps.emptyTrash() }
}
