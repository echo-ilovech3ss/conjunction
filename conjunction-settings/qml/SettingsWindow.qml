import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls as Controls
import "pages" as Pages

// SPEC §4.8 System Settings: 740x625 default, 232 pt Glass Sidebar, 52 pt Back/Forward header
ApplicationWindow {
    id: window
    width: (typeof initialWidth !== "undefined" && initialWidth > 0) ? initialWidth : 740
    height: (typeof initialHeight !== "undefined" && initialHeight > 0) ? initialHeight : 625
    minimumWidth: 640
    minimumHeight: 480
    visible: true
    title: "System Settings"
    color: Theme.windowBackgroundColor
    LayoutMirroring.enabled: Appearance.isRTL
    LayoutMirroring.childrenInherit: true

    function syncAppearanceTokens() {
        Appearance.setMode(SettingsManager.appearanceMode === "dark" ? "dark" : "light");
        Appearance.setAccent(SettingsManager.appearanceAccent);
        Appearance.setReducedMotion(SettingsManager.reducedMotion);
        Appearance.setReduceTransparency(SettingsManager.reduceTransparency);
        Appearance.setIncreaseContrast(SettingsManager.increaseContrast);
        if (typeof initialRtl !== "undefined" && initialRtl) Appearance.setLayoutDirection(Qt.RightToLeft);
        if (typeof initialFontScale !== "undefined" && initialFontScale > 0) Appearance.setFontScale(initialFontScale);
        if (typeof initialStressMode !== "undefined" && initialStressMode) Appearance.setStressMode(true);
    }

    Component.onCompleted: syncAppearanceTokens()

    Connections {
        target: SettingsManager
        function onAppearanceModeChanged() { window.syncAppearanceTokens(); }
        function onAppearanceAccentChanged() { window.syncAppearanceTokens(); }
        function onReducedMotionChanged() { window.syncAppearanceTokens(); }
        function onReduceTransparencyChanged() { window.syncAppearanceTokens(); }
        function onIncreaseContrastChanged() { window.syncAppearanceTokens(); }
    }

    Item {
        focus: true
        Keys.onEscapePressed: {
            if (SettingsManager.searchQuery.length > 0) {
                SettingsManager.searchQuery = "";
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Persistent 232 pt Glass Sidebar (SPEC §4.8)
        SettingsSidebar {
            id: sidebar
            Layout.preferredWidth: 232
            Layout.minimumWidth: 210
            Layout.maximumWidth: 260
            Layout.fillHeight: true
        }

        // Hairline Vertical Divider
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Theme.separatorColor
        }

        // Right Column: 52 pt Back/Forward Header + Content Area
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // SPEC §4.8 52 pt Header with Back / Forward Chevrons + Section Title
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                color: Theme.windowBackgroundColor

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10

                    RowLayout {
                        spacing: 4
                        Controls.ToolButton {
                            implicitWidth: 28; implicitHeight: 28
                            iconName: "chevron-left"
                            enabled: SettingsManager.canGoBack
                            onClicked: SettingsManager.goBack()
                        }
                        Controls.ToolButton {
                            implicitWidth: 28; implicitHeight: 28
                            iconName: "chevron-right"
                            enabled: SettingsManager.canGoForward
                            onClicked: SettingsManager.goForward()
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        elide: Text.ElideRight
                        text: {
                            if (SettingsManager.searchQuery.length > 0) return "Search Results";
                            var ps = SettingsManager.pages;
                            for (var i = 0; i < ps.length; ++i) {
                                if (ps[i].id === SettingsManager.activePage) return ps[i].title;
                            }
                            return "Settings";
                        }
                        font: Typography.title3SemiBold
                        color: Theme.labelColor
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Theme.toolbarPocketHairline
                }
            }

            Rectangle {
                id: detailPane
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.windowBackgroundColor

                Loader {
                    id: pageLoader
                    anchors.fill: parent
                    sourceComponent: {
                        if (SettingsManager.searchQuery.length > 0) return searchComponent;
                        switch (SettingsManager.activePage) {
                        case "about": return aboutComponent;
                        case "appearance": return appearanceComponent;
                        case "default-apps": return defaultAppsComponent;
                        case "shortcuts": return shortcutsComponent;
                        case "dock": return dockComponent;
                        case "displays": return displaysComponent;
                        case "sound": return soundComponent;
                        case "network": return networkComponent;
                        case "bluetooth": return bluetoothComponent;
                        default: return aboutComponent;
                        }
                    }
                }

                Component { id: searchComponent; Pages.SearchResultsPage {} }
                Component { id: aboutComponent; Pages.GeneralAboutPage {} }
                Component { id: appearanceComponent; Pages.AppearancePage {} }
                Component { id: defaultAppsComponent; Pages.DefaultAppsPage {} }
                Component { id: shortcutsComponent; Pages.ShortcutsPage {} }
                Component { id: dockComponent; Pages.DesktopDockPage {} }
                Component { id: displaysComponent; Pages.DisplaysPage {} }
                Component { id: soundComponent; Pages.SoundPage {} }
                Component { id: networkComponent; Pages.NetworkPage {} }
                Component { id: bluetoothComponent; Pages.BluetoothPage {} }
            }
        }
    }
}
