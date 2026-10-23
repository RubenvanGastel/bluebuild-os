import QtQuick
import qs.services

// A few bars of cava's spectrum, low notes first, each growing out both ways from the
// middle (sideways along a side). Accent-coloured while playing, dim and flat when paused.
Grid {
    id: root

    property bool vertical: false
    property int count: 10
    readonly property var levels: Cava.grouped(count)

    columns: vertical ? 1 : count
    spacing: 2

    Repeater {
        model: root.count

        // A slot the full height (width along a side), the bar centred in it.
        Item {
            required property int index
            readonly property real level: Math.max(0.12, Math.min(1, root.levels[index] ?? 0))

            width: root.vertical ? 18 : 3
            height: root.vertical ? 3 : 18

            Rectangle {
                anchors.centerIn: parent
                width: root.vertical ? 18 * parent.level : 3
                height: root.vertical ? 3 : 18 * parent.level
                radius: 1.5
                color: Playback.playing ? Theme.gold : Theme.textDim

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.normal
                    }
                }
            }
        }
    }
}
