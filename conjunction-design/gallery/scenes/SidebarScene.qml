import QtQuick
import QtQuick.Layouts
import Conjunction.Design
import Conjunction.Controls

Surface {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            Layout.fillHeight: true
            implicitWidth: 220

            SidebarSection { title: "Favorites" }
            SidebarRow { title: "Applications"; iconName: "settings"; selected: true; badgeText: "18" }
            SidebarRow { title: "Adapters & Packages"; iconName: "copy"; badgeText: "4" }
            SidebarRow { title: "Recent Launches"; iconName: "refresh" }

            SidebarSection { title: "System Services" }
            SidebarRow { title: "Application Daemon (appd)"; iconName: "check" }
            SidebarRow { title: "Privileged Service (sysd)"; iconName: "settings" }
            SidebarRow { title: "Diagnostics & Logs"; iconName: "warning"; badgeText: "2" }

            SidebarSection { title: "Categories" }
            SidebarRow { title: "Development Tools"; iconName: "settings" }
            SidebarRow { title: "Internet & Networking"; iconName: "search" }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.surface

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Geometry.contentPadding
                spacing: Spacing.sm

                Text {
                    text: "Sidebar Interaction Semantics"
                    font: Typography.windowTitle
                    color: Theme.textPrimary
                }

                Text {
                    text: "The sidebar represents the leading navigation column. Selection highlights are soft and accent-aware. The keyboard focus ring remains distinct from item selection."
                    font: Typography.body
                    color: Theme.textSecondary
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
