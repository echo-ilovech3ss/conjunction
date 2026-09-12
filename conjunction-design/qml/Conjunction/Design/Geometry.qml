pragma Singleton
import QtQuick

QtObject {
    id: root

    // Control Heights
    readonly property int controlHeightSmall: 24
    readonly property int controlHeightMedium: 32
    readonly property int controlHeightLarge: 40
    readonly property int minTargetSize: 32

    // Radii
    readonly property int radiusSmall: 4
    readonly property int radiusMedium: 8
    readonly property int radiusLarge: 12
    readonly property int radiusPill: 999

    // Lines & Focus Rings
    readonly property int separatorThickness: 1
    readonly property int focusRingThickness: 2
    readonly property int focusRingOffset: 2

    // Layout Margins
    readonly property int windowMargin: 16
    readonly property int contentPadding: 12
}
