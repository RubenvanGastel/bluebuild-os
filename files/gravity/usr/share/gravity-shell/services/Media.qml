pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Wallpapers can be images or videos. Videos play live (components/VideoLayer.qml); for
// everything that needs a still picture (the poster shown until a video plays, matugen
// colours, the blurred lock screen) a frame is taken from the video with ffmpeg and
// cached in ~/.cache/gravity-shell/frames.
Singleton {
    id: root

    readonly property var videoExtensions: ["mp4", "webm", "mkv", "mov", "m4v"]
    readonly property string frameDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/gravity-shell/frames"

    // Per video, goes up when its frame has been made, so its poster loads it. Only that
    // video's url changes: the other posters keep theirs and don't decode again.
    property var frameVersions: ({})

    // Screen the wallpaper picker covers completely right now ("" = none). The desktop
    // wallpaper there pauses, since nobody can see it.
    property string coveredScreen: ""
    // True while the lock screen covers everything: desktop videos pause.
    property bool locked: false

    function isVideo(path: string): bool {
        const m = /\.([^./]+)$/.exec(path);
        return !!m && videoExtensions.includes(m[1].toLowerCase());
    }

    // Cached frame of a video (it may not exist yet; see ensureFrame).
    function frameOf(path: string): string {
        return frameDir + "/" + Qt.md5(path).slice(0, 16) + ".jpg";
    }

    // A still picture for any wallpaper: the image itself, or a video's frame.
    function stillOf(path: string): string {
        return isVideo(path) ? frameOf(path) : path;
    }

    // file:// url of the still, changing when a new frame is made so an Image reloads it.
    function stillUrl(path: string): string {
        if (path === "")
            return "";
        return "file://" + stillOf(path) + (isVideo(path) ? "?" + (frameVersions[path] ?? 0) : "");
    }

    property var queue: []
    property var asked: ({})

    // Makes the video's frame in the background if it isn't cached yet.
    function ensureFrame(path: string): void {
        if (!isVideo(path) || asked[path])
            return;
        asked[path] = true;
        queue.push(path);
        next();
    }

    function next(): void {
        if (grab.running || queue.length === 0)
            return;
        grab.video = queue.shift();
        grab.running = true;
    }

    // The very first frame, which is where playback starts too, so a video takes over
    // from its poster without a jump.
    Process {
        id: grab

        property string video

        command: ["sh", "-c", `
            [ -s "$2" ] && exit 2
            mkdir -p "$(dirname "$2")" || exit 1
            tmp="$2.$$.jpg"
            ffmpeg -loglevel error -i "$1" -frames:v 1 -q:v 3 -y "$tmp"
            [ -s "$tmp" ] && mv -f "$tmp" "$2"
        `, "sh", video, root.frameOf(video)]
        // 2: it was cached already, so there is nothing to reload.
        onExited: code => {
            if (code !== 0 && code !== 2)
                console.warn("gravity: could not take a frame from", grab.video);
            if (code === 0) {
                const v = Object.assign({}, root.frameVersions);
                v[grab.video] = (v[grab.video] ?? 0) + 1;
                root.frameVersions = v;
            }
            Qt.callLater(root.next);
        }
    }

    // The current wallpaper always has its frame, for the lock screen.
    Connections {
        target: Config

        function onWallpaperPathChanged(): void {
            root.ensureFrame(Config.wallpaperPath);
        }
    }

    // Qt checks every hardware decoder when the first video player is made, which holds
    // the shell up for a second or more (seconds while the NVIDIA GPU is asleep). An empty
    // player shortly after startup does that up front, instead of when the picker opens.
    Loader {
        id: warmUp

        active: false
        source: "../components/VideoLayer.qml"
        onLoaded: Qt.callLater(() => active = false)
    }

    Timer {
        interval: 3000
        running: true
        onTriggered: warmUp.active = true
    }

    Component.onCompleted: ensureFrame(Config.wallpaperPath)
}
