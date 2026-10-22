import QtQuick
import qs.services

// The typed password as dots: one pops in after the last per character, growing from its
// centre, and shrinks back into it when deleted; while the password is checked a wave runs
// through them. Sized to its dots, so centre it in the pill. Shared by the lock screen and the
// polkit prompt.
Item {
    id: root

    // Characters typed.
    property int count: 0
    property bool checking: false
    property real dotSize: 12
    property color color: Theme.gold

    // Scene time, for the checking wave.
    property real t: 0

    implicitWidth: dotsView.contentWidth
    implicitHeight: dotSize * 3

    FrameAnimation {
        running: root.checking
        onTriggered: root.t += frameTime
    }

    ListModel {
        id: dots
    }

    // One model entry per typed character.
    function sync(): void {
        while (dots.count < count)
            dots.append({});
        while (dots.count > count)
            dots.remove(dots.count - 1);
    }

    onCountChanged: sync()
    Component.onCompleted: sync()

    ListView {
        id: dotsView

        anchors.centerIn: parent
        width: contentWidth
        height: root.height
        orientation: ListView.Horizontal
        interactive: false
        spacing: root.dotSize * 0.6
        model: dots

        delegate: Item {
            id: dot

            required property int index

            // Size used by the add and remove transitions.
            property real pop: 1

            width: root.dotSize
            height: dotsView.height

            Rectangle {
                width: root.dotSize
                height: root.dotSize
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: root.color
                scale: dot.pop

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.fast
                    }
                }

                transform: Translate {
                    // The checking wave: each dot hops a little after the one before.
                    y: -(root.checking ? Math.max(0, Math.sin(root.t * 7 - dot.index * 0.7)) * root.dotSize * 0.9 : 0)
                }
            }
        }

        // A new dot pops in from its centre, overshooting a little.
        add: Transition {
            NumberAnimation {
                property: "pop"
                from: 0
                to: 1
                duration: 320
                easing.type: Easing.OutBack
                easing.overshoot: 3
            }
        }

        // A deleted dot shrinks back into its centre.
        remove: Transition {
            NumberAnimation {
                property: "pop"
                to: 0
                duration: 180
                easing.type: Easing.InBack
                easing.overshoot: 2
            }
        }

        displaced: Transition {
            NumberAnimation {
                property: "x"
                duration: Theme.fast
                easing.type: Easing.OutCubic
            }
        }
    }
}
