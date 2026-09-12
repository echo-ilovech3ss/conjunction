import QtQuick
import QtQuick.Templates as T
import Conjunction.Design

T.ProgressBar {
    id: control

    implicitWidth: 200
    implicitHeight: 4

    Accessible.role: Accessible.ProgressBar
    Accessible.name: "Progress"

    background: Rectangle {
        implicitWidth: control.implicitWidth
        implicitHeight: control.implicitHeight
        radius: 2
        color: Theme.surfaceSecondary
    }

    contentItem: Item {
        implicitWidth: control.implicitWidth
        implicitHeight: control.implicitHeight

        Rectangle {
            id: fillBar
            visible: !control.indeterminate
            width: control.position * parent.width
            height: parent.height
            radius: 2
            color: Theme.accent
        }

        Rectangle {
            id: indeterminateBar
            visible: control.indeterminate
            width: parent.width * 0.3
            height: parent.height
            radius: 2
            color: Theme.accent

            SequentialAnimation on x {
                running: control.indeterminate && !Appearance.reducedMotion
                loops: Animation.Infinite
                NumberAnimation {
                    from: 0
                    to: control.width - indeterminateBar.width
                    duration: 1000
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    from: control.width - indeterminateBar.width
                    to: 0
                    duration: 1000
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }
}
