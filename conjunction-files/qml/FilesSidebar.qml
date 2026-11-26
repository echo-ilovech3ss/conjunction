import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Conjunction.Design
import Conjunction.Controls as C

// SPEC §4.7 Left Navigation Glass Sidebar (216 pt width, 10 pt selection pills, eject controls)
Item {
    id: root
    width: 216
    property Item backdropItem: null
    signal locationSelected(string path)
    signal ejectRequested(string mountPoint)

    GlassSurface {
        anchors.fill: parent
        variant: "regular"
        cornerRadius: 0
        shadowPreset: "none"
        backdropItem: root.backdropItem
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Theme.separatorColor
    }

    ListView {
        id: sidebarList
        anchors.fill: parent
        anchors.margins: 10
        model: SidebarModel
        spacing: 2
        clip: true

        section.property: "section"
        section.criteria: ViewSection.FullString
        section.delegate: Item {
            width: sidebarList.width
            height: 26

            Text {
                text: section.toUpperCase()
                font: Typography.caption2
                color: Theme.secondaryLabelColor
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
            }
        }

        delegate: Item {
            id: rowItem
            width: sidebarList.width
            height: 30

            property bool isCurrent: (FilesModel.currentPath === model.path)
            property bool isHovered: mouseArea.containsMouse

            Rectangle {
                anchors.fill: parent
                radius: Geometry.radiusSidebarPill // SPEC §2.1: 10 pt sidebar selection pill
                color: rowItem.isCurrent
                    ? Theme.systemBlue
                    : (rowItem.isHovered || dropArea.containsDrag ? Theme.controlFillHover : "transparent")
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 8

                Image {
                    source: "image://icon/" + model.iconName
                    width: 16
                    height: 16
                    fillMode: Image.PreserveAspectFit
                    opacity: rowItem.isCurrent ? 1.0 : 0.88
                }

                Text {
                    Layout.fillWidth: true
                    text: model.name
                    font: rowItem.isCurrent ? Typography.headline : Typography.body
                    color: rowItem.isCurrent ? "#FFFFFF" : Theme.labelColor
                    elide: Text.ElideRight
                }

                // Inline Eject button for mounted .cdmg / removable volumes (SPEC §5.2)
                Item {
                    visible: !!model.isMount
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    Rectangle {
                        anchors.fill: parent; radius: 6
                        color: ejectMouse.containsMouse ? Qt.rgba(1,1,1,0.22) : "transparent"
                    }
                    Icon {
                        anchors.centerIn: parent
                        name: "eject"
                        preferPhosphor: true
                        size: 13
                        color: rowItem.isCurrent ? "#FFFFFF" : Theme.secondaryLabelColor
                    }
                    MouseArea {
                        id: ejectMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.ejectRequested(model.path);
                        }
                    }
                }
            }

            // Drag .app onto Applications to install into /Applications or ~/Applications
            DropArea {
                id: dropArea
                anchors.fill: parent
                enabled: model.path.endsWith("/Applications")
                onDropped: (drop) => {
                    if (drop.hasUrls && drop.urls.length > 0) {
                        var p = drop.urls[0].toString().replace("file://", "");
                        if (p.endsWith(".app")) {
                            FileOps.installAppBundle(p, model.path);
                        }
                    }
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                anchors.rightMargin: model.isMount ? 24 : 0
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    FilesModel.setPath(model.path);
                    root.locationSelected(model.path);
                }
            }
        }
    }
}
