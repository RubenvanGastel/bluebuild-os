import QtQuick
import qs.services

// The typed password as Material 3 Expressive shapes: each character pops in as a random
// shape from the shape library, spinning into place on the fast spatial spring; a deleted one
// springs away. While the password is checked they wobble in a wave; a wrong one turns them
// to the error colour, shakes the row and drops them one after another (call fail() before
// `count` goes to 0); the right one turns them to `grantedColor` with a last pop.
// Shared by the lock screen and the polkit prompt.
Item {
    id: root

    // Characters typed.
    property int count: 0
    property bool checking: false
    property bool granted: false
    property real shapeSize: 18
    property real spacing: shapeSize * 0.45
    property color color: Theme.gold
    property color grantedColor: Theme.goldInk

    // True from fail() until the shapes have dropped.
    property bool failing: false

    // Shapes on screen: {uid, shape, alive}. Gone ones stay until they have sprung away.
    ListModel {
        id: shapes
    }
    property int nextUid: 0
    property string lastShape: ""
    // Slot of each live shape by uid, and how many there are.
    property var slots: ({})
    property int alive: 0

    // Room per shape: they close up when the row would be wider than the item.
    readonly property real step: alive > 1 ? Math.min(shapeSize + spacing, (width - shapeSize) / (alive - 1)) : shapeSize + spacing
    readonly property real rowWidth: alive > 0 ? shapeSize + (alive - 1) * step : 0

    function fail(): void {
        failing = true;
        shake.kick(-700);
        for (let i = 0; i < shapes.count; i++)
            shapes.setProperty(i, "alive", false);
        relayout();
    }

    function pickShape(): string {
        // Any shape but the last one, so two in a row always differ.
        let s;
        do
            s = Shapes.names[Math.floor(Math.random() * Shapes.names.length)];
        while (s === lastShape && Shapes.names.length > 1);
        lastShape = s;
        return s;
    }

    function sync(): void {
        let live = 0;
        for (let i = 0; i < shapes.count; i++)
            if (shapes.get(i).alive)
                live++;
        while (live < count) {
            shapes.append({ uid: nextUid++, shape: pickShape(), alive: true });
            live++;
        }
        for (let i = shapes.count - 1; i >= 0 && live > count; i--) {
            if (shapes.get(i).alive) {
                shapes.setProperty(i, "alive", false);
                live--;
            }
        }
        relayout();
    }

    function relayout(): void {
        const s = {};
        let n = 0;
        for (let i = 0; i < shapes.count; i++) {
            const e = shapes.get(i);
            if (e.alive)
                s[e.uid] = n++;
        }
        slots = s;
        alive = n;
    }

    function remove(uid: int): void {
        for (let i = 0; i < shapes.count; i++) {
            if (shapes.get(i).uid === uid) {
                shapes.remove(i);
                break;
            }
        }
        let anyGone = false;
        for (let i = 0; i < shapes.count; i++)
            anyGone = anyGone || !shapes.get(i).alive;
        if (!anyGone)
            failing = false;
    }

    // After the current event: a failed check clears the text and then calls fail(), and
    // the shapes should fall as a failure, not as deletes.
    onCountChanged: Qt.callLater(sync)

    // A wrong password: a push that springs back with a few wobbles.
    Spring {
        id: shake

        damping: 0.25
        stiffness: 900
        threshold: 0.2
    }

    // Scene time for the checking wave.
    property real t: 0

    FrameAnimation {
        running: root.checking
        onTriggered: root.t += frameTime
    }

    // Keeps the row centred as it grows and shrinks; not while shapes are dropping, so they
    // fall straight down.
    Spring {
        id: centre

        spec: "fastSpatial"
    }

    function recentre(): void {
        if (!failing)
            centre.to = (width - rowWidth) / 2;
    }

    onRowWidthChanged: recentre()
    onWidthChanged: recentre()
    onFailingChanged: recentre()
    Component.onCompleted: centre.snap((width - rowWidth) / 2)

    Item {
        id: row

        x: centre.value + shake.value
        width: root.rowWidth
        height: root.height

        Repeater {
            model: shapes

            Item {
                id: cell

                required property int uid
                required property string shape
                required property bool alive
                required property int index

                readonly property int slot: root.slots[uid] ?? -1
                // Where it sits in the row; a gone shape stays where it was.
                readonly property real home: slot >= 0 ? slot * root.step : -1

                onHomeChanged: if (home >= 0)
                    place.to = home

                width: root.shapeSize
                height: root.shapeSize
                x: place.value
                y: (root.height - height) / 2 + fall.value

                Spring {
                    id: place

                    spec: "fastSpatial"
                }

                // 0 -> 1 popping in, back to 0 springing away.
                Spring {
                    id: pop

                    spec: "fastSpatial"
                    to: 0
                    onSettled: if (!cell.alive && to === 0)
                        root.remove(cell.uid)
                }

                // Turns into place from a random angle; turns on as it leaves.
                Spring {
                    id: turn

                    spec: "fastSpatial"
                }

                // A wrong password drops it: falling, and fading.
                Spring {
                    id: fall

                    spec: "defaultSpatial"
                }

                Timer {
                    id: dropDelay

                    // One after another, from the first.
                    interval: 160 + cell.index * 35
                    onTriggered: {
                        fall.to = root.shapeSize * 2.5;
                        pop.to = 0;
                        turn.to = turn.value + (Math.random() < 0.5 ? -90 : 90);
                    }
                }

                Component.onCompleted: {
                    place.snap(Math.max(0, home));
                    turn.snap((Math.random() < 0.5 ? -1 : 1) * (60 + Math.random() * 60));
                    turn.to = 0;
                    pop.snap(0);
                    pop.to = 1;
                }

                onAliveChanged: if (!alive) {
                    if (root.failing) {
                        dropDelay.start();
                    } else {
                        pop.to = 0;
                        turn.to = turn.value + 45;
                    }
                }

                // The right password: one last pop.
                Connections {
                    target: root

                    function onGrantedChanged(): void {
                        if (root.granted)
                            pop.kick(6);
                    }
                }

                MaterialShape {
                    anchors.fill: parent
                    shape: cell.shape
                    color: root.failing ? Theme.rose : root.granted ? root.grantedColor : root.color
                    rotation: turn.value
                    // The checking wave: each shape swells a little after the one before.
                    scale: Math.max(0, pop.value) * (root.checking ? 1 - 0.3 * Math.max(0, Math.sin(root.t * 6 - cell.slot * 0.6)) : 1)
                    opacity: Math.min(1, Math.max(0, pop.value) * 2)

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.fast
                        }
                    }
                }
            }
        }
    }
}
