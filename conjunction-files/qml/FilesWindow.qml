import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Conjunction.Design 1.0
import Conjunction.Controls 1.0

Window {
    id: window
    width: 980
    height: 620
    minimumWidth: 720
    minimumHeight: 450
    visible: true
    title: {
        var comp = FilesModel.pathComponents;
        if (comp && comp.length > 0) {
            return comp[comp.length - 1].name;
        }
        return "Files";
    }
    color: isDarkTheme ? "#1C1C1E" : "#FFFFFF"

    property int viewMode: {
        if (initialViewMode === "list") return 1;
        if (initialViewMode === "column") return 2;
        return 0; // icon
    }

    function getActiveSelectedItem() {
        if (viewMode === 0) return iconView.selectedItem;
        if (viewMode === 1) return listView.selectedItem;
        if (viewMode === 2) return ColumnModel.hasPreview ? ColumnModel.previewData : null;
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

    // Keyboard Navigation Shortcuts
    Item {
        anchors.fill: parent
        focus: true

        Keys.onSpacePressed: (event) => {
            if (quickLookOverlay.visible) {
                quickLookOverlay.hide();
            } else {
                window.triggerQuickLook();
            }
            event.accepted = true;
        }

        Shortcut {
            sequences: ["Ctrl+1", "Cmd+1"]
            onActivated: window.viewMode = 0
        }

        Shortcut {
            sequences: ["Ctrl+2", "Cmd+2"]
            onActivated: window.viewMode = 1
        }

        Shortcut {
            sequences: ["Ctrl+3", "Cmd+3"]
            onActivated: window.viewMode = 2
        }

        Shortcut {
            sequences: ["Ctrl+I", "Cmd+I"]
            onActivated: window.triggerGetInfo()
        }

        Shortcut {
            sequences: ["Ctrl+N", "Cmd+N"]
            onActivated: FileOps.createFolder(FilesModel.currentPath, "untitled folder")
        }

        Shortcut {
            sequences: ["Ctrl+BackSpace", "Ctrl+Delete", "Cmd+Delete"]
            onActivated: {
                var it = window.getActiveSelectedItem();
                if (it && it.path) {
                    FileOps.moveToTrash([it.path]);
                }
            }
        }

        Shortcut {
            sequences: ["Alt+Left", "Ctrl+[", "Cmd+["]
            onActivated: FilesModel.goBack()
        }

        Shortcut {
            sequences: ["Alt+Right", "Ctrl+]", "Cmd+]"]
            onActivated: FilesModel.goForward()
        }

        Shortcut {
            sequences: ["Ctrl+Up", "Cmd+Up"]
            onActivated: FilesModel.cdUp()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Integrated macOS Toolbar
        FilesToolbar {
            id: toolbar
            Layout.fillWidth: true
            currentViewIndex: window.viewMode
            onViewModeChanged: (mode) => window.viewMode = mode
            onNewFolderRequested: FileOps.createFolder(FilesModel.currentPath, "untitled folder")
            onGetInfoRequested: window.triggerGetInfo()
        }

        // Main Explorer Body (Sidebar + Content View)
        QQC2.SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal

            FilesSidebar {
                id: sidebar
                QQC2.SplitView.preferredWidth: 200
                QQC2.SplitView.minimumWidth: 160
                QQC2.SplitView.maximumWidth: 280
                onLocationSelected: (path) => {
                    ColumnModel.resetToPath(path);
                }
            }

            Rectangle {
                QQC2.SplitView.fillWidth: true
                Layout.fillHeight: true
                color: isDarkTheme ? "#1C1C1E" : "#FFFFFF"
                clip: true

                // View Mode 0: Icon View
                FilesIconView {
                    id: iconView
                    visible: window.viewMode === 0
                    anchors.fill: parent
                    onOpenRequested: (it) => window.openItem(it)
                    onGetInfoRequested: (it) => window.triggerGetInfo(it)
                    onQuickLookRequested: (it) => window.triggerQuickLook(it)
                    onShowPackageContentsRequested: (it) => window.showPackageContents(it)
                }

                // View Mode 1: List View
                FilesListView {
                    id: listView
                    visible: window.viewMode === 1
                    anchors.fill: parent
                    onOpenRequested: (it) => window.openItem(it)
                    onGetInfoRequested: (it) => window.triggerGetInfo(it)
                    onQuickLookRequested: (it) => window.triggerQuickLook(it)
                    onShowPackageContentsRequested: (it) => window.showPackageContents(it)
                }

                // View Mode 2: Column View
                FilesColumnView {
                    id: columnView
                    visible: window.viewMode === 2
                    anchors.fill: parent
                    onOpenRequested: (it) => window.openItem(it)
                    onGetInfoRequested: (it) => window.triggerGetInfo(it)
                    onQuickLookRequested: (it) => window.triggerQuickLook(it)
                }
            }
        }

        // Bottom Status Bar
        Rectangle {
            Layout.fillWidth: true
            height: 24
            color: isDarkTheme ? "#1E1E20" : "#EBEBF0"

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: isDarkTheme ? "#2A2A2D" : "#D2D2D7"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                Text {
                    text: FilesModel.count + " items"
                    font.pixelSize: 11
                    color: isDarkTheme ? "#8E8E93" : "#6E6E73"
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "Available: Local Volume"
                    font.pixelSize: 11
                    color: isDarkTheme ? "#8E8E93" : "#6E6E73"
                }
            }
        }
    }

    // Modal / Floating Overlays
    QuickLookOverlay {
        id: quickLookOverlay
    }

    GetInfoDialog {
        id: getInfoDialog
    }

    ConfirmDeleteDialog {
        id: confirmDeleteDialog
        onConfirmed: FileOps.emptyTrash()
    }

    Component.onCompleted: {
        if (cliQuickLookTarget && cliQuickLookTarget !== "") {
            quickLookOverlay.show(cliQuickLookTarget);
        } else if (cliGetInfoTarget && cliGetInfoTarget !== "") {
            getInfoDialog.show(cliGetInfoTarget);
        }
    }
}
