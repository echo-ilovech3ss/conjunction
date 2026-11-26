import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import Conjunction.Design

T.Popup {
    id: control

    property string titleText: ""
    property string messageText: ""
    property string defaultButtonText: "Done"
    property string cancelButtonText: "Cancel"
    property Item invokerItem: null

    signal defaultTriggered()
    signal cancelTriggered()

    modal: true
    focus: true
    closePolicy: T.Popup.CloseOnEscape
    y: 0
    x: parent ? Math.round((parent.width - implicitWidth) / 2) : 0
    implicitWidth: 420
    implicitHeight: sheetLayout.implicitHeight + Spacing.lg * 2

    dim: true
    T.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.28) // SPEC §3.1 scrim 0 -> 0.28
    }

    // SPEC §3.1 Sheet Open 335 ms slide / Reduced Motion 180 ms fade; Close 333 ms
    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: Motion.duration(Motion.sheetOpen)
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "y"
                from: Appearance.reducedMotion ? 0 : -control.height * 0.35
                to: 0
                duration: Motion.spatialDuration(Motion.sheetOpen)
                easing.type: Motion.easingDecelerate
            }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: Motion.duration(Motion.sheetClose)
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "y"
                from: 0
                to: Appearance.reducedMotion ? 0 : -control.height * 0.35
                duration: Motion.spatialDuration(Motion.sheetClose)
                easing.type: Motion.easingAccelerate
            }
        }
    }

    background: Surface {
        elevation: "dialog"
        radius: Geometry.radiusSheet // 16 pt
    }

    contentItem: ColumnLayout {
        id: sheetLayout
        anchors.fill: parent
        anchors.margins: Spacing.lg
        anchors.bottomMargin: Spacing.md // 12 pt bottom margin concentric w/ cr=14 pills (SPEC §2.1)
        spacing: Spacing.md

        Text {
            text: control.titleText
            font: Typography.title2Bold
            color: Theme.textPrimary
            Layout.fillWidth: true
        }

        Text {
            text: control.messageText
            font: Typography.body
            color: Theme.textSecondary
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.fillWidth: true
            height: Geometry.separatorThickness
            color: Theme.separator
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Spacing.sm

            Item { Layout.fillWidth: true }

            Button {
                sizeClass: "pill" // 28 pt cr=14 (SPEC §2.1 & §2.3)
                text: control.cancelButtonText
                onClicked: {
                    control.cancelTriggered();
                    control.close();
                }
            }

            Button {
                id: sheetDefBtn
                sizeClass: "pill"
                text: control.defaultButtonText
                isDefault: true
                focus: true
                onClicked: {
                    control.defaultTriggered();
                    control.close();
                }
            }
        }
    }

    Keys.onEscapePressed: function(event) {
        control.cancelTriggered();
        control.close();
        event.accepted = true;
    }

    onOpened: sheetDefBtn.forceActiveFocus()
    onClosed: {
        if (invokerItem) invokerItem.forceActiveFocus();
    }
}
