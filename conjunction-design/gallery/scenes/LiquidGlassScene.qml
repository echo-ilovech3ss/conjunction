import QtQuick
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls as C

Item {
    id: root

    property real morphGap: 6.0

    // Procedural Conjunction abstract wallpaper layer behind glass cards (sibling item)
    Rectangle {
        id: backdropScene
        anchors.fill: parent
        radius: 16
        clip: true
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Appearance.isDark ? "#0C1B33" : "#3478F6" }
            GradientStop { position: 0.45; color: Appearance.isDark ? "#1C2951" : "#64B5F6" }
            GradientStop { position: 1.0; color: Appearance.isDark ? "#311B47" : "#F48FB1" }
        }

        // Bold geometric blocks & contrast strips to showcase refraction, clamping, and blur sigma
        Rectangle {
            x: Math.round(parent.width * 0.05)
            y: Math.round(parent.height * 0.06)
            width: Math.round(parent.width * 0.27)
            height: Math.round(parent.height * 0.34)
            radius: Math.min(60, Math.round(Math.min(width, height) * 0.28))
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#00DAC3" }
                GradientStop { position: 1.0; color: "#007AFF" }
            }
        }
        Rectangle {
            x: Math.round(parent.width * 0.44)
            y: Math.round(parent.height * 0.03)
            width: Math.round(parent.width * 0.32)
            height: Math.round(parent.height * 0.28)
            radius: Math.min(36, Math.round(Math.min(width, height) * 0.2))
            color: "#FFFFFF"
            opacity: 0.92
            clip: true
            Text {
                anchors.centerIn: parent
                width: Math.max(0, parent.width - 16)
                text: "HDR WHITE BLOCK\nMaxLumaSDR Test"
                font: Typography.headline
                color: "#111111"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
            }
        }
        Rectangle {
            x: Math.round(parent.width * 0.14)
            y: Math.round(parent.height * 0.41)
            width: Math.round(parent.width * 0.39)
            height: Math.round(parent.height * 0.34)
            radius: 28
            color: "#101218"
            clip: true
            Row {
                anchors.centerIn: parent
                spacing: Math.max(6, Math.round(parent.width * 0.035))
                Repeater {
                    model: 8
                    Rectangle {
                        width: Math.max(8, Math.round(parent.parent.width * 0.055))
                        height: Math.max(40, Math.round(parent.parent.height * 0.77))
                        radius: Math.round(width * 0.5)
                        color: index % 2 === 0 ? "#FFD600" : "#FF383C"
                    }
                }
            }
        }
        Rectangle {
            x: Math.round(parent.width * 0.57)
            y: Math.round(parent.height * 0.38)
            width: Math.round(parent.width * 0.38)
            height: Math.round(parent.height * 0.40)
            radius: 40
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#CB30E0" }
                GradientStop { position: 1.0; color: "#FF8D28" }
            }
        }
    }

    // Foreground Liquid Glass surfaces sampling sibling backdropScene
    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, foregroundCol.implicitHeight + 48)

        ColumnLayout {
            id: foregroundCol
            x: 24
            y: 24
            width: Math.max(0, parent.width - 48)
            height: Math.max(parent.height - 48, implicitHeight)
            spacing: 20

            GridLayout {
                Layout.fillWidth: true
                columns: root.width < 560 ? 1 : 3
                columnSpacing: 20
                rowSpacing: 16

                // Regular Glass
                Item {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: 160

                    GlassSurface {
                        anchors.fill: parent
                        variant: "regular"
                        cornerRadius: 20
                        backdropItem: backdropScene
                        shadowPreset: "popover"
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 6
                        Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: Appearance.stressMode ? Appearance.stressLongTitle : "Regular Glass"; font: Typography.title3SemiBold; color: Theme.labelColor; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: Appearance.isDark ? "Dark: sigma 10.5pt, MaxLuma 0.35" : "Light: sigma 14.0pt, Fill 0.20"; font: Typography.subheadline; color: Theme.secondaryLabelColor; elide: Text.ElideRight }
                        Item { Layout.fillHeight: true }
                        RowLayout {
                            Layout.fillWidth: true
                            C.Button { sizeClass: "pill"; text: "Primary"; isDefault: true; Layout.minimumWidth: 0; Layout.maximumWidth: 110; Layout.fillWidth: true }
                            C.Switch { checked: true }
                        }
                    }
                }

                // Clear Glass
                Item {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: 160

                    GlassSurface {
                        anchors.fill: parent
                        variant: "clear"
                        cornerRadius: 20
                        backdropItem: backdropScene
                        shadowPreset: "popover"
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 6
                        Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: "Clear Glass"; font: Typography.title3SemiBold; color: Theme.labelColor; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: "sigma 20.0pt, refr dr=45.2pt"; font: Typography.subheadline; color: Theme.secondaryLabelColor; elide: Text.ElideRight }
                        Item { Layout.fillHeight: true }
                        Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: "Edge-lensing & pure optical lens"; font: Typography.callout; color: Theme.labelColor; elide: Text.ElideRight }
                    }
                }

                // Tinted Glass Pair
                Item {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: 160

                    GlassSurface {
                        anchors.fill: parent
                        variant: "clear"
                        cornerRadius: 20
                        backdropItem: backdropScene
                        tintColor: Qt.rgba(0.0, 0.533, 1.0, 0.32)
                        shadowPreset: "popover"
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 6
                        Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: "Tinted Clear Glass"; font: Typography.title3SemiBold; color: "#FFFFFF"; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: "Preserves chroma; Reg desaturates"; font: Typography.subheadline; color: Qt.rgba(1, 1, 1, 0.85); elide: Text.ElideRight }
                        Item { Layout.fillHeight: true }
                        C.SegmentedControl {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            C.Segment { text: "Day" }
                            C.Segment { text: "Night" }
                        }
                    }
                }
            }

            // Row 2: EffectContainer Morphing & ScrollPocket
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: root.width < 560 ? 1 : 2
                columnSpacing: 20
                rowSpacing: 16

                // Interactive Smooth-Min Morphing Container (SPEC §1.4)
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 0
                    Layout.minimumHeight: 190

                    Rectangle {
                        anchors.fill: parent
                        radius: 18
                        color: Qt.rgba(0, 0, 0, 0.25)
                        border.color: Theme.separator
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: "EffectContainer Morph (gap = " + Math.round(root.morphGap) + " pt, spacing = 24 pt)"; font: Typography.headline; color: "#FFFFFF"; elide: Text.ElideRight }
                            C.Slider {
                                Layout.preferredWidth: 140
                                Layout.minimumWidth: 64
                                Layout.maximumWidth: 160
                                Layout.fillWidth: true
                                from: 0; to: 24; value: root.morphGap
                                onMoved: root.morphGap = value
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            GlassMorphContainer {
                                anchors.centerIn: parent
                                width: Math.min(240, parent.width - 8)
                                height: 96
                                spacing: 24.0
                                variant: "clear"
                                backdropItem: backdropScene
                                readonly property real cy: height * 0.5
                                readonly property real c1x: (width - (112 + root.morphGap)) * 0.5 + 28
                                readonly property real c2x: c1x + 56 + root.morphGap
                                pillRects: [
                                    Qt.rect(c1x - 28, cy - 28, 56, 56),
                                    Qt.rect(c2x - 28, cy - 28, 56, 56)
                                ]
                                pillRadii: [28, 28]
                            }
                        }
                    }
                }

                // ScrollPocket Soft vs Hard
                Item {
                    Layout.fillWidth: root.width < 560
                    Layout.preferredWidth: root.width < 560 ? -1 : Math.min(320, Math.round((root.width - 68) * 0.44))
                    Layout.fillHeight: true
                    Layout.minimumWidth: 0
                    Layout.minimumHeight: 220
                    clip: true

                    SquircleRect {
                        anchors.fill: parent
                        radius: 18
                        color: Theme.textBackgroundColor
                        borderColor: Theme.separator
                        borderWidth: 1
                    }

                    ListView {
                        id: pocketList
                        anchors.fill: parent
                        topMargin: 54
                        clip: true
                        model: 20
                        delegate: C.ListRow {
                            width: pocketList.width
                            title: "Conjunction Item " + (index + 1)
                            subtitle: "Scroll under the 54pt ScrollPocket toolbar"
                            iconName: index % 2 === 0 ? "folder" : "file"
                        }
                    }

                    C.Toolbar {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        scrolled: pocketList.contentY > 2
                        backdropItem: backdropScene
                        leadingItems: [
                            Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: pocketList.contentY > 2 ? "Hard Pocket (0.5pt)" : "Soft Pocket (Fade)"; font: Typography.headline; color: Theme.labelColor; elide: Text.ElideRight }
                        ]
                        trailingItems: [
                            C.ToolButton { iconName: "search" }
                        ]
                    }
                }
            }
        }
    }
}
