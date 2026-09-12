import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Surface {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Geometry.contentPadding
        spacing: Spacing.md

        Text {
            text: "Spacing & Grid System"
            font: Typography.windowTitle
            color: Theme.textPrimary
        }

        Rectangle {
            Layout.fillWidth: true
            height: Geometry.separatorThickness
            color: Theme.separator
        }

        ColumnLayout {
            spacing: Spacing.sm
            Layout.fillWidth: true

            component SpacingRow: RowLayout {
                property string name: ""
                property int tokenValue: 0

                spacing: Spacing.md
                Layout.fillWidth: true

                Text {
                    text: name + " (" + tokenValue + "px)"
                    font: Typography.controlLabel
                    color: Theme.textPrimary
                    Layout.preferredWidth: 140
                }

                Rectangle {
                    width: tokenValue
                    height: 20
                    color: Theme.accent
                    radius: Geometry.radiusSmall
                }
            }

            SpacingRow { name: "Spacing.none"; tokenValue: Spacing.none }
            SpacingRow { name: "Spacing.xxs"; tokenValue: Spacing.xxs }
            SpacingRow { name: "Spacing.xs"; tokenValue: Spacing.xs }
            SpacingRow { name: "Spacing.sm"; tokenValue: Spacing.sm }
            SpacingRow { name: "Spacing.md"; tokenValue: Spacing.md }
            SpacingRow { name: "Spacing.lg"; tokenValue: Spacing.lg }
            SpacingRow { name: "Spacing.xl"; tokenValue: Spacing.xl }
            SpacingRow { name: "Spacing.xxl"; tokenValue: Spacing.xxl }
        }

        Item { Layout.fillHeight: true }
    }
}
