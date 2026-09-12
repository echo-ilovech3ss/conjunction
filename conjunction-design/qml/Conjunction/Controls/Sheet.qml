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
        color: "#40000000"
    }

    enter: Transition {
        NumberAnimation {
            property: "y"
            from: -control.height
            to: 0
            duration: Motion.duration(Motion.normal)
            easing.type: Motion.easingDecelerate
        }
    }

    exit: Transition {
        NumberAnimation {
            property: "y"
            from: 0
            to: -control.height
            duration: Motion.duration(Motion.fast)
            easing.type: Motion.easingAccelerate
        }
    }

    background: Surface {
        elevation: "dialog"
        radius: Geometry.radiusLarge
    }

    contentItem: ColumnLayout {
        id: sheetLayout
        anchors.fill: parent
        anchors.margins: Spacing.lg
        spacing: Spacing.md

        Text {
            text: control.titleText
            font: Typography.windowTitle
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
                text: control.cancelButtonText
                onClicked: {
                    control.cancelTriggered();
                    control.close();
                }
            }

            Button {
                id: sheetDefBtn
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

    onOpened: {
        sheetDefBtn.forceActiveFocus();
    }

    onClosed: {
        if (invokerItem) invokerItem.forceActiveFocus();
    }
}
