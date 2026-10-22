import QtQuick
import QtQuick.Effects
import qs.services

// A panel that is the bar growing into the screen (the quick panel, the system monitor,
// tray menus), on whichever edge the bar is: a solid card against the bar's inner side,
// square where it meets the bar, with concave curves joining it to the bar. Fill a
// screen-sized window with it and put the contents in it; they keep their own size and
// are uncovered from the bar outwards as `grow` goes from 0 to 1. With the floating bar
// (Theme.barStyle) it is a separate card, rounded all round, Theme.gap under the bar.
Item {
    id: root

    // Size of the contents, and of the card once fully grown.
    property real fullWidth
    property real fullHeight
    // 0 = just the bar, 1 = full size.
    property real grow: 0
    // Where along the bar it opens, in this item's x (or y on a side): the middle of the
    // card ("centre") or its far end ("end"); kept clear of the bar's ends. "barEnd" puts it
    // at the bar's far end (right, or bottom on a side), flowing into the screen edge there.
    property real at: 0
    property string align: "centre"
    // Of the corners away from the bar.
    property real radius: 28

    default property alias content: inner.data
    readonly property Item card: card

    readonly property string edge: Theme.barEdge
    readonly property bool vertical: Theme.barVertical
    readonly property real bar: Theme.barSize
    readonly property real corner: Theme.barCorner
    readonly property bool floating: Theme.barStyle === "floating"
    // From the screen edge to the card's side toward the bar.
    readonly property real from: floating ? Theme.barOuter + Theme.gap : bar

    // Along the bar: its length, the card's length and where the card starts.
    readonly property real length: vertical ? height : width
    // Where the bar's ends are, as far as cards go: the frame, or the floating bar's ends.
    readonly property real lo: floating ? Theme.barInset : Theme.frameSize
    readonly property real hi: length - lo
    readonly property real span: vertical ? fullHeight : fullWidth
    readonly property real start: {
        if (align === "barEnd")
            return hi - span;
        const margin = floating ? 0 : corner + Theme.gap;
        const want = align === "end" ? at - span : at - span / 2;
        return Math.max(lo + margin, Math.min(want, hi - margin - span));
    }
    // Away from the bar: how far the card reaches now.
    readonly property real depth: (vertical ? fullWidth : fullHeight) * grow
    readonly property real cornerNow: corner * Math.min(1, depth / corner)

    // Rounding for the card's corner on the right and/or bottom of the screen: none where
    // it meets the bar, nor at the screen edge for "barEnd". Floating, all of them.
    function cornerRadius(right: bool, bottom: bool): real {
        if (floating)
            return Math.min(radius, depth / 2);
        const near = edge === "top" ? !bottom : edge === "bottom" ? bottom : edge === "left" ? !right : right;
        const high = vertical ? bottom : right;
        if (near || (align === "barEnd" && high))
            return 0;
        return Math.min(radius, depth / 2);
    }

    // Joins the card's start to the bar.
    EdgeCorner {
        visible: !root.floating
        u: root.start - size
        v: root.bar
        size: root.cornerNow
        high: true
        fill: Theme.surface
    }

    // Joins its far end to the bar.
    EdgeCorner {
        visible: !root.floating && root.align !== "barEnd"
        u: root.start + root.span
        v: root.bar
        size: root.cornerNow
        fill: Theme.surface
    }

    // At the bar's end: the curve there rides along on the card's outer edge.
    EdgeCorner {
        visible: !root.floating && root.align === "barEnd"
        u: root.hi - size
        v: root.bar + root.depth
        size: root.corner
        high: true
        fill: Theme.surface
    }

    // Floating, a soft shadow like niri's windows have.
    RectangularShadow {
        visible: root.floating && root.depth > 0
        anchors.fill: card
        radius: card.topLeftRadius
        blur: 30
        offset.y: 5
        color: Qt.rgba(0, 0, 0, 0.3)
    }

    Rectangle {
        id: card

        x: root.edge === "left" ? root.from : root.edge === "right" ? root.width - root.from - width : root.start
        y: root.edge === "top" ? root.from : root.edge === "bottom" ? root.height - root.from - height : root.start
        width: root.vertical ? root.depth : root.fullWidth
        height: root.vertical ? root.fullHeight : root.depth
        topLeftRadius: root.cornerRadius(false, false)
        topRightRadius: root.cornerRadius(true, false)
        bottomLeftRadius: root.cornerRadius(false, true)
        bottomRightRadius: root.cornerRadius(true, true)
        color: Theme.surface
        clip: true

        // Clicks on the card itself don't close it.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        // The contents, against the bar side as the card grows.
        Item {
            id: inner

            x: root.edge === "right" ? card.width - width : 0
            y: root.edge === "bottom" ? card.height - height : 0
            width: root.fullWidth
            height: root.fullHeight
        }
    }
}
