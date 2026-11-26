import QtQuick

Item {
    id: root

    // SPEC §1.3 Scroll-Edge Pocket ("soft" vs "hard")
    property bool scrolled: false
    property bool hardPocket: false
    property real pocketHeight: 54.0
    property Item backdropItem: null
    property bool darkMode: Appearance.isDark

    implicitWidth: 400
    implicitHeight: pocketHeight

    readonly property bool useHard: scrolled || hardPocket

    GlassSurface {
        anchors.fill: parent
        variant: "regular"
        cornerRadius: 0
        darkMode: root.darkMode
        backdropItem: root.backdropItem
        shadowPreset: "none"
        rimIntensityScale: 0.0
        scrollPocketMode: root.useHard ? "hard" : "soft"
        pocketHeight: root.pocketHeight
    }

    // Soft chroma-adaptive scrim + Hard 0.5pt hairline
    Rectangle {
        anchors.fill: parent
        visible: !root.useHard && !Appearance.shouldReduceTransparency
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.darkMode ? Qt.rgba(0.18, 0.18, 0.20, 0.8245) : Qt.rgba(0.95, 0.96, 0.98, 0.8245) }
            GradientStop { position: 0.72; color: root.darkMode ? Qt.rgba(0.18, 0.18, 0.20, 0.45) : Qt.rgba(0.95, 0.96, 0.98, 0.45) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Appearance.shouldIncreaseContrast ? 1.0 : Geometry.hairlineThickness
        visible: root.useHard || Appearance.shouldIncreaseContrast || Appearance.shouldReduceTransparency
        color: Theme.toolbarPocketHairline
    }
}
