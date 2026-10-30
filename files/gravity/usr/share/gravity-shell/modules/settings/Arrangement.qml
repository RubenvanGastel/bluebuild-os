import QtQuick
import qs.services

// Where the monitors that are on stand, to drag around: each a card at its size and place,
// scaled to fit. While one is dragged an outline shows where it will go: against the
// nearest side of another, lined up with its edges or middle when close, never
// overlapping. Clicking one picks it (`selected`) for its settings.
Rectangle {
    id: root

    // Connector of the monitor whose settings are shown.
    property string selected
    // Connector of the monitor this picker is on, with the pointer: it stays where it is in
    // niri's layout and the others move around it. Moving it would leave the pointer at the
    // same spot in the layout, which can then be on another monitor (and Wayland has no
    // way to move the pointer back).
    property string anchor
    signal picked(string name)

    // Where niri has them, at their exact size (Displays.rects).
    readonly property var fromNiri: Displays.rects

    // What is shown: niri's, or where one was just dropped until niri has moved it.
    property var rects: []
    property bool dragging: false

    onFromNiriChanged: if (!dragging)
        rects = fromNiri
    Component.onCompleted: rects = fromNiri

    readonly property real minX: Math.min(...rects.map(r => r.x))
    readonly property real minY: Math.min(...rects.map(r => r.y))
    readonly property real spanW: Math.max(...rects.map(r => r.x + r.w)) - minX
    readonly property real spanH: Math.max(...rects.map(r => r.y + r.h)) - minY
    // Fitted with room to drag one past the others.
    readonly property real pad: 20
    readonly property real k: Math.min((width - 2 * pad) / spanW, (height - 2 * pad) / spanH) * 0.7
    readonly property real originX: (width - spanW * k) / 2
    readonly property real originY: (height - spanH * k) / 2

    // Where a dragged one would go, in niri's pixels; null when not dragging.
    property var ghost: null

    width: parent?.width ?? 0
    height: 260
    radius: 20
    color: Theme.deep
    clip: true

    function toView(r: var): var {
        return { x: originX + (r.x - minX) * k, y: originY + (r.y - minY) * k, w: r.w * k, h: r.h * k };
    }

    // The place for monitor `index` let go at (x, y) in niri's pixels (Displays.snapTo).
    function snap(index: int, x: real, y: real): var {
        return Displays.snapTo(rects[index], x, y, rects.filter((_, i) => i !== index));
    }

    // Card `index` is at (px, py) in the picker.
    function fromView(px: real, py: real): var {
        return { x: minX + (px - originX) / k, y: minY + (py - originY) / k };
    }

    function drop(index: int, px: real, py: real): void {
        const at = fromView(px, py);
        const spot = snap(index, at.x, at.y);
        const placed = rects.map((r, i) => i === index ? Object.assign({}, r, spot) : r);
        // All shifted so the anchor stays put (niri takes negative positions too).
        const was = rects.find(r => r.name === anchor), now = placed.find(r => r.name === anchor);
        const dx = was && now ? was.x - now.x : 0, dy = was && now ? was.y - now.y : 0;
        const moved = placed.map(r => Object.assign({}, r, { x: r.x + dx, y: r.y + dy }));
        const positions = {};
        for (const r of moved)
            positions[r.key] = { x: r.x, y: r.y };
        rects = moved;
        Displays.setPositions(positions);
    }

    // Where the dragged one would go.
    Rectangle {
        readonly property var view: root.ghost ? root.toView(root.ghost) : null

        visible: view !== null
        x: view?.x ?? 0
        y: view?.y ?? 0
        width: view?.w ?? 0
        height: view?.h ?? 0
        radius: 12
        color: "transparent"
        border.width: 2
        border.color: Theme.gold
        opacity: 0.8
    }

    Repeater {
        model: root.rects

        Rectangle {
            id: card

            required property var modelData
            required property int index
            readonly property var view: root.toView(modelData)
            readonly property bool chosen: modelData.name === root.selected

            x: view.x
            y: view.y
            width: view.w
            height: view.h
            radius: 12
            z: mouse.drag.active ? 2 : 1
            opacity: mouse.drag.active ? 0.85 : 1
            color: chosen ? Theme.gold : mouse.containsMouse ? Theme.hover(Theme.tonal, 1.2) : Theme.tonal
            border.width: 2
            border.color: chosen ? Theme.hover(Theme.gold, 1.2) : Theme.hover(Theme.tonal, 1.3)

            Behavior on color {
                ColorAnimation {
                    duration: Theme.fast
                }
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - 12
                spacing: 2

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: card.modelData.label
                    color: card.chosen ? Theme.goldInk : Theme.tonalInk
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.Bold
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: card.modelData.name
                    color: card.chosen ? Theme.goldInk : Theme.tonalInk
                    opacity: 0.8
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                drag.target: card
                drag.threshold: 4
                // Kept inside the picker.
                drag.minimumX: 0
                drag.minimumY: 0
                drag.maximumX: root.width - card.width
                drag.maximumY: root.height - card.height

                drag.onActiveChanged: {
                    root.dragging = drag.active;
                    if (drag.active)
                        root.picked(card.modelData.name);
                }
                onPositionChanged: if (drag.active) {
                    const at = root.fromView(card.x, card.y);
                    const spot = root.snap(card.index, at.x, at.y);
                    root.ghost = Object.assign({}, card.modelData, spot);
                }
                onReleased: {
                    root.ghost = null;
                    const index = card.index, px = card.x, py = card.y;
                    const moved = px !== card.view.x || py !== card.view.y;
                    // Back to following the model, which the drop then rebuilds (after this
                    // handler, as that replaces this card).
                    card.x = Qt.binding(() => card.view.x);
                    card.y = Qt.binding(() => card.view.y);
                    if (moved)
                        Qt.callLater(() => root.drop(index, px, py));
                }
                onClicked: root.picked(card.modelData.name)
            }
        }
    }
}
