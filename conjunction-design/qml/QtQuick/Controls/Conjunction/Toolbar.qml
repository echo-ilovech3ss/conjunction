import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Rectangle {
    id: root

    property alias leadingItems: leadingRow.data
    property alias centerItems: centerRow.data
    property alias trailingItems: trailingRow.data

    implicitHeight: 52
    color: Theme.surface
    border.color: Theme.separator
    border.width: Geometry.separatorThickness

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Spacing.md
        anchors.rightMargin: Spacing.md
        spacing: Spacing.sm

        RowLayout {
            id: leadingRow
            spacing: Spacing.xs
        }

        Item { Layout.fillWidth: true }

        RowLayout {
            id: centerRow
            spacing: Spacing.sm
        }

        Item { Layout.fillWidth: true }

        RowLayout {
            id: trailingRow
            spacing: Spacing.xs
        }
    }
}
