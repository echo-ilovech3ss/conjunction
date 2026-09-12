import QtQuick
import QtQuick.Layouts
import org.kde.kwin 3.0 as KWin

Item {
    id: effectRoot

    // Screen coverage
    anchors.fill: parent

    property int selectedIndex: 0
    property var windowList: []

    function updateWindows() {
        if (typeof workspace === "undefined") return;
        var all = workspace.windowList();
        var eligible = [];
        for (var i = 0; i < all.length; ++i) {
            var w = all[i];
            if (w.normalWindow && !w.skipSwitcher && !w.minimized) {
                eligible.push(w);
            }
        }
        windowList = eligible;
        if (selectedIndex >= windowList.length) {
            selectedIndex = Math.max(0, windowList.length - 1);
        }
    }

    Component.onCompleted: {
        updateWindows();
    }

    // Dismiss on Escape
    focus: true
    Keys.onEscapePressed: {
        if (typeof effects !== "undefined") {
            effects.toggleEffect("conjunction-overview");
        }
    }
    Keys.onLeftPressed: {
        if (selectedIndex > 0) selectedIndex--;
    }
    Keys.onRightPressed: {
        if (selectedIndex < windowList.length - 1) selectedIndex++;
    }
    Keys.onReturnPressed: {
        if (selectedIndex >= 0 && selectedIndex < windowList.length) {
            var targetWin = windowList[selectedIndex];
            if (typeof workspace !== "undefined") {
                workspace.activeWindow = targetWin;
            }
            if (typeof effects !== "undefined") {
                effects.toggleEffect("conjunction-overview");
            }
        }
    }

    // Frosted dark background
    Rectangle {
        anchors.fill: parent
        color: "#D9101216"

        TapHandler {
            onTapped: {
                if (typeof effects !== "undefined") {
                    effects.toggleEffect("conjunction-overview");
                }
            }
        }
    }

    // Window Cards Row
    Row {
        id: cardsRow
        anchors.centerIn: parent
        spacing: 24

        Repeater {
            model: effectRoot.windowList

            Rectangle {
                id: cardItem
                width: 320
                height: 220
                radius: 12
                color: "#1E2026"
                border.color: effectRoot.selectedIndex === index ? "#007AFF" : (thumbHover.hovered ? "#FFFFFF" : "#383A42")
                border.width: effectRoot.selectedIndex === index ? 3 : 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    // Top Bar with title
                    Text {
                        text: modelData.caption || modelData.title || "Window"
                        color: "#FFFFFF"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                    }

                    // KWin Native WindowThumbnail (Compositor-owned live render)
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        KWin.WindowThumbnail {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height * (modelData.width / Math.max(1, modelData.height)))
                            height: Math.min(parent.height, parent.width * (modelData.height / Math.max(1, modelData.width)))
                            wId: modelData.internalId
                        }
                    }
                }

                HoverHandler {
                    id: thumbHover
                    onHoveredChanged: {
                        if (hovered) effectRoot.selectedIndex = index;
                    }
                }

                TapHandler {
                    onTapped: {
                        if (typeof workspace !== "undefined") {
                            workspace.activeWindow = modelData;
                        }
                        if (typeof effects !== "undefined") {
                            effects.toggleEffect("conjunction-overview");
                        }
                    }
                }
            }
        }
    }
}
