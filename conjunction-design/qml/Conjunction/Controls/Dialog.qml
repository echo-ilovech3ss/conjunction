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
        elevation: "dialog"
        radius: Geometry.radiusSheet // 16 pt
        implicitWidth: 380
        implicitHeight: dialogLayout.implicitHeight + Spacing.lg + Spacing.md

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
