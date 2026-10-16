import QtQuick
import qs.services

// A wallpaper (image or video, by file path) that cross-fades when its source changes:
// the new one loads underneath, then fades in on top. A video shows its poster frame
// until it plays. Used for the desktop, the picker preview and the picker cards.
Item {
    id: root

    property string source
    property size sourceSize
    property int duration: Theme.slow
    // False shows the first image at once instead of fading it in.
    property bool fadeFirst: true

    // True: a new image replaces the old one at once, without fading (e.g. while hidden).
    property bool instant: false

    // Keep decoded images in Qt's cache. Worth it for small thumbnails that come and go
    // (the picker cards); off for full-screen wallpapers, which are large.
    property bool cache: false

    // Videos: `live` gives them a player at all (false = poster only), `playing` pauses it.
    property bool live: true
    property bool playing: true

    // True once an image is showing.
    readonly property bool ready: front >= 0
    // Path of the one on top; empty until one shows.
    readonly property string current: front === 0 ? a.path : front === 1 ? b.path : ""

    // Slot on top; -1 = nothing shown yet, so the first one fades in too.
    property int front: -1

    function load(): void {
        const back = front === 0 ? b : a;
        const top = front === 0 ? a : front === 1 ? b : null;
        if (source === "")
            return;
        Media.ensureFrame(source);
        // Mid-fade the layer underneath still shows through, so loading into it would
        // blank it out; the fade's end loads the latest source instead.
        if (top?.fading)
            return;
        // Back to the one on top: drop whatever was still loading underneath.
        if (top && top.path === source)
            back.path = "";
        else
            back.path = source;
    }

    onSourceChanged: load()
    Component.onCompleted: load()

    component Layer: Item {
        id: layer

        required property int slot
        property string path

        readonly property bool video: Media.isVideo(path)
        readonly property bool ready: path !== "" && (still.status === Image.Ready || (player.item?.ready ?? false))
        readonly property bool fading: fadeIn.running

        anchors.fill: parent
        z: root.front === slot ? 1 : 0
        opacity: 0

        // Only if it's still the one wanted; the source may have moved on meanwhile.
        onReadyChanged: if (ready && root.front !== slot && path === root.source)
            promote()

        function promote(): void {
            const first = root.front === -1;
            root.front = slot;
            if ((first && !root.fadeFirst) || root.instant) {
                fadeIn.stop();
                opacity = 1;
                layer.retireOther();
                root.load();
            } else {
                fadeIn.restart();
            }
        }

        // Once on top and opaque, the other layer is covered: let it go.
        function retireOther(): void {
            const other = slot === 0 ? b : a;
            other.path = "";
            other.opacity = 0;
        }

        // The image, or a video's poster frame.
        Image {
            id: still

            anchors.fill: parent
            source: Media.stillUrl(layer.path)
            fillMode: Image.PreserveAspectCrop
            sourceSize: root.sourceSize
            asynchronous: true
            cache: root.cache
        }

        Loader {
            id: player

            anchors.fill: parent
            active: layer.video && root.live
            source: "VideoLayer.qml"
            onLoaded: {
                item.path = Qt.binding(() => layer.path);
                item.playing = Qt.binding(() => root.playing);
            }
        }

        NumberAnimation {
            id: fadeIn
            target: layer
            property: "opacity"
            from: 0
            to: 1
            duration: root.duration
            easing.type: Easing.OutCubic
            onFinished: {
                layer.retireOther();
                root.load();
            }
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
