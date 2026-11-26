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
    implicitHeight: Geometry.toolbarHeightUnified

    ScrollPocket {
        anchors.fill: parent
        scrolled: root.scrolled
        pocketHeight: root.height
        backdropItem: root.backdropItem
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Spacing.lg
        anchors.rightMargin: Spacing.lg
        spacing: Spacing.sm

        RowLayout {
            id: leadingRow
            spacing: Spacing.sm
        }

        Item { Layout.fillWidth: true }

        RowLayout {
            id: centerRow
            spacing: Spacing.sm
        }

        Item { Layout.fillWidth: true }

        RowLayout {
            id: trailingRow
            spacing: Spacing.sm
        }
    }
}
