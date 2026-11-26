import QtQuick
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls as C

// SPEC §4.5 Quick Search: 680x54 capsule -> expands 680x430 (20 pt radius)
Item {
    id: root
    property Item backdropItem: null

    readonly property bool hasResults: filteredResults.length > 0
    property string activeFilter: "All"
    property int currentIndex: 0
    property bool previewExpanded: ShellState.quickLookVisible

    readonly property var filteredResults: {
        var all = ShellState.searchResults || [];
        if (activeFilter === "All") return all;
        var out = [];
        for (var i = 0; i < all.length; ++i) {
            var cat = (all[i].category || "");
            if (activeFilter === "Apps" && (cat === "Apps" || cat === "Applications")) out.push(all[i]);
            else if (activeFilter === "Files" && cat === "Files") out.push(all[i]);
            else if (activeFilter === "Settings" && cat.indexOf("Settings") >= 0) out.push(all[i]);
        }
        return out;
    }

    onFilteredResultsChanged: {
        if (currentIndex >= filteredResults.length) currentIndex = 0;
        if (filteredResults.length > 0) previewExpanded = true;
    }

    width: 680
    height: hasResults || ShellState.searchQuery !== "" ? 430 : 54
    Behavior on height { NumberAnimation { duration: Motion.duration(Motion.quickSearchOpen); easing.type: Easing.OutCubic } }

    GlassSurface {
        anchors.fill: parent
        variant: "clear"
        cornerRadius: 20
        shadowPreset: "window"
        backdropItem: root.backdropItem

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Top Input Bar (54 pt)
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 54

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 16
                    spacing: 12

                    Icon { name: "search"; size: 22; color: Theme.secondaryLabelColor }

                    TextInput {
                        id: queryInput
                        Layout.fillWidth: true
                        text: ShellState.searchQuery
                        color: Theme.labelColor
                        selectionColor: Theme.selectedContentBackgroundColor
                        font: Typography.makeSpecFont(20, Font.Normal, -0.002, false, false)
                        clip: true
                        focus: root.visible
                        onTextChanged: {
                            if (ShellState.searchQuery !== text) {
                                ShellState.searchQuery = text;
                                root.currentIndex = 0;
                            }
                        }

                        Text {
                            visible: queryInput.text === ""
                            text: "Quick Search"
                            color: Theme.tertiaryLabelColor
                            font: parent.font
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Keys.onUpPressed: root.currentIndex = Math.max(0, root.currentIndex - 1)
                        Keys.onDownPressed: root.currentIndex = Math.min(root.filteredResults.length - 1, root.currentIndex + 1)
                        Keys.onTabPressed: (ev) => {
                            ev.accepted = true;
                            root.previewExpanded = !root.previewExpanded;
                            if (root.previewExpanded) ShellState.openQuickLook(root.currentIndex);
                        }
                        Keys.onReturnPressed: {
                            if (root.filteredResults.length > 0) {
                                var origIdx = (ShellState.searchResults || []).indexOf(root.filteredResults[root.currentIndex]);
                                ShellState.activateSearchResult(origIdx >= 0 ? origIdx : root.currentIndex);
                            }
                        }
                        Keys.onEscapePressed: ShellState.spotlightVisible = false
                    }

                    // Quick category filter pills (64x30 condensed pills)
                    Row {
                        visible: root.height > 80
                        spacing: 4
                        Repeater {
                            model: ["All", "Apps", "Files", "Settings"]
                            delegate: Item {
                                width: 58; height: 28
                                Rectangle {
                                    anchors.fill: parent; radius: 14
                                    color: root.activeFilter === modelData ? Theme.systemBlue
                                        : (Appearance.isDark ? Qt.rgba(1,1,1,0.09) : Qt.rgba(0,0,0,0.06))
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: root.activeFilter === modelData ? "#FFFFFF" : Theme.labelColor
                                    font: Typography.caption2
                                }
                                MouseArea { anchors.fill: parent; onClicked: root.activeFilter = modelData }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: root.height > 80
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Theme.separatorColor
                }
            }

            // Expanded Two-Pane Body (Left Results + Right Quick Look Inspector)
            RowLayout {
                visible: root.height > 80
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                ListView {
                    id: resultsList
                    Layout.preferredWidth: root.previewExpanded ? 340 : root.width
                    Layout.fillHeight: true
                    clip: true
                    topMargin: 8
                    bottomMargin: 8
                    leftMargin: 10
                    rightMargin: 10
                    spacing: 2
                    model: root.filteredResults
                    currentIndex: root.currentIndex

                    delegate: Item {
                        width: resultsList.width - 20
                        height: 44

                        readonly property bool selected: index === root.currentIndex
                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: selected ? Theme.systemBlue : (rowHover.containsMouse ? Theme.controlFillHover : "transparent")
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            Rectangle {
                                width: 28; height: 28; radius: 7
                                color: selected ? Qt.rgba(1,1,1,0.22) : (Appearance.isDark ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.06))
                                Icon {
                                    anchors.centerIn: parent
                                    name: modelData.icon || "applications"
                                    size: 17
                                    color: selected ? "#FFFFFF" : Theme.systemBlue
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    text: modelData.title || ""
                                    color: selected ? "#FFFFFF" : Theme.labelColor
                                    font: Typography.headline
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: modelData.subtitle || ""
                                    color: selected ? Qt.rgba(1,1,1,0.80) : Theme.secondaryLabelColor
                                    font: Typography.caption1
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.currentIndex = index
                            onClicked: {
                                root.currentIndex = index;
                                var origIdx = (ShellState.searchResults || []).indexOf(modelData);
                                ShellState.activateSearchResult(origIdx >= 0 ? origIdx : index);
                            }
                        }
                    }
                }

                Rectangle {
                    visible: root.previewExpanded && root.filteredResults.length > 0
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    color: Theme.separatorColor
                }

                // Quick Look / Preview Pane (SPEC §4.5)
                Item {
                    visible: root.previewExpanded && root.filteredResults.length > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    readonly property var cur: root.filteredResults.length > 0 && root.currentIndex < root.filteredResults.length
                        ? root.filteredResults[root.currentIndex] : null

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 10
                        visible: parent.cur !== null

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 72; height: 72; radius: 18
                            color: Appearance.isDark ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.06)
                            Icon {
                                anchors.centerIn: parent
                                name: parent.parent.parent.cur ? (parent.parent.parent.cur.icon || "applications") : "applications"
                                size: 38
                                color: Theme.systemBlue
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: parent.parent.cur ? (parent.parent.cur.title || "") : ""
                            color: Theme.labelColor
                            font: Typography.title2Bold
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: parent.parent.cur ? (parent.parent.cur.subtitle || "") : ""
                            color: Theme.secondaryLabelColor
                            font: Typography.callout
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Theme.separatorColor
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: parent.parent.cur ? (parent.parent.cur.previewDetail || parent.parent.cur.subtitle || "") : ""
                            color: Theme.secondaryLabelColor
                            font: Typography.callout
                            wrapMode: Text.WordWrap
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Item { Layout.fillWidth: true }
                            C.Button {
                                text: "Open"
                                isDefault: true
                                sizeClass: "regular"
                                onClicked: {
                                    var origIdx = (ShellState.searchResults || []).indexOf(root.filteredResults[root.currentIndex]);
                                    ShellState.activateSearchResult(origIdx >= 0 ? origIdx : root.currentIndex);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
