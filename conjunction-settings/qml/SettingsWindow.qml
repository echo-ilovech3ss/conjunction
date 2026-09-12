import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls as Controls
import "pages" as Pages

ApplicationWindow {
    id: window
    width: 920
    height: 640
    minimumWidth: 760
    minimumHeight: 520
    visible: true
    title: "System Settings"
    color: Theme.backgroundPrimary

    // Global keyboard handling
    Item {
        focus: true
        Keys.onEscapePressed: {
            if (SettingsManager.searchQuery.length > 0) {
                SettingsManager.searchQuery = ""
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Persistent Left Sidebar
        SettingsSidebar {
            id: sidebar
            Layout.preferredWidth: 230
            Layout.minimumWidth: 200
            Layout.maximumWidth: 280
            Layout.fillHeight: true
        }

        // Vertical Separator
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Theme.separator
        }

        // Detail Pane
        Rectangle {
            id: detailPane
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.backgroundPrimary

            Loader {
                id: pageLoader
                anchors.fill: parent

                sourceComponent: {
                    if (SettingsManager.searchQuery.length > 0) {
                        return searchComponent;
                    }
                    switch (SettingsManager.activePage) {
                    case "about": return aboutComponent;
                    case "appearance": return appearanceComponent;
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
            Component { id: dockComponent; Pages.DesktopDockPage {} }
            Component { id: displaysComponent; Pages.DisplaysPage {} }
            Component { id: soundComponent; Pages.SoundPage {} }
            Component { id: networkComponent; Pages.NetworkPage {} }
            Component { id: bluetoothComponent; Pages.BluetoothPage {} }
        }
    }
}
