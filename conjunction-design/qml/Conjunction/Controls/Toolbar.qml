import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Item {
    id: root

    property alias leadingItems: leadingRow.data
    property alias centerItems: centerRow.data
    property alias trailingItems: trailingRow.data
    property bool scrolled: false
    property Item backdropItem: null

    // SPEC §4.6 Unified Toolbar 54 pt over ScrollPocket
    implicitHeight: Math.max(Geometry.toolbarHeightUnified, mainToolbarRow.implicitHeight + 8)
    clip: true

    ScrollPocket {
        anchors.fill: parent
        scrolled: root.scrolled
        pocketHeight: root.height
        backdropItem: root.backdropItem
    }

    RowLayout {
        id: mainToolbarRow
        anchors.fill: parent
        anchors.leftMargin: Spacing.lg
        anchors.rightMargin: Spacing.lg
        spacing: Spacing.sm

        RowLayout {
            id: leadingRow
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: Spacing.sm
        }

        Item { Layout.fillWidth: true; Layout.minimumWidth: 0 }

        RowLayout {
            id: centerRow
            Layout.minimumWidth: 0
            spacing: Spacing.sm
        }

        Item { Layout.fillWidth: true; Layout.minimumWidth: 0 }

        RowLayout {
            id: trailingRow
            Layout.minimumWidth: 0
            spacing: Spacing.sm
        }
    }
}
