import QtQuick
import Conjunction.Design

Dialog {
    id: root

    property string alertType: "info"

    isDestructive: alertType === "destructive"
    defaultButtonText: alertType === "destructive" ? "Delete" : "OK"
}
