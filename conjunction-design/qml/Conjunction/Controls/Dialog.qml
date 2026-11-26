import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import Conjunction.Design

T.Dialog {
    id: control

    property string titleText: ""
    property string messageText: ""
    property string defaultButtonText: "OK"
    property string cancelButtonText: "Cancel"
    property bool isDestructive: false
    property Item invokerItem: null

    signal defaultTriggered()
    signal cancelTriggered()

    modal: true
    focus: true
    anchors.centerIn: parent
    margins: 12
    closePolicy: T.Popup.CloseOnEscape

    background: Rectangle {
        color: "transparent"
    }

    dim: true
    T.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.28)
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: Motion.duration(Motion.popoverOpen) }
            NumberAnimation { property: "scale"; from: Appearance.reducedMotion ? 1.0 : 0.94; to: 1.0; duration: Motion.spatialDuration(Motion.popoverOpen); easing.type: Easing.OutCubic }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: Motion.duration(Motion.popoverClose) }
            NumberAnimation { property: "scale"; from: 1.0; to: Appearance.reducedMotion ? 1.0 : 0.94; duration: Motion.spatialDuration(Motion.popoverClose); easing.type: Easing.OutCubic }
        }
    }

    contentItem: Surface {
        readonly property real maxWinW: control.T.Overlay.overlay ? Math.max(260, control.T.Overlay.overlay.width - 32) : 420
        readonly property real maxWinH: control.T.Overlay.overlay ? Math.max(180, control.T.Overlay.overlay.height - 32) : 600
        elevation: "dialog"
        radius: Geometry.radiusSheet // 16 pt
        implicitWidth: Math.min(380, maxWinW)
        implicitHeight: Math.min(dialogLayout.implicitHeight + Spacing.lg + Spacing.md, maxWinH)

        ColumnLayout {
            id: dialogLayout
            anchors.fill: parent
            anchors.topMargin: Spacing.lg
            anchors.leftMargin: Spacing.lg
            anchors.rightMargin: Spacing.lg
            anchors.bottomMargin: Spacing.md
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
                Layout.preferredHeight: msgText.implicitHeight
                Layout.maximumHeight: Math.max(48, (control.T.Overlay.overlay ? control.T.Overlay.overlay.height : 600) - 200)
                contentWidth: width
                contentHeight: msgText.implicitHeight
                clip: true
                T.ScrollBar.vertical: ScrollBar {}

                Text {
                    id: msgText
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
                    sizeClass: "pill" // 28 pt cr=14
                    text: control.cancelButtonText
                    onClicked: {
                        control.cancelTriggered();
                        control.close();
                    }
                }

                Button {
                    id: defBtn
                    sizeClass: "pill"
                    text: control.defaultButtonText
                    isDefault: !control.isDestructive
                    isDestructive: control.isDestructive
                    focus: true
                    onClicked: {
                        control.defaultTriggered();
                        control.close();
                    }
                }
            }
        }
    }

    Keys.onEscapePressed: function(event) {
        control.cancelTriggered();
        control.close();
        event.accepted = true;
    }

    onOpened: defBtn.forceActiveFocus()
    onClosed: {
        if (invokerItem) invokerItem.forceActiveFocus();
    }
}
