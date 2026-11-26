import QtQuick
import QtQuick.Layouts
import Conjunction.Design

// SPEC §4.3 Control Center: independent floating Clear Glass capsules on U=64 / gutter=12 pt grid.
// Clean-room implementation with "Nearby Share" (no proprietary terms).
Item {
    id: root
    property Item backdropItem: null

    width: Math.min(304, parent ? parent.width - 16 : 304) // 292 content + 12 margins
    height: Math.min(ccColumn.implicitHeight + 8, parent ? parent.height - 124 : ccColumn.implicitHeight + 8)
    clip: true

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: ccColumn.implicitHeight
        clip: true

        Column {
            id: ccColumn
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(292, parent.width - 8)
            spacing: 12 // SPEC §4.3 uniform 12 pt gutter

        // ---- Rows 1..3: Left 3x (2x1 = 140x64) + Right (2x2 Media 140x140 + 2x 1x1 64x64) ----
        Row {
            width: 292
            spacing: 12

            // Left Column: Wi-Fi, Bluetooth, Nearby Share
            Column {
                width: 140
                spacing: 12

                // Wi-Fi 2x1 (140x64)
                GlassSurface {
                    width: 140; height: 64
                    variant: "clear"
                    cornerRadius: 26
                    shadowPreset: "popover"
                    backdropItem: root.backdropItem

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10
                        Rectangle {
                            width: 38; height: 38; radius: 19
                            color: ShellState.wifiEnabled ? Theme.systemBlue : (Appearance.isDark ? Qt.rgba(1,1,1,0.12) : Qt.rgba(0,0,0,0.08))
                            Icon { anchors.centerIn: parent; name: ShellState.wifiEnabled ? "wifi" : "wifi-off"; size: 19; color: ShellState.wifiEnabled ? "#FFFFFF" : Theme.labelColor }
                        }
                        Column {
                            Layout.fillWidth: true
                            Text { text: "Wi-Fi"; color: Theme.labelColor; font: Typography.headline; elide: Text.ElideRight; width: 68 }
                            Text { text: ShellState.wifiEnabled ? ShellState.wifiSsid : "Off"; color: Theme.secondaryLabelColor; font: Typography.subheadline; elide: Text.ElideRight; width: 68 }
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: ShellState.toggleWifi() }
                }

                // Bluetooth 2x1 (140x64)
                GlassSurface {
                    width: 140; height: 64
                    variant: "clear"
                    cornerRadius: 26
                    shadowPreset: "popover"
                    backdropItem: root.backdropItem

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10
                        Rectangle {
                            width: 38; height: 38; radius: 19
                            color: ShellState.bluetoothEnabled ? Theme.systemBlue : (Appearance.isDark ? Qt.rgba(1,1,1,0.12) : Qt.rgba(0,0,0,0.08))
                            Icon { anchors.centerIn: parent; name: ShellState.bluetoothEnabled ? "bluetooth" : "bluetooth-disabled"; size: 19; color: ShellState.bluetoothEnabled ? "#FFFFFF" : Theme.labelColor }
                        }
                        Column {
                            Layout.fillWidth: true
                            Text { text: "Bluetooth"; color: Theme.labelColor; font: Typography.headline; elide: Text.ElideRight; width: 68 }
                            Text { text: ShellState.bluetoothEnabled ? "On" : "Off"; color: Theme.secondaryLabelColor; font: Typography.subheadline; elide: Text.ElideRight; width: 68 }
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: ShellState.toggleBluetooth() }
                }

                // Nearby Share 2x1 (140x64)
                GlassSurface {
                    width: 140; height: 64
                    variant: "clear"
                    cornerRadius: 26
                    shadowPreset: "popover"
                    backdropItem: root.backdropItem

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10
                        Rectangle {
                            width: 38; height: 38; radius: 19
                            color: ShellState.nearbyShareEnabled ? Theme.systemBlue : (Appearance.isDark ? Qt.rgba(1,1,1,0.12) : Qt.rgba(0,0,0,0.08))
                            Icon { anchors.centerIn: parent; name: "nearby"; size: 19; color: ShellState.nearbyShareEnabled ? "#FFFFFF" : Theme.labelColor }
                        }
                        Column {
                            Layout.fillWidth: true
                            Text { text: "Nearby"; color: Theme.labelColor; font: Typography.headline; elide: Text.ElideRight; width: 68 }
                            Text { text: ShellState.nearbyShareEnabled ? "Everyone" : "Off"; color: Theme.secondaryLabelColor; font: Typography.subheadline; elide: Text.ElideRight; width: 68 }
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: ShellState.toggleNearbyShare() }
                }
            }

            // Right Column: 2x2 Media Player + Row of 2x 1x1 Quick Tiles
            Column {
                width: 140
                spacing: 12

                // 2x2 Media Transport (140x140, cr=26)
                GlassSurface {
                    width: 140; height: 140
                    variant: "clear"
                    cornerRadius: 26
                    shadowPreset: "popover"
                    backdropItem: root.backdropItem

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8
                        Rectangle {
                            width: 40; height: 40; radius: 10
                            color: Appearance.isDark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.08)
                            Icon { anchors.centerIn: parent; name: "sound"; size: 20; color: Theme.secondaryLabelColor }
                        }
                        Text {
                            text: "Not Playing"
                            color: Theme.labelColor
                            font: Typography.headline
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            elide: Text.ElideRight
                        }
                        Item { Layout.fillHeight: true }
                        RowLayout {
                            Layout.fillWidth: true
                            Icon { name: "prev"; size: 22; color: Theme.secondaryLabelColor }
                            Item { Layout.fillWidth: true }
                            Icon { name: "play"; size: 26; color: Theme.labelColor }
                            Item { Layout.fillWidth: true }
                            Icon { name: "next"; size: 22; color: Theme.secondaryLabelColor }
                        }
                    }
                }

                // 2x 1x1 Tiles (64x64 circular)
                Row {
                    width: 140
                    spacing: 12

                    GlassSurface {
                        width: 64; height: 64
                        variant: "clear"
                        cornerRadius: 32
                        shadowPreset: "popover"
                        backdropItem: root.backdropItem
                        tintColor: ShellState.stageManagerEnabled ? Qt.rgba(0, 0.533, 1.0, 0.45) : Qt.rgba(0, 0, 0, 0)
                        Icon { anchors.centerIn: parent; name: "stage"; size: 24; color: Theme.labelColor }
                        MouseArea { anchors.fill: parent; onClicked: ShellState.toggleStageManager() }
                    }

                    GlassSurface {
                        width: 64; height: 64
                        variant: "clear"
                        cornerRadius: 32
                        shadowPreset: "popover"
                        backdropItem: root.backdropItem
                        Icon { anchors.centerIn: parent; name: "mirror"; size: 24; color: Theme.labelColor }
                        MouseArea { anchors.fill: parent; onClicked: ShellState.toggleOverview() }
                    }
                }
            }
        }

        // ---- Row 4: Dark Mode (1x1 White Circle when dark!) + Night Shift (1x1) + Focus (2x1 140x64) ----
        Row {
            width: 292
            spacing: 12

            // Dark Mode 1x1 (64x64 circle; bright solid white highlight matching Dark Mode active state)
            Item {
                width: 64; height: 64
                GlassSurface {
                    anchors.fill: parent
                    visible: !ShellState.isDark
                    variant: "clear"
                    cornerRadius: 32
                    shadowPreset: "popover"
                    backdropItem: root.backdropItem
                }
                Rectangle {
                    anchors.fill: parent
                    visible: ShellState.isDark
                    radius: 32
                    color: "#FFFFFF"
                }
                Icon {
                    anchors.centerIn: parent
                    name: ShellState.isDark ? "sun" : "moon"
                    size: 24
                    color: ShellState.isDark ? "#111111" : Theme.labelColor
                }
                MouseArea { anchors.fill: parent; onClicked: ShellState.toggleTheme() }
            }

            // Night Shift / Reduced Transparency Quick 1x1 (64x64)
            GlassSurface {
                width: 64; height: 64
                variant: "clear"
                cornerRadius: 32
                shadowPreset: "popover"
                backdropItem: root.backdropItem
                tintColor: ShellState.nightShiftEnabled ? Qt.rgba(1.0, 0.55, 0.16, 0.45) : Qt.rgba(0, 0, 0, 0)
                Icon { anchors.centerIn: parent; name: "brightness"; size: 24; color: Theme.labelColor }
                MouseArea { anchors.fill: parent; onClicked: ShellState.toggleNightShift() }
            }

            // Focus / Do Not Disturb 2x1 (140x64)
            GlassSurface {
                width: 140; height: 64
                variant: "clear"
                cornerRadius: 26
                shadowPreset: "popover"
                backdropItem: root.backdropItem
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10
                    Rectangle {
                        width: 38; height: 38; radius: 19
                        color: ShellState.doNotDisturb ? Theme.systemIndigo : (Appearance.isDark ? Qt.rgba(1,1,1,0.14) : Qt.rgba(0,0,0,0.08))
                        Icon { anchors.centerIn: parent; name: "moon"; size: 19; color: ShellState.doNotDisturb ? "#FFFFFF" : Theme.labelColor }
                    }
                    Text {
                        text: ShellState.doNotDisturb ? "DND On" : "Focus"
                        color: Theme.labelColor
                        font: Typography.headline
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        elide: Text.ElideRight
                    }
                }
                MouseArea { anchors.fill: parent; onClicked: ShellState.toggleDoNotDisturb() }
            }
        }

        // ---- Row 5: Display Brightness 4x1 (292x64, 6pt white track + 20x20 thumb) ----
        GlassSurface {
            width: 292; height: 64
            variant: "clear"
            cornerRadius: 26
            shadowPreset: "popover"
            backdropItem: root.backdropItem

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                spacing: 4
                Text { text: "Display"; color: Theme.labelColor; font: Typography.headline }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Icon { name: "brightness"; size: 15; color: Theme.secondaryLabelColor }
                    Item {
                        id: dispTrack
                        Layout.fillWidth: true
                        height: 20
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width; height: 6; radius: 3
                            color: Appearance.isDark ? Qt.rgba(1,1,1,0.20) : Qt.rgba(0,0,0,0.14)
                            Rectangle {
                                width: Math.max(6, (ShellState.brightness / 100.0) * parent.width)
                                height: parent.height; radius: 3
                                color: "#FFFFFF"
                            }
                        }
                        Rectangle {
                            width: 20; height: 20; radius: 10
                            color: "#FFFFFF"
                            border.width: 0.75; border.color: Qt.rgba(0,0,0,0.18)
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width, (ShellState.brightness / 100.0) * (parent.width - width)))
                        }
                        MouseArea {
                            anchors.fill: parent
                            onPressed: (m) => ShellState.brightness = Math.round(Math.max(0, Math.min(1, m.x / width)) * 100)
                            onPositionChanged: (m) => { if (pressed) ShellState.brightness = Math.round(Math.max(0, Math.min(1, m.x / width)) * 100) }
                        }
                    }
                    Icon { name: "sun"; size: 17; color: Theme.labelColor }
                }
            }
        }

        // ---- Row 6: Sound Volume 4x1 (292x64, 6pt white track + 20x20 thumb + trailing 36pt output btn) ----
        GlassSurface {
            width: 292; height: 64
            variant: "clear"
            cornerRadius: 26
            shadowPreset: "popover"
            backdropItem: root.backdropItem

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                spacing: 10
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text { Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight; text: "Sound"; color: Theme.labelColor; font: Typography.headline }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Icon { name: ShellState.volume === 0 ? "volume-mute" : "volume"; size: 15; color: Theme.secondaryLabelColor }
                        Item {
                            Layout.fillWidth: true
                            height: 20
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 6; radius: 3
                                color: Appearance.isDark ? Qt.rgba(1,1,1,0.20) : Qt.rgba(0,0,0,0.14)
                                Rectangle {
                                    width: Math.max(6, (ShellState.volume / 100.0) * parent.width)
                                    height: parent.height; radius: 3
                                    color: "#FFFFFF"
                                }
                            }
                            Rectangle {
                                width: 20; height: 20; radius: 10
                                color: "#FFFFFF"
                                border.width: 0.75; border.color: Qt.rgba(0,0,0,0.18)
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.max(0, Math.min(parent.width - width, (ShellState.volume / 100.0) * (parent.width - width)))
                            }
                            MouseArea {
                                anchors.fill: parent
                                onPressed: (m) => ShellState.volume = Math.round(Math.max(0, Math.min(1, m.x / width)) * 100)
                                onPositionChanged: (m) => { if (pressed) ShellState.volume = Math.round(Math.max(0, Math.min(1, m.x / width)) * 100) }
                            }
                        }
                        Icon { name: "volume"; size: 17; color: Theme.labelColor }
                    }
                }
                GlassSurface {
                    Layout.preferredWidth: 36; Layout.preferredHeight: 36
                    variant: "clear"
                    cornerRadius: 18
                    shadowPreset: "none"
                    backdropItem: root.backdropItem
                    Icon { anchors.centerIn: parent; name: "sound"; size: 18; color: Theme.labelColor }
                    MouseArea { anchors.fill: parent; onClicked: ShellState.OpenSetting("sound") }
                }
            }
        }

        // ---- Footer: Centered "Edit Controls" Pill (~110x28, cr=14) ----
        Item {
            width: 292
            height: Math.max(32, ccEditText.implicitHeight + 12)
            GlassSurface {
                anchors.centerIn: parent
                width: Math.min(260, Math.max(112, ccEditText.implicitWidth + 28))
                height: Math.max(28, ccEditText.implicitHeight + 10)
                variant: "clear"
                cornerRadius: height * 0.5
                shadowPreset: "pill"
                backdropItem: root.backdropItem
                Text {
                    id: ccEditText
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - 16)
                    text: "Edit Controls"
                    color: Theme.labelColor
                    font: Typography.callout
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
                MouseArea { anchors.fill: parent; onClicked: ShellState.OpenSetting("controlcenter") }
            }
        }
        }
    }
}
