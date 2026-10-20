import QtQuick
import qs.services

// Text that floats away and drifts back in when it changes, instead of snapping.
Item {
    id: root

    property string text
    property alias color: label.color
    property alias font: label.font
    property alias elide: label.elide
    property alias horizontalAlignment: label.horizontalAlignment
    property alias lineHeight: label.lineHeight
    // Direction the old text leaves in (-1 up, 1 down).
    property int direction: -1

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    clip: false

    Text {
        id: label

        width: root.width
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 13
        elide: Text.ElideRight
        text: root.text
    }

    onTextChanged: {
        if (label.text === "" || label.text === text) {
            label.text = text;
            return;
        }
        swap.restart();
    }

    SequentialAnimation {
        id: swap

        ParallelAnimation {
            NumberAnimation {
                target: label
                property: "anchors.verticalCenterOffset"
                to: 8 * root.direction
                duration: 130
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: label
                property: "opacity"
                to: 0
                duration: 130
            }
        }
        // A script rather than PropertyActions: their values are taken when the animation
        // was last started, which would show the text from one change before.
        ScriptAction {
            script: {
                label.text = root.text;
                label.anchors.verticalCenterOffset = -8 * root.direction;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: label
                property: "anchors.verticalCenterOffset"
                to: 0
                duration: 380
                easing.type: Easing.OutBack
                easing.overshoot: 2.2
            }
            NumberAnimation {
                target: label
                property: "opacity"
                to: 1
                duration: 240
            }
        }
    }
}
