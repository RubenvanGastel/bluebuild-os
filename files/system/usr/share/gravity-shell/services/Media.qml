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

    // Goes up whenever a frame has been made, so posters can load it.
    property int frameTick: 0

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
        return "file://" + stillOf(path) + (isVideo(path) ? "?" + frameTick : "");
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

    // One second in skips a fade from black; very short videos fall back to the start.
    Process {
        id: grab

        property string video

        command: ["sh", "-c", `
            [ -s "$2" ] && exit 0
            mkdir -p "$(dirname "$2")" || exit 1
            tmp="$2.$$.jpg"
            ffmpeg -loglevel error -ss 1 -i "$1" -frames:v 1 -q:v 3 -y "$tmp"
            [ -s "$tmp" ] || ffmpeg -loglevel error -i "$1" -frames:v 1 -q:v 3 -y "$tmp"
            [ -s "$tmp" ] && mv -f "$tmp" "$2"
        `, "sh", video, root.frameOf(video)]
        onExited: code => {
            if (code !== 0)
                console.warn("gravity: could not take a frame from", grab.video);
            root.frameTick++;
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

    Component.onCompleted: ensureFrame(Config.wallpaperPath)
}
