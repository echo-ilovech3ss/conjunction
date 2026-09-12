import QtQuick
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls

Surface {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Geometry.contentPadding
        spacing: Spacing.md

        Text {
            text: "Accessibility & Assistive Technology Semantics"
            font: Typography.windowTitle
            color: Theme.textPrimary
        }

        Text {
            text: "All Conjunction controls expose standard Accessible roles (Button, CheckBox, RadioButton, Slider, EditableText, ListItem, Dialog) to the accessibility bridge."
            font: Typography.secondaryBody
            color: Theme.textSecondary
        }

        Rectangle {
            Layout.fillWidth: true
            height: Geometry.separatorThickness
            color: Theme.separator
        }

        RowLayout {
            spacing: Spacing.md

            Button {
                text: "Font Scale 100%"
                onClicked: Appearance.setFontScale(1.0)
            }
            Button {
                text: "Font Scale 125%"
                onClicked: Appearance.setFontScale(1.25)
            }
            Button {
                text: "Font Scale 150%"
                onClicked: Appearance.setFontScale(1.5)
            }
            Button {
                text: "Font Scale 200%"
                onClicked: Appearance.setFontScale(2.0)
            }
        }

        Text {
            text: "Active Scale: " + Math.round(Appearance.fontScale * 100) + "%"
            font: Typography.sectionHeading
            color: Theme.accent
        }

        Item { Layout.fillHeight: true }
    }
}
