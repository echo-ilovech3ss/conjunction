import QtQuick
import QtQuick.Layouts
import org.kde.kwin 3.0 as KWin

Item {
    id: effectRoot
    anchors.fill: parent

    property int selectedIndex: 0
    property var windowList: []
    property bool entered: false

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
        entered = true;
    }

    function dismiss() {
        entered = false;
        if (typeof effects !== "undefined") {
            effects.toggleEffect("conjunction-overview");
        }
    }

    focus: true
    Keys.onEscapePressed: dismiss()
    Keys.onLeftPressed: if (selectedIndex > 0) selectedIndex--
    Keys.onRightPressed: if (selectedIndex < windowList.length - 1) selectedIndex++
    Keys.onReturnPressed: {
        if (selectedIndex >= 0 && selectedIndex < windowList.length) {
            if (typeof workspace !== "undefined") workspace.activeWindow = windowList[selectedIndex];
            dismiss();
        }
    }

    // SPEC §3.1: Desktop dims ~0.25 + blur in 525 ms
    Rectangle {
        anchors.fill: parent
        color: "#440B0E14"
        opacity: effectRoot.entered ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 525; easing.type: Easing.OutCubic } }
        TapHandler { onTapped: effectRoot.dismiss() }
    }

    // SPEC §3.1 & §4: Top Spaces Bar (~135 pt tall sliding smoothly down from Menu Bar)
    Rectangle {
        id: spacesBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 135
        color: "#8C1A1D24"
        y: effectRoot.entered ? 0 : -135
        Behavior on y { NumberAnimation { duration: 525; easing.type: Easing.OutCubic } }

        Row {
            anchors.centerIn: parent
            spacing: 24

            Repeater {
                model: (typeof workspace !== "undefined" && workspace.desktops) ? workspace.desktops : []
                Rectangle {
                    width: 148
                    height: 86
                    radius: 12
                    property bool isCur: (typeof workspace !== "undefined" && workspace.currentDesktop === modelData)
                    color: "#2E3440"
                    border.color: isCur ? "#FFFFFF" : "#44FFFFFF"
                    border.width: isCur ? 2 : 1

                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: -22
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.name || ("Desktop " + (index + 1))
                        color: "#FFFFFF"
                        font.pixelSize: 12
                    }

                    TapHandler {
                        onTapped: if (typeof workspace !== "undefined") workspace.currentDesktop = modelData
                    }
                }
            }

            Rectangle {
                width: 48; height: 86; radius: 12
                color: "#22FFFFFF"; border.color: "#44FFFFFF"; border.width: 1
                Text { anchors.centerIn: parent; text: "+"; color: "#FFFFFF"; font.pixelSize: 22 }
            }
        }
    }

    // Decluttered non-overlapping Window Grid (525 ms enter / 492 ms exit)
    Grid {
        id: cardsGrid
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 56
        columns: Math.max(1, Math.min(4, Math.ceil(Math.sqrt(effectRoot.windowList.length))))
        spacing: 24
        scale: effectRoot.entered ? 1.0 : 0.90
        Behavior on scale { NumberAnimation { duration: 525; easing.type: Easing.OutCubic } }

        Repeater {
            model: effectRoot.windowList

            Rectangle {
                id: cardItem
                readonly property int cols: cardsGrid.columns
                width: Math.min(360, (effectRoot.width - 96 - (cols - 1) * 24) / cols)
                height: Math.round(width * 0.66)
                radius: 16
                color: "#20232B"
                border.color: (effectRoot.selectedIndex === index || thumbHover.hovered) ? "#007AFF" : "#33FFFFFF"
                border.width: (effectRoot.selectedIndex === index || thumbHover.hovered) ? 2.5 : 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

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

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: Math.min(parent.width - 16, cardLabel.implicitWidth + 20)
                        height: 24
                        radius: 12
                        color: thumbHover.hovered ? "#007AFF" : "#80000000"

                        Text {
                            id: cardLabel
                            anchors.centerIn: parent
                            text: modelData.caption || modelData.title || "Window"
                            color: "#FFFFFF"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                    }
                }

                HoverHandler {
                    id: thumbHover
                    onHoveredChanged: if (hovered) effectRoot.selectedIndex = index
                }
                TapHandler {
                    onTapped: {
                        if (typeof workspace !== "undefined") workspace.activeWindow = modelData;
                        effectRoot.dismiss();
                    }
                }
            }
        }
    }
}
