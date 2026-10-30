import QtQuick
import qs.services

// A few bars of cava's spectrum, low notes first, each growing out both ways from the
// middle (sideways along a side). Accent-coloured while playing, dim and flat when paused.
// Config.visualizerStyle draws them as bars, as one smooth wave mirrored about the middle,
// or as columns of dots that light up from the middle out.
Item {
    id: root

    property bool vertical: false
    property int count: 10
    readonly property var levels: Cava.grouped(count)
    readonly property string style: Config.visualizerStyle
    property color color: Playback.playing ? Theme.gold : Theme.textDim

    // Along the bar, and across it.
    readonly property real length: count * 3 + (count - 1) * 2
    readonly property real depth: 18

    implicitWidth: vertical ? depth : length
    implicitHeight: vertical ? length : depth

    Behavior on color {
        ColorAnimation {
            duration: Theme.normal
        }
    }

    function level(i: int): real {
        return Math.max(0.12, Math.min(1, levels[i] ?? 0));
    }

    Grid {
        visible: root.style === "bars"
        columns: root.vertical ? 1 : root.count
        spacing: 2

        Repeater {
            model: root.count

            // A slot the full height (width along a side), the bar centred in it.
            Item {
                required property int index
                readonly property real level: root.level(index)

                width: root.vertical ? 18 : 3
                height: root.vertical ? 3 : 18

                Rectangle {
                    anchors.centerIn: parent
                    width: root.vertical ? 18 * parent.level : 3
                    height: root.vertical ? 3 : 18 * parent.level
                    radius: 1.5
                    color: root.color
                }
            }
        }
    }

    Canvas {
        id: canvas

        visible: root.style !== "bars"
        anchors.fill: parent

        Connections {
            target: root

            function onLevelsChanged(): void {
                if (canvas.visible)
                    canvas.requestPaint();
            }

            function onColorChanged(): void {
                canvas.requestPaint();
            }

            function onStyleChanged(): void {
                canvas.requestPaint();
            }

            function onVerticalChanged(): void {
                canvas.requestPaint();
            }
        }

        // Drawn as if horizontal; along a side the canvas is turned so the low notes
        // stay first, at the top.
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (root.vertical) {
                ctx.translate(width, 0);
                ctx.rotate(Math.PI / 2);
            }
            ctx.fillStyle = root.color;
            const mid = root.depth / 2;
            const centre = i => i * 5 + 1.5;
            if (root.style === "wave") {
                // Through the top of each bar with curves between the midpoints, then back
                // the same way mirrored below the middle.
                const through = points => {
                    ctx.lineTo(points[0][0], points[0][1]);
                    for (let i = 0; i < points.length - 1; i++)
                        ctx.quadraticCurveTo(points[i][0], points[i][1], (points[i][0] + points[i + 1][0]) / 2, (points[i][1] + points[i + 1][1]) / 2);
                    ctx.lineTo(points[points.length - 1][0], points[points.length - 1][1]);
                };
                const top = [];
                for (let i = 0; i < root.count; i++)
                    top.push([centre(i), mid - root.level(i) * mid]);
                ctx.beginPath();
                ctx.moveTo(0, mid);
                through(top);
                ctx.lineTo(root.length, mid);
                through(top.reverse().map(p => [p[0], 2 * mid - p[1]]));
                ctx.closePath();
                ctx.fill();
            } else {
                // Five dots a column: one, three or all five lit from the middle out, the
                // rest faint.
                const dots = 5;
                const step = root.depth / dots;
                for (let i = 0; i < root.count; i++) {
                    const lit = 1 + 2 * Math.round((root.level(i) - 0.12) / 0.88 * 2);
                    for (let d = 0; d < dots; d++) {
                        ctx.globalAlpha = Math.abs(d - 2) * 2 < lit ? 1 : 0.25;
                        ctx.beginPath();
                        ctx.arc(centre(i), step * (d + 0.5), 1.5, 0, 2 * Math.PI);
                        ctx.fill();
                    }
                }
            }
        }
    }
}
