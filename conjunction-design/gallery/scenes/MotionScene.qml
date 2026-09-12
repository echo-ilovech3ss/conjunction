import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Surface {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    property bool moved: false

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Geometry.contentPadding
        spacing: Spacing.md

        Text {
            text: "Motion Tokens & Reduced Motion"
            font: Typography.windowTitle
            color: Theme.textPrimary
        }

        Text {
            text: "Motion tokens define consistent duration and curves. When Reduced Motion is active, durations collapse to instant."
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

            Rectangle {
                width: 140
                height: Geometry.controlHeightMedium
                radius: Geometry.radiusSmall
                color: Theme.accent

                Text {
                    anchors.centerIn: parent
                    text: "Trigger Motion"
                    font: Typography.controlLabel
                    color: Theme.accentText
                }

                TapHandler {
                    onTapped: root.moved = !root.moved
                }
            }

            Rectangle {
                width: 180
                height: Geometry.controlHeightMedium
                radius: Geometry.radiusSmall
                color: Appearance.reducedMotion ? Theme.destructive : Theme.surfaceSecondary
                border.color: Theme.separator

                Text {
                    anchors.centerIn: parent
                    text: Appearance.reducedMotion ? "Reduced Motion: ON" : "Reduced Motion: OFF"
                    font: Typography.controlLabel
                    color: Appearance.reducedMotion ? Theme.destructiveText : Theme.textPrimary
                }

                TapHandler {
                    onTapped: Appearance.reducedMotion = !Appearance.reducedMotion
                }
            }
        }

        ColumnLayout {
            spacing: Spacing.md
            Layout.fillWidth: true

            component MotionTrack: Item {
                property string label: ""
                property int durationToken: 0

                Layout.fillWidth: true
                height: 36

                RowLayout {
                    anchors.fill: parent
                    spacing: Spacing.md

                    Text {
                        text: label
                        font: Typography.caption
                        color: Theme.textPrimary
                        Layout.preferredWidth: 100
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 3
                        color: Theme.surfaceSecondary

                        Rectangle {
                            id: ball
                            width: 16
                            height: 16
                            radius: 8
                            y: -5
                            x: root.moved ? (parent.width - width) : 0
                            color: Theme.accent

                            Behavior on x {
                                NumberAnimation {
                                    duration: Motion.duration(durationToken)
                                    easing.type: Motion.easingStandard
                                }
                            }
                        }
                    }
                }
            }

            MotionTrack { label: "Fast (100ms)"; durationToken: Motion.fast }
            MotionTrack { label: "Normal (200ms)"; durationToken: Motion.normal }
            MotionTrack { label: "Slow (350ms)"; durationToken: Motion.slow }
        }

        Item { Layout.fillHeight: true }
    }
}
