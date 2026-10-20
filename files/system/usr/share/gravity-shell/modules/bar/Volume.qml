import QtQuick
import QtQuick.Shapes
import Quickshell.Services.Pipewire
import qs.services

// Speaker glyph + level (under it, along a side). The status pill around it scrolls the
// volume (setVolume).
Item {
    id: root

    property bool vertical: false

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real volume: sink?.audio?.volume ?? 0

    implicitWidth: row.implicitWidth
    implicitHeight: vertical ? row.implicitHeight : 24
    visible: sink !== null

    PwObjectTracker {
        objects: [root.sink]
    }

    function setVolume(v: real): void {
        if (sink?.ready && sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1.5, v));
        }
    }

    Grid {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        columns: root.vertical ? 1 : 2
        spacing: root.vertical ? 3 : 6
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Shape {
            width: 18
            height: 16
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "transparent"
                fillColor: root.muted ? Theme.textDim : Theme.text
                PathPolyline {
                    path: [Qt.point(0, 5), Qt.point(4, 5), Qt.point(9, 1), Qt.point(9, 15), Qt.point(4, 11), Qt.point(0, 11), Qt.point(0, 5)]
                }
            }

            // Sound waves: one arc per third of the volume range.
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.rgba(Theme.gold.r, Theme.gold.g, Theme.gold.b, !root.muted && root.volume > 0.01 ? 1 : 0)
                strokeWidth: 1.6
                capStyle: ShapePath.RoundCap
                startX: 11.5
                startY: 5.5
                PathArc {
                    x: 11.5
                    y: 10.5
                    radiusX: 3
                    radiusY: 3
                }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.rgba(Theme.gold.r, Theme.gold.g, Theme.gold.b, !root.muted && root.volume > 0.34 ? 1 : 0)
                strokeWidth: 1.6
                capStyle: ShapePath.RoundCap
                startX: 13.5
                startY: 3
                PathArc {
                    x: 13.5
                    y: 13
                    radiusX: 5.5
                    radiusY: 5.5
                }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.rgba(Theme.gold.r, Theme.gold.g, Theme.gold.b, !root.muted && root.volume > 0.67 ? 1 : 0)
                strokeWidth: 1.6
                capStyle: ShapePath.RoundCap
                startX: 15.5
                startY: 0.5
                PathArc {
                    x: 15.5
                    y: 15.5
                    radiusX: 8
                    radiusY: 8
                }
            }
        }

        Text {
            text: root.muted ? (root.vertical ? "off" : "muted") : Math.round(root.volume * 100) + (root.vertical ? "" : "%")
            color: root.muted ? Theme.textDim : Theme.text
            font.family: Theme.font
            font.pixelSize: root.vertical ? 11 : 13
            font.weight: Font.Bold
        }
    }
}
