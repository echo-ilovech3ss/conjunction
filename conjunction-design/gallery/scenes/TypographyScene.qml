import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Surface {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    Flickable {
        anchors.fill: parent
        anchors.margins: Geometry.contentPadding
        clip: true
        contentWidth: width
        contentHeight: typoMainCol.implicitHeight

        ColumnLayout {
            id: typoMainCol
            width: parent.width
            spacing: Spacing.md

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Typography Hierarchy (Inter / Inter Display / JetBrains Mono)"
                font: Typography.windowTitle
                color: Theme.textPrimary
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.fillWidth: true
                height: Geometry.separatorThickness
                color: Theme.separator
            }

            ColumnLayout {
                spacing: Spacing.sm
                Layout.fillWidth: true

                Text { Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight; text: "Large Title (26 pt Inter Display, 0.9685x cap-scaled)"; font: Typography.largeTitle; color: Theme.textPrimary }
                Text { Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight; text: "Title 1 (22 pt Inter Display)"; font: Typography.title1; color: Theme.textPrimary }
                Text { Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight; text: "Title 2 Bold (17 pt Inter — Alert Headings)"; font: Typography.title2Bold; color: Theme.textPrimary }
                Text { Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight; text: "Title 3 SemiBold (15 pt Inter — Toolbar & Inspector Titles)"; font: Typography.title3SemiBold; color: Theme.textPrimary }
                Text { Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight; text: "Headline (13 pt SemiBold Inter)"; font: Typography.headline; color: Theme.textPrimary }
                Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: "Body / Regular Control (13 pt Inter — 19 pt line height, tracking -0.0010 em)"; font: Typography.body; color: Theme.textPrimary; wrapMode: Text.WordWrap }
                Text { Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight; text: "Callout (12 pt Inter — secondary table rows)"; font: Typography.callout; color: Theme.textSecondary }
                Text { Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight; text: "Subheadline Bold (11 pt — Sidebar Section Headers)"; font: Typography.subheadlineBold; color: Theme.textSecondary }
                Text { Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight; text: "Status Bar Tabular Figures (11 pt tnum): Thu 26 Nov 22:00 — 1 of 113 selected, 15.97 GB available"; font: Typography.subheadlineTnum; color: Theme.textPrimary }
                Text { Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight; text: "Footnote / Caption 2 (10 pt Medium — toolbar labels & tags)"; font: Typography.caption2; color: Theme.textSecondary }
                Text { Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight; text: "Mini Control (9 pt Inter)"; font: Typography.miniControl; color: Theme.textSecondary }
                Text { Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight; text: "Code Mono (13 pt JetBrains Mono 0.9652x): sha256:7f83b165 / 0123456789"; font: Typography.codeMono; color: Theme.textPrimary }
            }
        }
    }
}
