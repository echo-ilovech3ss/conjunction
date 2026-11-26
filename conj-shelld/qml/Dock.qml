import QtQuick
import QtQuick.Layouts
import Conjunction.Design

// SPEC §4.2: Floating Clear Glass Dock with cosine-bell magnification (R = 3 * P0)
// and 680 ms launch bounce keyframes.
Item {
    id: root
    property Item backdropItem: null

    readonly property real baseTileSize: ShellState.dockTileSize // SPEC §4.2 nominal P0 = 54 pt (16-128)
    readonly property real maxScale: ShellState.dockMagnification ? ShellState.dockScaleMax : 1.0
    readonly property real capsuleHeight: baseTileSize + 20 // 74 pt at P0=54
    readonly property real centerSpacing: 60.0 * (baseTileSize / 54.0)
    readonly property real magRadius: 3.0 * baseTileSize // SPEC §4.2 cosine bell R = 3 * P0

    implicitHeight: Math.max(108.5, Math.round(baseTileSize * 2.02))
    height: implicitHeight
    width: Math.max(capsule.width + 80, 420)

    property bool pointerInside: dockMouse.containsMouse
    property real pointerLocalX: -9999
    property string hoveredTitle: ""
    property real hoveredCenterX: 0

    // Cosine bell magnification factor w(d) = 0.5*(1 + cos(pi * d / R))
    function computeMagScale(centerXInCapsule) {
        if (!ShellState.dockMagnification || !root.pointerInside) return 1.0;
        var ptrInCap = root.pointerLocalX - capsule.x;
        var dist = Math.abs(ptrInCap - centerXInCapsule);
        if (dist >= root.magRadius) return 1.0;
        var w = 0.5 * (1.0 + Math.cos(Math.PI * dist / root.magRadius));
        return 1.0 + (root.maxScale - 1.0) * w;
    }

    // Floating 26 pt Clear Glass tooltip 8 pt above magnified icon (SPEC §4.2)
    GlassSurface {
        id: tooltipPill
        visible: root.pointerInside && root.hoveredTitle !== ""
        x: Math.max(8, Math.min(root.width - width - 8, capsule.x + root.hoveredCenterX - width * 0.5))
        y: capsule.y - (root.baseTileSize * (root.maxScale - 1.0)) - height - 8
        width: tipText.implicitWidth + 24
        height: 26
        variant: "clear"
        cornerRadius: 13
        shadowPreset: "pill"
        backdropItem: root.backdropItem
        z: 20

        Text {
            id: tipText
            anchors.centerIn: parent
            text: root.hoveredTitle
            color: Theme.labelColor
            font: Typography.callout
        }
    }

    GlassSurface {
        id: capsule
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        width: dockRow.implicitWidth + 24
        height: root.capsuleHeight
        variant: "clear"
        cornerRadius: Math.min(height * 0.28, 24)
        shadowPreset: "popover"
        backdropItem: root.backdropItem
        z: 10
    }

    Row {
        id: dockRow
        anchors.verticalCenter: capsule.verticalCenter
        anchors.horizontalCenter: capsule.horizontalCenter
        spacing: Math.max(4, root.centerSpacing - root.baseTileSize)
        z: 15

        // App Launcher Special Icon (leading utility)
        Item {
            id: launcherSlot
            width: root.baseTileSize
            height: root.baseTileSize + 14
            readonly property real cx: x + width * 0.5
            readonly property real targetScale: root.computeMagScale(cx + 12)

            Item {
                width: root.baseTileSize
                height: root.baseTileSize
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                transformOrigin: Item.Bottom
                scale: launcherSlot.targetScale
                Behavior on scale {
                    NumberAnimation { duration: Appearance.reducedMotion ? 80 : 120; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.width * 0.24
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#5AC8FA" }
                        GradientStop { position: 1.0; color: "#007AFF" }
                    }
                    border.width: 0.75
                    border.color: Qt.rgba(1, 1, 1, 0.35)
                }
                Icon { anchors.centerIn: parent; name: "apps"; size: Math.round(root.baseTileSize * 0.54); color: "#FFFFFF" }
            }

            Rectangle {
                visible: ShellState.appLauncherVisible
                width: 4; height: 4; radius: 2
                color: Appearance.isDark ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(0, 0, 0, 0.70)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: { root.hoveredTitle = "App Launcher"; root.hoveredCenterX = launcherSlot.cx + 12; }
                onClicked: ShellState.toggleAppLauncher()
            }
        }

        // Pinned + Running Apps
        Repeater {
            model: ShellState.dockItems
            delegate: Item {
                id: appSlot
                width: root.baseTileSize
                height: root.baseTileSize + 14
                readonly property real cx: x + width * 0.5
                readonly property real targetScale: root.computeMagScale(cx + 12)
                property real bounceY: 0

                // SPEC §4.2 Launch Bounce: 680 ms keyframes 0 -> -22 -> 0 -> -10 -> 0 -> -3 -> 0 pt
                SequentialAnimation {
                    id: bounceAnim
                    running: false
                    NumberAnimation { target: appSlot; property: "bounceY"; to: -22; duration: 150; easing.type: Easing.OutQuad }
                    NumberAnimation { target: appSlot; property: "bounceY"; to: 0;   duration: 140; easing.type: Easing.InQuad }
                    NumberAnimation { target: appSlot; property: "bounceY"; to: -10; duration: 120; easing.type: Easing.OutQuad }
                    NumberAnimation { target: appSlot; property: "bounceY"; to: 0;   duration: 110; easing.type: Easing.InQuad }
                    NumberAnimation { target: appSlot; property: "bounceY"; to: -3;  duration: 80;  easing.type: Easing.OutQuad }
                    NumberAnimation { target: appSlot; property: "bounceY"; to: 0;   duration: 80;  easing.type: Easing.InQuad }
                }

                Item {
                    width: root.baseTileSize
                    height: root.baseTileSize
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8 - appSlot.bounceY
                    anchors.horizontalCenter: parent.horizontalCenter
                    transformOrigin: Item.Bottom
                    scale: appSlot.targetScale
                    Behavior on scale {
                        NumberAnimation { duration: Appearance.reducedMotion ? 80 : 120; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.width * 0.24
                        color: modelData.id === "org.conjunction.files" ? "#1E88E5"
                            : modelData.id === "org.conjunction.terminal" ? "#26282C"
                            : modelData.id === "org.conjunction.settings" ? "#6E737D"
                            : (modelData.active ? Theme.systemBlue : (Appearance.isDark ? "#3A3C42" : "#F2F4F8"))
                        border.width: 0.75
                        border.color: Appearance.isDark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.12)
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: modelData.icon || "applications"
                        size: Math.round(root.baseTileSize * 0.56)
                        color: (modelData.id === "org.conjunction.files" || modelData.id === "org.conjunction.terminal" || modelData.id === "org.conjunction.settings" || modelData.active)
                            ? "#FFFFFF" : Theme.labelColor
                    }
                }

                // Active / Running Dot (4 pt circle, SPEC §4.2)
                Rectangle {
                    visible: !!modelData.running
                    width: 4
                    height: 4
                    radius: 2
                    color: Appearance.isDark ? Qt.rgba(1, 1, 1, 0.90) : Qt.rgba(0, 0, 0, 0.72)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        root.hoveredTitle = modelData.name || modelData.id;
                        root.hoveredCenterX = appSlot.cx + 12;
                    }
                    onClicked: {
                        if (!modelData.running && !Appearance.reducedMotion) {
                            bounceAnim.restart();
                        }
                        ShellState.focusApp(modelData.id);
                    }
                }
            }
        }

        // Hairline Divider separating Minimized Windows, Mounted Volumes & Trash
        Item {
            width: 9
            height: root.baseTileSize
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.centerIn: parent
                width: 1
                height: root.baseTileSize * 0.72
                color: Theme.separatorColor
            }
        }

        // Minimized Windows Section
        Repeater {
            model: ShellState.minimizedWindows
            delegate: Item {
                id: minSlot
                width: root.baseTileSize
                height: root.baseTileSize + 14
                readonly property real cx: x + width * 0.5

                Item {
                    width: root.baseTileSize * 0.92
                    height: root.baseTileSize * 0.76
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    transformOrigin: Item.Bottom
                    scale: root.computeMagScale(minSlot.cx + 12)
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: Appearance.isDark ? "#2C2E33" : "#FAFAFC"
                        border.width: 1
                        border.color: Theme.separatorColor
                        Column {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 3
                            Rectangle { width: parent.width; height: 6; radius: 3; color: Theme.separatorColor }
                            Rectangle { width: parent.width * 0.75; height: 4; radius: 2; color: Theme.quaternaryLabelColor }
                            Icon { name: modelData.icon || "file"; size: 16; color: Theme.systemBlue; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        root.hoveredTitle = modelData.title || modelData.appName || "Minimized Window";
                        root.hoveredCenterX = minSlot.cx + 12;
                    }
                    onClicked: ShellState.unminimizeWindow(modelData.internalId)
                }
            }
        }

        // Mounted Disk Images / Volumes
        Repeater {
            model: ShellState.mountedVolumes
            delegate: Item {
                id: volSlot
                width: root.baseTileSize
                height: root.baseTileSize + 14
                readonly property real cx: x + width * 0.5

                Item {
                    width: root.baseTileSize
                    height: root.baseTileSize
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    transformOrigin: Item.Bottom
                    scale: root.computeMagScale(volSlot.cx + 12)

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.width * 0.24
                        color: Appearance.isDark ? "#383C45" : "#E5EAF2"
                        border.width: 0.75
                        border.color: Theme.separatorColor
                    }
                    Icon { anchors.centerIn: parent; name: "drive"; size: Math.round(root.baseTileSize * 0.54); color: Theme.labelColor }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        root.hoveredTitle = modelData.name || "Mounted Disk";
                        root.hoveredCenterX = volSlot.cx + 12;
                    }
                    onClicked: ShellState.openPath(modelData.mountPoint)
                }
            }
        }

        // Trash <-> Eject Morph Tile (SPEC §4.2: Trash icon morphs to Eject on drag)
        Item {
            id: trashSlot
            width: root.baseTileSize
            height: root.baseTileSize + 14
            readonly property real cx: x + width * 0.5
            readonly property bool showEject: ShellState.isDraggingDockItem

            Item {
                width: root.baseTileSize
                height: root.baseTileSize
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                transformOrigin: Item.Bottom
                scale: root.computeMagScale(trashSlot.cx + 12)
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.width * 0.24
                    color: trashSlot.showEject ? Theme.systemBlue : (Appearance.isDark ? "#34363C" : "#EAECEF")
                    border.width: 0.75
                    border.color: Appearance.isDark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.12)
                }

                Icon {
                    anchors.centerIn: parent
                    name: trashSlot.showEject ? "eject" : "trash"
                    preferPhosphor: trashSlot.showEject
                    size: Math.round(root.baseTileSize * 0.54)
                    color: trashSlot.showEject ? "#FFFFFF" : Theme.labelColor
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: {
                    root.hoveredTitle = trashSlot.showEject ? "Eject Volume" : "Trash";
                    root.hoveredCenterX = trashSlot.cx + 12;
                }
                onClicked: {
                    if (trashSlot.showEject && ShellState.draggingItemId !== "") {
                        ShellState.ejectVolume(ShellState.draggingItemId);
                        ShellState.setDraggingDockItem(false);
                    } else {
                        ShellState.openPath("trash:///");
                    }
                }
            }
        }
    }

    // Track pointer position across entire dock band for smooth magnification
    MouseArea {
        id: dockMouse
        anchors.fill: capsule
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: (mouse) => {
            root.pointerLocalX = capsule.x + mouse.x;
        }
        onExited: {
            root.pointerLocalX = -9999;
            root.hoveredTitle = "";
        }
    }
}
