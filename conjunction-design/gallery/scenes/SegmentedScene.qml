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
            text: "Segmented Controls"
            font: Typography.windowTitle
            color: Theme.textPrimary
        }

        Text {
            text: "Used for small groups of closely related choices, view modes, or sorting modes. Adjacent segments form a cohesive unified control."
            font: Typography.secondaryBody
            color: Theme.textSecondary
        }

        Rectangle {
            Layout.fillWidth: true
            height: Geometry.separatorThickness
            color: Theme.separator
        }

        Text {
            text: "Text Segments (View Mode Selector)"
            font: Typography.sectionHeading
            color: Theme.textPrimary
        }

        SegmentedControl {
            currentIndex: 0
            Segment { text: "Day View" }
            Segment { text: "Week View" }
            Segment { text: "Month View" }
            Segment { text: "Year View" }
        }

        Text {
            text: "Icon Segments (Layout Presentation Selector)"
            font: Typography.sectionHeading
            color: Theme.textPrimary
        }

        SegmentedControl {
            currentIndex: 1
            Segment { iconName: "copy"; text: "Cards" }
            Segment { iconName: "search"; text: "List" }
            Segment { iconName: "settings"; text: "Grid" }
        }

        Text {
            text: "Compact Icon-Only Segments"
            font: Typography.sectionHeading
            color: Theme.textPrimary
        }

        SegmentedControl {
            currentIndex: 0
            Segment { iconName: "arrow-left" }
            Segment { iconName: "refresh" }
            Segment { iconName: "arrow-right" }
        }

        Item { Layout.fillHeight: true }
    }
}
