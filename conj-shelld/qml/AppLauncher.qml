import QtQuick
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls as C

// SPEC §4.5 App Launcher: 844x584 Clear Glass modal with 26 pt continuous corners
Item {
    id: root
    property Item backdropItem: null

    width: 844
    height: 584

    property string searchFilter: ""
    property string categoryFilter: "All"

    readonly property var filteredApps: {
        var list = ShellState.appCatalog || [];
        var q = searchFilter.trim().toLowerCase();
        var cat = categoryFilter;
        var out = [];
        for (var i = 0; i < list.length; ++i) {
            var a = list[i];
            var catOk = (cat === "All") || (a.category === cat);
            var qOk = (q === "") || (a.name || "").toLowerCase().indexOf(q) >= 0 || (a.id || "").toLowerCase().indexOf(q) >= 0;
            if (catOk && qOk) out.push(a);
        }
        return out;
    }

    GlassSurface {
        anchors.fill: parent
        variant: "clear"
        cornerRadius: 26
        shadowPreset: "window"
        backdropItem: root.backdropItem

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 18

            // Top Search + Category Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "Applications"
                    color: Theme.labelColor
                    font: Typography.title2Bold
                }

                Item { Layout.fillWidth: true }

                Row {
                    spacing: 6
                    Repeater {
                        model: ["All", "Utilities", "Internet", "Development", "System"]
                        delegate: Item {
                            width: catTxt.implicitWidth + 22
                            height: 28
                            Rectangle {
                                anchors.fill: parent; radius: 14
                                color: root.categoryFilter === modelData ? Theme.systemBlue
                                    : (Appearance.isDark ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.06))
                            }
                            Text {
                                id: catTxt
                                anchors.centerIn: parent
                                text: modelData
                                color: root.categoryFilter === modelData ? "#FFFFFF" : Theme.labelColor
                                font: Typography.callout
                            }
                            MouseArea { anchors.fill: parent; onClicked: root.categoryFilter = modelData }
                        }
                    }
                }

                C.SearchField {
                    Layout.preferredWidth: 210
                    placeholderText: "Search apps"
                    text: root.searchFilter
                    onTextChanged: root.searchFilter = text
                }
            }

            // Responsive App Grid (6 columns)
            GridView {
                id: appGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                cellWidth: Math.floor(width / 6)
                cellHeight: 112
                clip: true
                model: root.filteredApps

                delegate: Item {
                    width: appGrid.cellWidth
                    height: appGrid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 6
                        radius: 16
                        color: tileHover.containsMouse
                            ? (Appearance.isDark ? Qt.rgba(1,1,1,0.12) : Qt.rgba(0,0,0,0.06))
                            : "transparent"
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 60; height: 60; radius: 15
                            color: modelData.id === "org.conjunction.files" ? "#1E88E5"
                                : modelData.id === "org.conjunction.terminal" ? "#26282C"
                                : modelData.id === "org.conjunction.settings" ? "#6E737D"
                                : Theme.systemBlue
                            border.width: 0.75
                            border.color: Qt.rgba(1, 1, 1, 0.25)

                            Icon {
                                anchors.centerIn: parent
                                name: modelData.icon || "applications"
                                size: 32
                                color: "#FFFFFF"
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.maximumWidth: appGrid.cellWidth - 16
                            text: modelData.name || modelData.id
                            color: Theme.labelColor
                            font: Typography.subheadline
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    MouseArea {
                        id: tileHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            ShellState.appLauncherVisible = false;
                            if (modelData.isBundle && modelData.bundlePath) {
                                ShellState.launchBundle(modelData.bundlePath);
                            } else {
                                ShellState.focusApp(modelData.id);
                            }
                        }
                    }
                }
            }
        }
    }
}
