import QtQuick

// A value pulled towards `to` by a spring, as Material 3 Expressive moves things (Compose's
// spring(): mass 1, a damping ratio and a stiffness). Changing `to` midway keeps the current
// speed, so motion never restarts from a standstill. `spec` picks one of M3 Expressive's
// motion tokens; `damping` and `stiffness` can also be set directly.
//   Spring { id: s; spec: "fastSpatial"; to: shown ? 1 : 0 }   ...   scale: s.value
FrameAnimation {
    id: root

    property real to: 0
    property real value: 0
    property real velocity: 0

    // ExpressiveMotionTokens: spatial springs move and resize things, and may overshoot;
    // effects springs (colour, opacity) don't.
    readonly property var specs: ({
            fastSpatial: [0.6, 800],
            defaultSpatial: [0.8, 380],
            slowSpatial: [0.8, 200],
            fastEffects: [1.0, 3800],
            defaultEffects: [1.0, 1600],
            slowEffects: [1.0, 800]
        })
    property string spec: "defaultSpatial"
    property real damping: specs[spec][0]
    property real stiffness: specs[spec][1]
    // At rest once this close and this slow (per second).
    property real threshold: 0.001

    signal settled

    // Jumps there without moving.
    function snap(v: real): void {
        to = v;
        value = v;
        velocity = 0;
        running = false;
    }

    // A push: the value flies off at this speed and springs back to `to`.
    function kick(v: real): void {
        velocity += v;
        running = true;
    }

    Component.onCompleted: value = to
    onToChanged: running = true

    onTriggered: {
        // Small steps keep a stiff spring stable at any frame rate.
        const steps = Math.max(1, Math.ceil(frameTime / 0.004));
        const dt = Math.min(frameTime, 0.1) / steps;
        const c = 2 * damping * Math.sqrt(stiffness);
        let x = value, v = velocity;
        for (let i = 0; i < steps; i++) {
            v += (-stiffness * (x - to) - c * v) * dt;
            x += v * dt;
        }
        if (Math.abs(x - to) < threshold && Math.abs(v) < threshold * 10) {
            value = to;
            velocity = 0;
            running = false;
            settled();
        } else {
            value = x;
            velocity = v;
        }
    }
}
