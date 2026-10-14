import QtQuick
import QtQuick.Shapes
import qs.services
import "Rng.js" as Rng

// One floating chunk of the city: a rock island (maybe with a house or a street lamp),
// a crate, or a gravity gem. Its whole shape and motion come from `seed`.
Item {
    id: root

    required property int seed
    // 0.3 = far away (small, faded, slow) .. 1.2 = close (big, vivid, reacts strongly)
    required property real depth
    required property GravityScene scene

    // Everything random is rolled once here.
    readonly property var p: {
        const r = Rng.make(seed * 7919 + 13);
        const roll = r();
        const kind = roll < 0.48 ? "rock" : roll < 0.68 ? "house" : roll < 0.8 ? "lamp" : roll < 0.9 ? "crate" : "gem";

        // Floating island outline in unit space: flat-ish top, jagged taper to a tip below.
        const pts = [];
        const n = 5;
        for (let i = 0; i < n; i++)
            pts.push([-1 + 2 * i / (n - 1), -0.25 + (r() - 0.5) * 0.12]);
        pts.push([0.86, 0.05 + r() * 0.1]);
        pts.push([0.55, 0.38 + r() * 0.15]);
        pts.push([0.08 + (r() - 0.5) * 0.35, 0.95 + r() * 0.2]);
        pts.push([-0.42, 0.42 + r() * 0.15]);
        pts.push([-0.82, 0.08 + r() * 0.1]);

        return {
            kind: kind,
            bx: 0.04 + r() * 0.92,
            by: 0.08 + r() * 0.62,
            size: kind === "crate" ? 30 + r() * 22 : kind === "gem" ? 34 + r() * 22 : 55 + r() * 90,
            fx: 0.10 + r() * 0.18,
            fy: 0.16 + r() * 0.22,
            fr: 0.07 + r() * 0.12,
            phase: r() * Math.PI * 2,
            ampX: 6 + r() * 14,
            ampY: 10 + r() * 18,
            rot0: (r() - 0.5) * (kind === "crate" ? 60 : 14),
            rotAmp: kind === "crate" || kind === "gem" ? 10 + r() * 14 : 2 + r() * 4,
            tumble: kind === "crate" ? (r() - 0.5) * 9 : 0,
            spin: (r() - 0.5) * 2,
            drift: (r() - 0.5) * 6,
            delay: r(),
            houseX: -0.3 + r() * 0.4,
            pts: pts
        };
    }

    readonly property real unit: scene.height / 1080
    readonly property real fog: Rng.clamp(1.15 - depth, 0, 0.75)
    readonly property real reach: scene.height * 0.16 * depth

    width: p.size * depth * unit * 2
    height: width * 0.75

    // --- motion ---------------------------------------------------------------------
    readonly property real t: scene.t
    readonly property real rise: {
        const lp = Rng.clamp(scene.intro * 1.6 - p.delay * 0.6, 0, 1);
        return Math.pow(1 - lp, 3);
    }

    x: {
        const span = scene.width + width * 2;
        const base = p.bx * scene.width + t * p.drift * depth;
        const wrapped = ((base + width) % span + span) % span - width;
        return wrapped - width / 2 + Math.sin(t * p.fx + p.phase) * p.ampX * unit + scene.g.x * reach;
    }
    y: p.by * scene.height - height / 2 + Math.sin(t * p.fy + p.phase * 1.3) * p.ampY * unit + scene.g.y * reach + rise * scene.height * (0.7 + 0.4 * depth)
    rotation: p.rot0 + Math.sin(t * p.fr + p.phase) * p.rotAmp + t * p.tumble + scene.g.x * 16 * p.spin - scene.g.y * 6 * p.spin
    opacity: 1 - rise

    // --- colours (far things melt into the dusk haze) ------------------------------------
    function fogged(c: color): color {
        return Rng.mix(c, Theme.dusk, root.fog);
    }

    readonly property color stoneTop: fogged("#c99a7c")
    readonly property color stoneMid: fogged("#6c4a72")
    readonly property color stoneBottom: fogged("#21173f")
    readonly property color rim: Qt.rgba(Theme.gold.r, Theme.gold.g, Theme.gold.b, 0.85 - fog)

    function toLocal(pt: var): point {
        return Qt.point((pt[0] + 1) / 2 * width, (pt[1] + 0.35) / 1.55 * height);
    }

    // --- island (rock / house / lamp) ----------------------------------------------------
    Shape {
        id: island

        visible: root.p.kind === "rock" || root.p.kind === "house" || root.p.kind === "lamp"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: root.height

                GradientStop {
                    position: 0.0
                    color: root.stoneTop
                }
                GradientStop {
                    position: 0.35
                    color: root.stoneMid
                }
                GradientStop {
                    position: 1.0
                    color: root.stoneBottom
                }
            }

            PathPolyline {
                path: [...root.p.pts, root.p.pts[0]].map(pt => root.toLocal(pt))
            }
        }

        // Lighter top stratum, so the island reads as a slab of rock rather than a triangle.
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.fogged("#a77a78")
            PathPolyline {
                path: {
                    const top = root.p.pts.slice(0, 5);
                    const band = top.map(pt => [pt[0] * 0.94, pt[1] + 0.16]).reverse();
                    return [...top, ...band, top[0]].map(pt => root.toLocal(pt));
                }
            }
        }

        // Lamplight catching the top edge.
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.rim
            strokeWidth: Math.max(1, 1.6 * root.depth)
            capStyle: ShapePath.RoundCap

            PathPolyline {
                path: root.p.pts.slice(0, 5).map(pt => root.toLocal(pt))
            }
        }
    }

    // A little Hekseville house sitting on the island.
    Item {
        id: house

        visible: root.p.kind === "house"
        readonly property real w: root.width * 0.42
        width: w
        height: w * 1.15
        x: root.width * (0.5 + root.p.houseX * 0.5) - w / 2
        y: root.toLocal([0, -0.25]).y - height + 2

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "transparent"
                fillColor: root.fogged("#3a2a55")
                PathPolyline {
                    path: [Qt.point(0, house.height * 0.42), Qt.point(house.width * 0.5, 0), Qt.point(house.width, house.height * 0.42), Qt.point(house.width * 0.92, house.height * 0.42), Qt.point(house.width * 0.92, house.height), Qt.point(house.width * 0.08, house.height), Qt.point(house.width * 0.08, house.height * 0.42), Qt.point(0, house.height * 0.42)]
                }
            }
        }

        Rectangle {
            x: parent.width * 0.38
            y: parent.height * 0.55
            width: parent.width * 0.24
            height: parent.height * 0.22
            radius: 1
            color: Theme.gold
            opacity: (0.75 + 0.25 * Math.sin(root.t * 1.7 + root.p.phase)) * (1 - root.fog)
        }
    }

    // A street lamp leaning out of the rock.
    Item {
        visible: root.p.kind === "lamp"
        readonly property real h: root.height * 0.75
        width: 4
        height: h
        x: root.width * (0.5 + root.p.houseX * 0.5)
        y: root.toLocal([0, -0.25]).y - h + 2

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: Math.max(1.5, 2.2 * root.depth)
            height: parent.h
            color: root.fogged("#2b1f40")
        }

        GlowBlob {
            anchors.horizontalCenter: parent.horizontalCenter
            y: -height / 2
            width: root.height * 0.55
            height: width
            color: Theme.gold
            strength: 0.65
            // Pulse via opacity: changing the gradient itself would rebuild the shape each frame.
            opacity: (0.75 + 0.25 * Math.sin(root.t * 2.3 + root.p.phase)) * (1 - root.fog)
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: -height / 2
            width: Math.max(3, 6 * root.depth)
            height: width
            radius: width / 2
            color: Theme.cream
        }
    }

    // A tumbling wooden crate.
    Rectangle {
        visible: root.p.kind === "crate"
        anchors.centerIn: parent
        width: root.width * 0.55
        height: width
        radius: 2
        color: root.fogged("#8a5a3c")
        border.color: root.fogged("#4a2c22")
        border.width: Math.max(1, width * 0.08)

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 1.2
            height: parent.border.width
            rotation: 45
            color: parent.border.color
        }
    }

    // Kat's precious gems: violet, glowing, slowly turning.
    Item {
        visible: root.p.kind === "gem"
        anchors.fill: parent

        GlowBlob {
            anchors.centerIn: parent
            width: parent.width * 1.6
            height: width
            color: Theme.nebula
            strength: 0.6
            opacity: (0.7 + 0.3 * Math.sin(root.t * 1.3 + root.p.phase)) * (1 - root.fog * 0.8)
        }

        Shape {
            anchors.centerIn: parent
            width: parent.width * 0.45
            height: width * 1.5
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Qt.rgba(1, 1, 1, 0.5 * (1 - root.fog))
                strokeWidth: 1
                fillGradient: LinearGradient {
                    x1: 0
                    y1: 0
                    x2: root.width * 0.45
                    y2: root.width * 0.67

                    GradientStop {
                        position: 0
                        color: root.fogged(Theme.glow)
                    }
                    GradientStop {
                        position: 1
                        color: root.fogged("#4b2fb8")
                    }
                }
                PathPolyline {
                    readonly property real w: root.width * 0.45
                    readonly property real h: w * 1.5
                    path: [Qt.point(w / 2, 0), Qt.point(w, h * 0.35), Qt.point(w / 2, h), Qt.point(0, h * 0.35), Qt.point(w / 2, 0)]
                }
            }
        }
    }
}
