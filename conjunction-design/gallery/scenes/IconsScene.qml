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
            text: "Semantic Icons Foundation"
            font: Typography.windowTitle
            color: Theme.textPrimary
        }

        Rectangle {
            Layout.fillWidth: true
            height: Geometry.separatorThickness
            color: Theme.separator
        }

        GridLayout {
            columns: 4
            rowSpacing: Spacing.md
            columnSpacing: Spacing.md
            Layout.fillWidth: true

            component IconCard: Rectangle {
                property string iconName: ""
                property color iconColor: Theme.textPrimary

                Layout.fillWidth: true
                height: 70
                radius: Geometry.radiusMedium
                color: Theme.surfaceSecondary
                border.color: Theme.separator
                border.width: Geometry.separatorThickness

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Spacing.xs

                    Icon {
                        name: iconName
                        size: 24
                        color: iconColor
                        Layout.alignment: Qt.AlignCenter
                    }

                    Text {
                        text: iconName
                        font: Typography.caption
                        color: Theme.textPrimary
                        Layout.alignment: Qt.AlignCenter
                    }
                }
            }

            IconCard { iconName: "settings"; iconColor: Theme.textPrimary }
            IconCard { iconName: "search"; iconColor: Theme.textPrimary }
            IconCard { iconName: "check"; iconColor: Theme.success }
            IconCard { iconName: "close"; iconColor: Theme.destructive }

            IconCard { iconName: "warning"; iconColor: Theme.warning }
            IconCard { iconName: "refresh"; iconColor: Theme.accent }
            IconCard { iconName: "copy"; iconColor: Theme.textSecondary }
            IconCard { iconName: "arrow-right"; iconColor: Theme.textPrimary }
        }

        Item { Layout.fillHeight: true }
    }
}
