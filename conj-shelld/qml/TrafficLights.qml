import QtQuick
import Conjunction.Design

Item {
    id: root
    property bool active: true
    property bool altPressed: false
    property bool canClose: true
    property bool canMinimize: true
    property bool canZoom: true
    property real buttonSize: 14
    property real buttonSpacing: 9 // center-to-center 14 + 9 = 23 pt (SPEC §4.6)

    signal closeClicked()
    signal minimizeClicked()
    signal zoomClicked()

    implicitWidth: buttonSize * 3 + buttonSpacing * 2
    implicitHeight: buttonSize

    property bool groupHovered: clusterArea.containsMouse

    MouseArea {
        id: clusterArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Row {
        spacing: root.buttonSpacing

        // Close
        Rectangle {
            width: root.buttonSize
            height: root.buttonSize
            radius: root.buttonSize * 0.5
            color: (root.active || root.groupHovered) ? Theme.trafficLightClose : Theme.trafficLightInactive
            border.width: Theme.highContrast ? 1.5 : 0.75
            border.color: (root.active || root.groupHovered) ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(0, 0, 0, 0.12)
            Behavior on color { ColorAnimation { duration: Motion.hoverSwap } }

            Canvas {
                anchors.fill: parent
                visible: root.groupHovered && root.canClose
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = Qt.rgba(0.28, 0.04, 0.04, 0.85);
                    ctx.lineWidth = 1.4;
                    ctx.lineCap = "round";
                    var p = width * 0.30;
                    ctx.beginPath();
                    ctx.moveTo(p, p); ctx.lineTo(width - p, height - p);
                    ctx.moveTo(width - p, p); ctx.lineTo(p, height - p);
                    ctx.stroke();
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.canClose
                onClicked: root.closeClicked()
            }
        }

        // Minimize
        Rectangle {
            width: root.buttonSize
            height: root.buttonSize
            radius: root.buttonSize * 0.5
            color: (root.active || root.groupHovered) ? Theme.trafficLightMinimize : Theme.trafficLightInactive
            border.width: Theme.highContrast ? 1.5 : 0.75
            border.color: (root.active || root.groupHovered) ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(0, 0, 0, 0.12)
            Behavior on color { ColorAnimation { duration: Motion.hoverSwap } }

            Rectangle {
                visible: root.groupHovered && root.canMinimize
                anchors.centerIn: parent
                width: root.buttonSize * 0.52
                height: 1.5
                radius: 0.75
                color: Qt.rgba(0.32, 0.20, 0.02, 0.85)
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.canMinimize
                onClicked: root.minimizeClicked()
            }
        }

        // Zoom / Fullscreen (+ with Alt)
        Rectangle {
            width: root.buttonSize
            height: root.buttonSize
            radius: root.buttonSize * 0.5
            color: (root.active || root.groupHovered) ? Theme.trafficLightZoom : Theme.trafficLightInactive
            border.width: Theme.highContrast ? 1.5 : 0.75
            border.color: (root.active || root.groupHovered) ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(0, 0, 0, 0.12)
            Behavior on color { ColorAnimation { duration: Motion.hoverSwap } }

            Item {
                anchors.fill: parent
                visible: root.groupHovered && root.canZoom
                Canvas {
                    anchors.fill: parent
                    property bool alt: root.altPressed
                    onAltChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = Qt.rgba(0.05, 0.25, 0.05, 0.85);
                        ctx.strokeStyle = ctx.fillStyle;
                        if (alt) {
                            ctx.lineWidth = 1.4;
                            ctx.beginPath();
                            ctx.moveTo(width * 0.5, width * 0.25); ctx.lineTo(width * 0.5, width * 0.75);
                            ctx.moveTo(width * 0.25, width * 0.5); ctx.lineTo(width * 0.75, width * 0.5);
                            ctx.stroke();
                        } else {
                            ctx.beginPath();
                            ctx.moveTo(width * 0.28, width * 0.28);
                            ctx.lineTo(width * 0.62, width * 0.28);
                            ctx.lineTo(width * 0.28, width * 0.62);
                            ctx.closePath();
                            ctx.fill();
                            ctx.beginPath();
                            ctx.moveTo(width * 0.72, width * 0.72);
                            ctx.lineTo(width * 0.38, width * 0.72);
                            ctx.lineTo(width * 0.72, width * 0.38);
                            ctx.closePath();
                            ctx.fill();
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.canZoom
                onClicked: root.zoomClicked()
            }
        }
    }
}
