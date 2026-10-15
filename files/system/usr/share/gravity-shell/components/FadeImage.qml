import QtQuick
import qs.services

// An image (by file path) that cross-fades when its source changes: the new picture
// loads underneath, then fades in on top. Used for the wallpaper and the picker preview.
Item {
    id: root

    property string source
    property size sourceSize
    property int duration: Theme.slow

    // Slot of the image on top; -1 = nothing shown yet, so the first one fades in too.
    property int front: -1

    function load(): void {
        const back = front === 0 ? b : a;
        const url = source !== "" ? "file://" + source : "";
        if (url !== "" && back.source.toString() !== url)
            back.source = url;
    }

    onSourceChanged: load()
    Component.onCompleted: load()

    component Layer: Image {
        id: img

        required property int slot

        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize: root.sourceSize
        asynchronous: true
        cache: false
        z: root.front === slot ? 1 : 0
        opacity: 0

        onStatusChanged: if (status === Image.Ready && root.front !== slot) {
            root.front = slot;
            fadeIn.restart();
        }

        NumberAnimation {
            id: fadeIn
            target: img
            property: "opacity"
            from: 0
            to: 1
            duration: root.duration
            easing.type: Easing.OutCubic
        }
    }

    Layer {
        id: a
        slot: 0
    }

    Layer {
        id: b
        slot: 1
    }
}
