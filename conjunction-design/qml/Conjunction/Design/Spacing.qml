pragma Singleton
import QtQuick

QtObject {
    id: root

    // SPEC §2.2 Spacing Grid
    readonly property int none: 0
    readonly property int xxs: 2    // segmented thumb inset, hairline offset, slider knob gap
    readonly property int xs: 4     // base grid unit / menu item padding
    readonly property int sm: 8     // standard inline control gap
    readonly property int inset: 10 // sidebar pill horizontal inset, card vertical gap
    readonly property int md: 12    // Control Center gutter, Dock inner margin
    readonly property int lg: 16    // Sheet edge margin, card padding, NC margin
    readonly property int xl: 20    // Window body content outer margin
    readonly property int xxl: 24   // EffectContainer morphing neighborhood radius
}
