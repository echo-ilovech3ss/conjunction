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
            text: "Progress Indicators & Sliders"
            font: Typography.windowTitle
            color: Theme.textPrimary
        }

        Rectangle {
            Layout.fillWidth: true
            height: Geometry.separatorThickness
            color: Theme.separator
        }

        Text {
            text: "Sliders (Track, filled region, keyboard step)"
            font: Typography.sectionHeading
            color: Theme.textPrimary
        }

        RowLayout {
            spacing: Spacing.md

            Slider {
                id: testSlider
                value: 0.65
                implicitWidth: 260
            }

            Text {
                text: Math.round(testSlider.value * 100) + "%"
                font: Typography.controlLabel
                color: Theme.textPrimary
            }
        }

        Text {
            text: "Progress Bars (Determinate & Indeterminate)"
            font: Typography.sectionHeading
            color: Theme.textPrimary
        }

        ColumnLayout {
            spacing: Spacing.sm

            Text { text: "Determinate (65%)"; font: Typography.caption; color: Theme.textSecondary }
            ProgressBar {
                value: 0.65
                implicitWidth: 320
            }

            Text { text: "Indeterminate Activity Bar"; font: Typography.caption; color: Theme.textSecondary }
            ProgressBar {
                indeterminate: true
                implicitWidth: 320
            }
        }

        Text {
            text: "Activity Spinner (Respects Reduced Motion)"
            font: Typography.sectionHeading
            color: Theme.textPrimary
        }

        RowLayout {
            spacing: Spacing.md

            ActivityIndicator {
                size: 24
            }

            Text {
                text: Appearance.reducedMotion ? "Motion Reduced (Static)" : "Active Processing..."
                font: Typography.body
                color: Theme.textSecondary
            }
        }

        Item { Layout.fillHeight: true }
    }
}
