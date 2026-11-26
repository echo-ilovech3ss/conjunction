import QtQuick
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls

Surface {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    Flickable {
        id: stressFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: stressCol.implicitHeight + Geometry.contentPadding * 2
        clip: true

        ColumnLayout {
            id: stressCol
            x: Geometry.contentPadding
            y: Geometry.contentPadding
            width: Math.max(200, stressFlick.width - Geometry.contentPadding * 2)
            spacing: Spacing.md

            Text {
                Layout.fillWidth: true
                text: Appearance.stressLongTitle
                font: Typography.windowTitle
                color: Theme.textPrimary
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: Appearance.stressCompoundWord + " " + Appearance.stressUnbrokenUrl
                font: Typography.secondaryBody
                color: Theme.textSecondary
                wrapMode: Text.Wrap
            }

            Toolbar {
                Layout.fillWidth: true
                leadingItems: [
                    ToolButton { iconName: "arrow-left"; tooltipText: "Back" },
                    ToolButton { iconName: "arrow-right"; tooltipText: "Forward" },
                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.maximumWidth: Math.min(180, Math.round(stressCol.width * 0.24))
                        text: Appearance.stressLongTitle
                        font: Typography.sectionHeading
                        color: Theme.textPrimary
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                ]
                centerItems: [
                    SegmentedControl {
                        currentIndex: 0
                        Layout.fillWidth: true
                        Layout.minimumWidth: 64
                        Layout.maximumWidth: Math.min(200, Math.round(stressCol.width * 0.36))
                        Segment { text: "OverwhelminglyLongSegmentOne" }
                        Segment { text: "Donaudampfschifffahrt" }
                        Segment { text: "Third" }
                    }
                ]
                trailingItems: [
                    Button { text: "LongPrimaryActionLabelForTesting"; isDefault: true; Layout.minimumWidth: 44; Layout.maximumWidth: Math.min(120, Math.round(stressCol.width * 0.22)) }
                ]
            }

            GridLayout {
                Layout.fillWidth: true
                columns: stressCol.width < 540 ? 1 : 3
                columnSpacing: Spacing.sm
                rowSpacing: Spacing.xs

                Button {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: "SuperLongPrimaryButton_" + Appearance.stressCompoundWord
                    isDefault: true
                }
                Button {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: Appearance.stressUnbrokenUrl
                }
                ToolButton {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.maximumWidth: stressCol.width < 540 ? stressCol.width : 140
                    iconName: "settings"
                    text: "VeryLongToolButtonCaptionHere"
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: root.width < 600 ? 1 : 2
                columnSpacing: Spacing.md
                rowSpacing: Spacing.sm

                CheckBox {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: "Checkbox: " + Appearance.stressLongTitle
                    checked: true
                }
                RadioButton {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: "Radio: " + Appearance.stressCompoundWord
                    checked: true
                }
                Switch {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: "Switch: " + Appearance.stressUnbrokenUrl
                    checked: true
                }
                ComboBox {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    model: [
                        Appearance.stressLongTitle,
                        Appearance.stressCompoundWord,
                        Appearance.stressUnbrokenUrl
                    ]
                }
                SearchField {
                    Layout.fillWidth: true
                    text: Appearance.stressUnbrokenUrl
                }
                TextField {
                    Layout.fillWidth: true
                    text: Appearance.stressLongTitle
                    showClearButton: true
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: stressCol.width < 540 ? 1 : 2
                columnSpacing: Spacing.md
                rowSpacing: Spacing.sm

                Sidebar {
                    Layout.fillWidth: stressCol.width < 540
                    Layout.preferredWidth: stressCol.width < 540 ? stressCol.width : Math.min(200, Math.round(stressCol.width * 0.36))
                    Layout.preferredHeight: 160
                    SidebarSection { title: "Extremely Long Sidebar Section Title Overflow Check" }
                    SidebarRow {
                        title: Appearance.stressLongTitle
                        iconName: "settings"
                        selected: true
                        badgeText: "99999+"
                    }
                    SidebarRow {
                        title: Appearance.stressCompoundWord
                        iconName: "copy"
                        badgeText: "NEW"
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 0

                    DisclosureControl {
                        Layout.fillWidth: true
                        title: Appearance.stressLongTitle
                    }
                    ListRow {
                        Layout.fillWidth: true
                        title: Appearance.stressLongTitle
                        subtitle: Appearance.stressUnbrokenUrl
                        iconName: "globe"
                        accessoryItem: Button { text: "InspectBundleAction"; sizeClass: "small"; Layout.maximumWidth: 130 }
                    }
                    TableHeader {
                        Layout.fillWidth: true
                        columns: ["SuperLongColumnHeadingAlpha", "Donaudampfschifffahrtsgesellschaft", "StatusURLIdentifier"]
                    }
                    TableDataRow {
                        Layout.fillWidth: true
                        values: [Appearance.stressCompoundWord, Appearance.stressLongTitle, Appearance.stressUnbrokenUrl]
                        selected: true
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: Spacing.sm

                Button { id: stMenuBtn; text: "Stress Menu"; Layout.maximumWidth: 140; onClicked: stMenu.popup(stMenuBtn, 0, stMenuBtn.height + 4) }
                Button { id: stPopBtn; text: "Stress Popover"; Layout.maximumWidth: 150; onClicked: stPop.open() }
                Button { id: stDlgBtn; text: "Stress Dialog"; Layout.maximumWidth: 140; onClicked: stDlg.open() }
                Button { id: stSheetBtn; text: "Stress Sheet"; Layout.maximumWidth: 140; onClicked: stSheet.open() }
            }

            Menu {
                id: stMenu
                MenuHeading { text: Appearance.stressLongTitle }
                MenuItem { text: Appearance.stressLongTitle; iconName: "settings"; shortcutText: "Ctrl+Shift+Alt+F12" }
                CheckableMenuItem { text: Appearance.stressCompoundWord; checked: true }
                MenuItem { text: Appearance.stressUnbrokenUrl; isDestructive: true }
            }

            Popover {
                id: stPop
                invokerItem: stPopBtn
                x: 8
                y: 8
                implicitWidth: 320
                implicitHeight: 160
                ColumnLayout {
                    anchors.fill: parent
                    spacing: Spacing.sm
                    Text { Layout.fillWidth: true; text: Appearance.stressLongTitle; font: Typography.headline; color: Theme.textPrimary; elide: Text.ElideRight }
                    Text { Layout.fillWidth: true; text: Appearance.stressUnbrokenUrl; font: Typography.body; color: Theme.textSecondary; wrapMode: Text.Wrap; elide: Text.ElideRight; maximumLineCount: 3 }
                }
            }

            Dialog {
                id: stDlg
                invokerItem: stDlgBtn
                titleText: Appearance.stressLongTitle
                messageText: Appearance.stressCompoundWord + "\n\n" + Appearance.stressUnbrokenUrl + "\n\n" + Appearance.stressLongTitle
            }

            Sheet {
                id: stSheet
                invokerItem: stSheetBtn
                titleText: Appearance.stressCompoundWord
                messageText: Appearance.stressUnbrokenUrl + "\n\n" + Appearance.stressLongTitle
            }
        }
    }
}
