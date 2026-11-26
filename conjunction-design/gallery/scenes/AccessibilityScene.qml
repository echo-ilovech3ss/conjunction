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
            Layout.fillWidth: true
            text: "Accessibility: Contrast, Transparency & Motion"
            font: Typography.windowTitle
            color: Theme.textPrimary
            elide: Text.ElideRight
        }

        Text {
            text: "Supports Reduce Transparency (#EDEDED/#282828 solid chrome), Increase Contrast (65% dividers, 1pt borders, pure label primaries), Reduced Motion (180ms crossfades), and Font Scaling."
            font: Typography.secondaryBody
            color: Theme.textSecondary
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.fillWidth: true
            height: Geometry.separatorThickness
            color: Theme.separator
        }

        Flow {
            Layout.fillWidth: true
            spacing: Spacing.md
            CheckBox {
                text: "Reduce Transparency"
                checked: Appearance.reduceTransparency
                onToggled: Appearance.setReduceTransparency(checked)
            }
            CheckBox {
                text: "Increase Contrast"
                checked: Appearance.increaseContrast
                onToggled: Appearance.setIncreaseContrast(checked)
            }
            CheckBox {
                text: "Reduced Motion"
                checked: Appearance.reducedMotion
                onToggled: Appearance.setReducedMotion(checked)
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Spacing.md
            Button { text: "Font Scale 100%"; onClicked: Appearance.setFontScale(1.0) }
            Button { text: "Font Scale 125%"; onClicked: Appearance.setFontScale(1.25) }
            Button { text: "Font Scale 150%"; onClicked: Appearance.setFontScale(1.5) }
            Button { text: "Font Scale 200%"; onClicked: Appearance.setFontScale(2.0) }
        }

        Text {
            Layout.fillWidth: true
            text: "Active Scale: " + Math.round(Appearance.fontScale * 100) + "% | Optical Cap-Scale: " + (Appearance.useOpticalCapScaling ? "ON (0.9685x)" : "OFF")
            font: Typography.sectionHeading
            color: Theme.accent
            wrapMode: Text.Wrap
        }

        Item { Layout.fillHeight: true }
    }
}
