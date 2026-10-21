import QtQuick
import qs.services

// A list that unfolds out of the control above it: it grows open while its rows slide
// down and fade in one after another, and folds back up the same way. Rows take their
// part of the animation from share(index): opacity and a small drop.
Item {
    id: root

    property bool open: false
    // Rows in it, for spreading the stagger.
    property int count: 0
    default property alias content: column.data
    property alias spacing: column.spacing

    // 0 = folded, 1 = open.
    property real unfold: open ? 1 : 0
    readonly property bool moving: anim.running

    Behavior on unfold {
        NumberAnimation {
            id: anim

            duration: Theme.normal + 60
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasized
        }
    }

    // How far the index-th row is along (0..1): each starts a little after the one above,
    // with the delay shrinking for long lists so the last ones aren't left too short a run.
    function share(index: int): real {
        const step = Math.min(0.18, 0.7 / Math.max(1, count - 1));
        return Math.max(0, Math.min(1, unfold * (1 + step * Math.max(0, count - 1)) - step * index));
    }

    visible: unfold > 0
    width: parent?.width ?? 0
    height: (column.implicitHeight + 6) * unfold
    clip: true

    Column {
        id: column

        y: 6
        width: parent.width
        spacing: 4
    }
}
