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

    readonly property real maxWinW: control.T.Overlay.overlay ? Math.max(260, control.T.Overlay.overlay.width - 32) : 420
    readonly property real maxWinH: control.T.Overlay.overlay ? Math.max(180, control.T.Overlay.overlay.height - 32) : 600

    modal: true
    focus: true
    closePolicy: T.Popup.CloseOnEscape
    margins: 12
    y: 0
    x: parent ? Math.round((parent.width - width) / 2) : 0
    implicitWidth: Math.min(420, maxWinW)
    implicitHeight: Math.min(sheetLayout.implicitHeight + Spacing.lg * 2, maxWinH)

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
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: sheetMsgText.implicitHeight
            Layout.maximumHeight: Math.max(48, control.maxWinH - 160)
            contentWidth: width
            contentHeight: sheetMsgText.implicitHeight
            clip: true
            T.ScrollBar.vertical: ScrollBar {}

            Text {
                id: sheetMsgText
                width: parent.width
                text: control.messageText
                font: Typography.body
                color: Theme.textSecondary
                wrapMode: Text.Wrap
            }
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
