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
            x: 40; y: 40; width: 220; height: 220; radius: 60
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#00DAC3" }
                GradientStop { position: 1.0; color: "#007AFF" }
            }
        }
        Rectangle {
            x: 360; y: 20; width: 260; height: 180; radius: 36
            color: "#FFFFFF"
            opacity: 0.92
            Text {
                anchors.centerIn: parent
                text: "HDR WHITE BLOCK\nMaxLumaSDR Test"
                font: Typography.headline
                color: "#111111"
                horizontalAlignment: Text.AlignHCenter
            }
        }
        Rectangle {
            x: 110; y: 265; width: 320; height: 220; radius: 28
            color: "#101218"
            Row {
                anchors.centerIn: parent
                spacing: 14
                Repeater {
                    model: 8
                    Rectangle { width: 18; height: 170; radius: 9; color: index % 2 === 0 ? "#FFD600" : "#FF383C" }
                }
            }
        }
        Rectangle {
            x: 470; y: 240; width: 320; height: 260; radius: 40
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#CB30E0" }
                GradientStop { position: 1.0; color: "#FF8D28" }
            }
        }
    }

    // Foreground Liquid Glass surfaces sampling sibling backdropScene
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20

        RowLayout {
            Layout.fillWidth: true
            spacing: 20

            // Regular Glass
            Item {
                Layout.preferredWidth: 250
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
                    Text { text: "Regular Glass"; font: Typography.title3SemiBold; color: Theme.labelColor }
                    Text { text: Appearance.isDark ? "Dark: sigma 10.5pt, MaxLuma 0.35" : "Light: sigma 14.0pt, Fill 0.20"; font: Typography.subheadline; color: Theme.secondaryLabelColor }
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        C.Button { sizeClass: "pill"; text: "Primary"; isDefault: true }
                        C.Switch { checked: true }
                    }
                }
            }

            // Clear Glass
            Item {
                Layout.preferredWidth: 250
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
                    Text { text: "Clear Glass"; font: Typography.title3SemiBold; color: Theme.labelColor }
                    Text { text: "sigma 20.0pt, refr dr=45.2pt"; font: Typography.subheadline; color: Theme.secondaryLabelColor }
                    Item { Layout.fillHeight: true }
                    Text { text: "Edge-lensing & pure optical lens"; font: Typography.callout; color: Theme.labelColor }
                }
            }

            // Tinted Glass Pair
            Item {
                Layout.preferredWidth: 250
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
                    Text { text: "Tinted Clear Glass"; font: Typography.title3SemiBold; color: "#FFFFFF" }
                    Text { text: "Preserves chroma; Reg desaturates"; font: Typography.subheadline; color: Qt.rgba(1, 1, 1, 0.85) }
                    Item { Layout.fillHeight: true }
                    C.SegmentedControl {
                        Layout.fillWidth: true
                        C.Segment { text: "Day" }
                        C.Segment { text: "Night" }
                    }
                }
            }
        }

        // Row 2: EffectContainer Morphing & ScrollPocket
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 20

            // Interactive Smooth-Min Morphing Container (SPEC §1.4)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

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
                        Text { text: "EffectContainer Morph (gap = " + Math.round(root.morphGap) + " pt, spacing = 24 pt)"; font: Typography.headline; color: "#FFFFFF" }
                        Item { Layout.fillWidth: true }
                        C.Slider {
                            implicitWidth: 160
                            from: 0; to: 24; value: root.morphGap
                            onMoved: root.morphGap = value
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        GlassMorphContainer {
                            anchors.centerIn: parent
                            width: 240
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
                Layout.preferredWidth: 320
                Layout.fillHeight: true
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
                        Text { text: pocketList.contentY > 2 ? "Hard Pocket (0.5pt)" : "Soft Pocket (Fade)"; font: Typography.headline; color: Theme.labelColor }
                    ]
                    trailingItems: [
                        C.ToolButton { iconName: "search" }
                    ]
                }
            }
        }
    }
}
