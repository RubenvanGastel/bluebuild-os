import QtQuick
import qs.services
import "Rng.js" as Rng

// Dusty's star dust: tiny motes drifting upward, as if gravity were slightly reversed.
Item {
    id: root

    required property GravityScene scene
    property int count: Config.starCount

    Repeater {
        model: root.count

        Rectangle {
            id: star

            required property int index

            readonly property var p: {
                const r = Rng.make(index * 104729 + 7);
                const tone = r();
                return {
                    bx: r(),
                    by: r(),
                    size: 1 + Math.pow(r(), 3) * 3,
                    speed: 4 + r() * 14,
                    sway: 4 + r() * 10,
                    tw: 0.6 + r() * 2.2,
                    phase: r() * Math.PI * 2,
                    depth: 0.2 + r() * 0.6,
                    color: tone < 0.6 ? Theme.cream : tone < 0.85 ? Theme.glow : Theme.gold
                };
            }

            readonly property real t: root.scene.t
            readonly property real span: root.height + 20

            width: p.size
            height: p.size
            radius: p.size / 2
            color: p.color
            x: p.bx * root.width + Math.sin(t * 0.3 + p.phase) * p.sway + root.scene.g.x * root.height * 0.08 * p.depth
            y: ((p.by * span - t * p.speed) % span + span) % span - 10 + root.scene.g.y * root.height * 0.08 * p.depth
            opacity: (0.35 + 0.65 * (0.5 + 0.5 * Math.sin(t * p.tw + p.phase))) * (1 - root.scene.rise * 0.8)
        }
    }
}
