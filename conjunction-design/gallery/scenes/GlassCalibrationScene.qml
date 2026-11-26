import QtQuick
import Conjunction.Design
import Conjunction.Controls as C

// Deterministic pixel benchmark scene for SPEC §7 automated Python verification (1080x760)
Item {
    id: calRoot
    implicitWidth: 1080
    implicitHeight: 760

    Item {
        id: calBackdrop
        anchors.fill: parent

        Rectangle { anchors.fill: parent; color: "#808080" }

        // 1. Transfer Bands (x=0..500, y=0..600): uniform 0.0 / 0.5 / 1.0 sRGB (200pt tall each -> >=50pt capture clearance)
        Rectangle { x: 0; y: 0;   width: 500; height: 200; color: Qt.rgba(0.0, 0.0, 0.0, 1.0) }
        Rectangle { x: 0; y: 200; width: 500; height: 200; color: Qt.rgba(0.5, 0.5, 0.5, 1.0) }
        Rectangle { x: 0; y: 400; width: 500; height: 200; color: Qt.rgba(1.0, 1.0, 1.0, 1.0) }

        // 2. Blur Step Edges (y=0..150, padded cleanly from other zones)
        // Clear m=140 step at x=610; Reg Light step (#000000 -> #DCDCDC below MaxLuma 0.94) / Reg Dark step (#000000 -> #505050 below MaxLuma 0.35) at x=910
        Rectangle { x: 500; y: 0; width: 140; height: 150; color: "#000000" }
        Rectangle { x: 640; y: 0; width: 150; height: 150; color: "#FFFFFF" }
        Rectangle { x: 790; y: 0; width: 140; height: 150; color: "#000000" }
        Rectangle { x: 930; y: 0; width: 150; height: 150; color: Appearance.isDark ? "#525252" : "#DCDCDC" }

        // 3. Rim & Tint Backdrops (y=150..320; uniform >=50pt around Rim boxes at x=530..850, y=195..295!)
        Rectangle { x: 500; y: 150; width: 370; height: 185; color: Qt.rgba(0.5, 0.5, 0.5, 1.0) }
        Rectangle { x: 870; y: 150; width: 210; height: 185; color: "#FFFFFF" }

        // 4. Morphing Container Zone (y=335..520)
        Rectangle { x: 500; y: 335; width: 580; height: 185; color: "#141821" }

        // 5. Refraction Displacement Ruler (x=0..500, y=600..760): black left half, white step right at x_inside=24pt from left edge
        Rectangle { x: 0; y: 600; width: 500; height: 160; color: "#000000" }
        Rectangle { x: 80; y: 600; width: 120; height: 160; color: "#FFFFFF" }
        Rectangle { x: 280; y: 600; width: 120; height: 160; color: "#FFFFFF" }
    }

    // ---- 1. RAMP TRANSFER CHECK (rim disabled for pure face matrix measurement) ----
    GlassSurface { x: 30;  y: 30;  width: 140; height: 140; variant: "regular"; cornerRadius: 16; shadowPreset: "none"; rimIntensityScale: 0.0; backdropItem: calBackdrop }
    GlassSurface { x: 30;  y: 230; width: 140; height: 140; variant: "regular"; cornerRadius: 16; shadowPreset: "none"; rimIntensityScale: 0.0; backdropItem: calBackdrop }
    GlassSurface { x: 30;  y: 430; width: 140; height: 140; variant: "regular"; cornerRadius: 16; shadowPreset: "none"; rimIntensityScale: 0.0; backdropItem: calBackdrop }

    GlassSurface { x: 190; y: 30;  width: 140; height: 140; variant: "clear"; cornerRadius: 16; shadowPreset: "none"; rimIntensityScale: 0.0; backdropItem: calBackdrop }
    GlassSurface { x: 190; y: 230; width: 140; height: 140; variant: "clear"; cornerRadius: 16; shadowPreset: "none"; rimIntensityScale: 0.0; backdropItem: calBackdrop }
    GlassSurface { x: 190; y: 430; width: 140; height: 140; variant: "clear"; cornerRadius: 16; shadowPreset: "none"; rimIntensityScale: 0.0; backdropItem: calBackdrop }

    GlassSurface { x: 360; y: 30;  width: 60; height: 140; variant: "regular"; cornerRadius: 16; shadowPreset: "none"; rimIntensityScale: 0.0; backdropItem: calBackdrop }
    GlassSurface { x: 360; y: 230; width: 60; height: 140; variant: "regular"; cornerRadius: 16; shadowPreset: "none"; rimIntensityScale: 0.0; backdropItem: calBackdrop }
    GlassSurface { x: 360; y: 430; width: 60; height: 140; variant: "regular"; cornerRadius: 16; shadowPreset: "none"; rimIntensityScale: 0.0; backdropItem: calBackdrop }

    // ---- 2. BLUR ERF STEP EDGES ----
    GlassSurface { x: 570; y: 15; width: 140; height: 120; variant: "clear";   cornerRadius: 12; shadowPreset: "none"; rimIntensityScale: 0.0; backdropItem: calBackdrop }
    GlassSurface { x: 860; y: 15; width: 140; height: 120; variant: "regular"; cornerRadius: 12; shadowPreset: "none"; rimIntensityScale: 0.0; backdropItem: calBackdrop }

    // ---- 3. SPECULAR RIM (isolated >=48pt inside uniform #808080 band!) & TINT ----
    GlassSurface { x: 540; y: 200; width: 140; height: 85; variant: "regular"; cornerRadius: 16; shadowPreset: "none"; rimIntensityScale: 1.0; backdropItem: calBackdrop }
    GlassSurface { x: 700; y: 200; width: 140; height: 85; variant: "clear";   cornerRadius: 16; shadowPreset: "none"; rimIntensityScale: 1.0; backdropItem: calBackdrop }

    GlassSurface { x: 885; y: 200; width: 75; height: 85; variant: "regular"; tintColor: Qt.rgba(0.0, 0.533, 1.0, 0.50); cornerRadius: 16; shadowPreset: "none"; rimIntensityScale: 0.0; backdropItem: calBackdrop }
    GlassSurface { x: 975; y: 200; width: 75; height: 85; variant: "clear";   tintColor: Qt.rgba(0.0, 0.533, 1.0, 0.50); cornerRadius: 16; shadowPreset: "none"; rimIntensityScale: 0.0; backdropItem: calBackdrop }

    // ---- 4. MORPHING NECK BRIDGE (56pt circles, spacing=24pt, gaps=0, 4, 10, 20) ----
    GlassMorphContainer {
        x: 520; y: 342; width: 250; height: 80; spacing: 24.0; variant: "clear"; backdropItem: calBackdrop
        pillRects: [Qt.rect(125 - 56, 12, 56, 56), Qt.rect(125, 12, 56, 56)]
        pillRadii: [28, 28]
    }
    GlassMorphContainer {
        x: 800; y: 342; width: 250; height: 80; spacing: 24.0; variant: "clear"; backdropItem: calBackdrop
        pillRects: [Qt.rect(125 - 58, 12, 56, 56), Qt.rect(125 + 2, 12, 56, 56)]
        pillRadii: [28, 28]
    }
    GlassMorphContainer {
        x: 520; y: 428; width: 250; height: 80; spacing: 24.0; variant: "clear"; backdropItem: calBackdrop
        pillRects: [Qt.rect(125 - 61, 12, 56, 56), Qt.rect(125 + 5, 12, 56, 56)]
        pillRadii: [28, 28]
    }
    GlassMorphContainer {
        x: 800; y: 428; width: 250; height: 80; spacing: 24.0; variant: "clear"; backdropItem: calBackdrop
        pillRects: [Qt.rect(125 - 66, 12, 56, 56), Qt.rect(125 + 10, 12, 56, 56)]
        pillRadii: [28, 28]
    }

    // ---- 5. EDGE REFRACTION SPECIMEN (left edge x=80 sits over black->white step x=80 so dr(0) samples x=80-45=35 black!) ----
    // Actually place box left edge at x=80 (over white 80..200): inward normal points right (+1, 0), so -normal*dr shifts LEFT into black!
    GlassSurface { x: 80;  y: 620; width: 120; height: 120; variant: "clear";   cornerRadius: 16; shadowPreset: "none"; rimIntensityScale: 0.0; backdropItem: calBackdrop }
    GlassSurface { x: 280; y: 620; width: 120; height: 120; variant: "regular"; cornerRadius: 16; shadowPreset: "none"; rimIntensityScale: 0.0; backdropItem: calBackdrop }

    // ---- 6. CONTROL SIZE RULER SPECIMENS (Table 2.3) ----
    Row {
        x: 520; y: 540; spacing: 8
        C.Button { objectName: "btn_mini"; sizeClass: "mini"; text: "Mini" }
        C.Button { objectName: "btn_small"; sizeClass: "small"; text: "Small" }
        C.Button { objectName: "btn_reg"; sizeClass: "regular"; text: "Regular"; isDefault: true }
        C.Button { objectName: "btn_large"; sizeClass: "large"; text: "Large" }
        C.Button { objectName: "btn_pill"; sizeClass: "pill"; text: "Pill" }
        C.ToolButton { objectName: "btn_tool"; iconName: "search" }
    }
    Row {
        x: 520; y: 595; spacing: 12
        C.Switch { objectName: "sw_reg"; sizeClass: "regular"; checked: true }
        C.Switch { objectName: "sw_small"; sizeClass: "small"; checked: true }
        C.Switch { objectName: "sw_mini"; sizeClass: "mini"; checked: true }
        C.SegmentedControl {
            objectName: "seg_reg"; sizeClass: "regular"
            C.Segment { text: "One" }
            C.Segment { text: "Two" }
        }
        C.SegmentedControl {
            objectName: "seg_tb"; sizeClass: "regular"; inToolbar: true
            C.Segment { text: "Icon" }
            C.Segment { text: "List" }
        }
    }
    Row {
        x: 520; y: 650; spacing: 12
        C.Slider { objectName: "slider_reg"; width: 140; value: 0.5 }
        C.TextField { objectName: "tf_reg"; width: 130; text: "Regular 24pt" }
        C.CheckBox { objectName: "chk_reg"; checked: true; text: "Check" }
        C.RadioButton { objectName: "rad_reg"; checked: true; text: "Radio" }
    }
}
