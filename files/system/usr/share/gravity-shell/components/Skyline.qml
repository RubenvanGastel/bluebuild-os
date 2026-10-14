import QtQuick
import QtQuick.Shapes
import qs.services
import "Rng.js" as Rng

// Distant Hekseville silhouette with its clock tower, lit windows and a warm horizon.
Item {
    id: root

    required property GravityScene scene

    readonly property real unit: height / 220

    // Buildings as {x, w, h, roof}; the clock tower sits at ~68% of the width.
    readonly property var buildings: {
        const r = Rng.make(4242);
        const out = [];
        if (width <= 0 || height <= 0)
            return out;
        // Local copy: the `unit` property may not be evaluated yet when this runs.
        const unit = height / 220;
        const towerX = width * 0.68;
        let x = -10;
        while (x < width + 10) {
            const w = (26 + r() * 60) * unit;
            const nearTower = Math.abs(x + w / 2 - towerX) < 70 * unit;
            const h = (nearTower ? 0.45 : 0.18 + r() * 0.42) * height;
            out.push({ x: x, w: w, h: h, roof: r() < 0.35 ? "spire" : r() < 0.5 ? "gable" : "flat" });
            x += Math.max(4, w + r() * 6 * unit);
        }
        return out;
    }

    readonly property real towerX: width * 0.68
    readonly property real towerW: 34 * unit
    readonly property real towerH: height * 0.92

    readonly property var outline: {
        const pts = [Qt.point(0, height)];
        for (const b of buildings) {
            const top = height - b.h;
            pts.push(Qt.point(b.x, height));
            pts.push(Qt.point(b.x, top));
            if (b.roof === "spire") {
                pts.push(Qt.point(b.x + b.w * 0.42, top));
                pts.push(Qt.point(b.x + b.w * 0.5, top - b.w * 0.9));
                pts.push(Qt.point(b.x + b.w * 0.58, top));
            } else if (b.roof === "gable") {
                pts.push(Qt.point(b.x + b.w * 0.5, top - b.w * 0.35));
            }
            pts.push(Qt.point(b.x + b.w, top));
            pts.push(Qt.point(b.x + b.w, height));
        }
        pts.push(Qt.point(width, height));
        pts.push(Qt.point(0, height));
        return pts;
    }

    readonly property var lights: {
        const r = Rng.make(777);
        const out = [];
        const unit = height / 220;
        if (unit <= 0)
            return out;
        for (const b of buildings) {
            const n = Math.min(12, Math.floor(b.h / (18 * unit) * (0.4 + r())));
            for (let i = 0; i < n; i++)
                out.push({ x: b.x + 4 * unit + r() * (b.w - 10 * unit), y: height - b.h + 8 * unit + r() * (b.h - 12 * unit), tw: r() < 0.25 ? 0.5 + r() * 2 : 0, phase: r() * 6.28 });
        }
        return out;
    }

    transform: Translate {
        x: root.scene.g.x * root.scene.height * 0.012
        y: root.scene.g.y * root.scene.height * 0.012
    }

    // Warm glow rising from behind the city.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.25
        height: parent.height * 1.6
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 0.7
                color: Qt.rgba(Theme.horizon.r, Theme.horizon.g, Theme.horizon.b, 0.22)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(Theme.amber.r, Theme.amber.g, Theme.amber.b, 0.38)
            }
        }
    }

    // Straight edges only; the curve renderer chokes on this many collinear points.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.GeometryRenderer
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: root.height
                GradientStop {
                    position: 0
                    color: "#2c1f52"
                }
                GradientStop {
                    position: 1
                    color: Theme.night
                }
            }
            PathPolyline {
                path: root.outline
            }
        }

        // Clock tower.
        ShapePath {
            strokeColor: "transparent"
            fillColor: "#24183f"
            PathPolyline {
                readonly property real l: root.towerX - root.towerW / 2
                readonly property real r: root.towerX + root.towerW / 2
                readonly property real top: root.height - root.towerH
                path: [Qt.point(l, root.height), Qt.point(l, top + root.towerW), Qt.point(l - 4 * root.unit, top + root.towerW), Qt.point(root.towerX, top - root.towerW * 1.2), Qt.point(r + 4 * root.unit, top + root.towerW), Qt.point(r, top + root.towerW), Qt.point(r, root.height), Qt.point(l, root.height)]
            }
        }
    }

    // The clock face.
    GlowBlob {
        x: root.towerX - width / 2
        y: root.height - root.towerH + root.towerW * 1.5 - height / 2
        width: root.towerW * 2.4
        height: width
        color: Theme.gold
        strength: 0.45
    }
    Rectangle {
        x: root.towerX - width / 2
        y: root.height - root.towerH + root.towerW * 1.5 - height / 2
        width: root.towerW * 0.62
        height: width
        radius: width / 2
        color: Theme.cream
        border.color: Theme.gold
        border.width: Math.max(1, root.unit * 1.5)
    }

    Repeater {
        model: root.lights

        Rectangle {
            required property var modelData

            x: modelData.x
            y: modelData.y
            width: Math.max(1.5, 3 * root.unit)
            height: Math.max(2, 4 * root.unit)
            color: Theme.gold
            opacity: modelData.tw > 0 ? 0.35 + 0.45 * (0.5 + 0.5 * Math.sin(root.scene.t * modelData.tw + modelData.phase)) : 0.6
        }
    }
}
