import QtQuick
import QtQuick.Shapes
import qs.services

// Material 3 Expressive's loading indicator: a shape that morphs into the next one every
// 650 ms (soft burst, 9-sided cookie, pentagon, pill, sunny, 4-sided cookie, oval) on a bouncy
// spring, turning a quarter more with each morph while the whole turns once every 4.666 s.
// As LoadingIndicator in compose material3; `size` is the container (48 in the spec), the
// shape takes 38/48 of it.
Item {
    id: root

    property real size: 48
    property color color: Theme.gold
    property bool running: visible

    implicitWidth: size
    implicitHeight: size

    // Which morph (from shape `index` to the next), how far along, and the turns.
    property int index: 0
    property real targetAngle: 90
    property real globalAngle: 0
    // Every point of the outline, rebuilt each frame.
    property var points: []

    // Keeps the shapes inside the container as they turn: the farthest any of them reaches
    // from the centre decides (Compose's calculateScaleFactor).
    readonly property real reach: Math.max(...Shapes.loader.map(r => Math.max(...r)))
    // Pixels per unit of the shapes' own square.
    readonly property real unit: size * 38 / 48 / (2 * reach)

    Spring {
        id: morph

        // spring(dampingRatio = 0.6, stiffness = 200, visibilityThreshold = 0.1)
        damping: 0.6
        stiffness: 200
        threshold: 0.1
        onSettled: {
            root.index = (root.index + 1) % Shapes.loader.length;
            morph.snap(0);
            root.targetAngle = (root.targetAngle + 90) % 360;
        }
    }

    Timer {
        interval: 650
        repeat: true
        triggeredOnStart: true
        running: root.running
        onTriggered: morph.to = 1
    }

    FrameAnimation {
        running: root.running
        onTriggered: {
            root.globalAngle = (root.globalAngle + frameTime * 360 / 4.666) % 360;
            root.update();
        }
    }

    function update(): void {
        const a = Shapes.loader[index];
        const b = Shapes.loader[(index + 1) % Shapes.loader.length];
        // The spring overshoots past 1: mixing the shapes that far exaggerates the next one
        // for a moment, which is the bounce.
        const t = morph.value;
        const turn = (t * 90 + targetAngle + globalAngle) * Math.PI / 180;
        const n = a.length;
        const c = size / 2;
        const out = [];
        for (let i = 0; i <= n; i++) {
            const k = i % n;
            const r = (a[k] + (b[k] - a[k]) * t) * unit;
            const angle = 2 * Math.PI * k / n + turn;
            out.push(Qt.point(c + r * Math.cos(angle), c + r * Math.sin(angle)));
        }
        points = out;
    }

    Component.onCompleted: update()

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.color
            strokeWidth: -1

            PathPolyline {
                path: root.points
            }
        }
    }
}
