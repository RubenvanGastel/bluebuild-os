pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Wallpapers can be images, videos or shaders. Videos play live (components/VideoLayer.qml);
// for everything that needs a still picture (the poster shown until a video plays,
// matugen colours, the blurred lock screen) a frame is taken from the video with ffmpeg
// and cached in ~/.cache/gravity-shell/frames.
//
// Shaders are Shadertoy-style .glsl files (a mainImage() function using iTime and
// iResolution). They are wrapped and compiled with Qt's qsb into ~/.cache/gravity-shell/
// shaders and run by components/ShaderLayer.qml, which also saves their first frame as
// the still.
Singleton {
    id: root

    readonly property var videoExtensions: ["mp4", "webm", "mkv", "mov", "m4v"]
    readonly property string frameDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/gravity-shell/frames"
    readonly property string shaderDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/gravity-shell/shaders"

    // Goes up whenever a frame has been made, so posters can load it.
    property int frameTick: 0

    // Screen the wallpaper picker covers completely right now ("" = none). The desktop
    // wallpaper there pauses, since nobody can see it.
    property string coveredScreen: ""
    // True while the lock screen covers everything: desktop videos pause.
    property bool locked: false

    function isVideo(path: string): bool {
        const m = /\.([^./]+)$/.exec(path);
        return !!m && videoExtensions.includes(m[1].toLowerCase());
    }

    function isShader(path: string): bool {
        return /\.glsl$/i.test(path);
    }

    // Anything with a still that has to be made: a video's or a shader's frame.
    function hasFrame(path: string): bool {
        return isVideo(path) || isShader(path);
    }

    // Cached frame of a video (it may not exist yet; see ensureFrame).
    function frameOf(path: string): string {
        return frameDir + "/" + Qt.md5(path).slice(0, 16) + ".jpg";
    }

    // A still picture for any wallpaper: the image itself, or a video's or shader's frame.
    function stillOf(path: string): string {
        return hasFrame(path) ? frameOf(path) : path;
    }

    // file:// url of the still, changing when a new frame is made so an Image reloads it.
    function stillUrl(path: string): string {
        if (path === "")
            return "";
        return "file://" + stillOf(path) + (hasFrame(path) ? "?" + frameTick : "");
    }

    // --- shaders ------------------------------------------------------------------------
    // Shaders whose first frame has been saved this session (by ShaderLayer).
    property var posters: ({})

    function posterSaved(path: string): void {
        posters[path] = true;
        frameTick++;
    }

    // Compiled shaders by path: a number that goes up with each compile, so the url
    // changes and the effect reloads it. Missing = not compiled (yet, or it failed).
    property var compiled: ({})
    property var shaderQueue: []
    property var shaderAsked: ({})

    function qsbOf(path: string): string {
        return shaderDir + "/" + Qt.md5(path).slice(0, 16) + ".qsb";
    }

    function shaderUrl(path: string): string {
        return compiled[path] ? "file://" + qsbOf(path) + "?" + compiled[path] : "";
    }

    function ensureShader(path: string): void {
        if (!isShader(path) || shaderAsked[path])
            return;
        shaderAsked[path] = true;
        shaderQueue.push(path);
        nextShader();
    }

    function nextShader(): void {
        if (compile.running || shaderQueue.length === 0)
            return;
        compile.shader = shaderQueue.shift();
        compile.running = true;
    }

    // Wraps the Shadertoy-style code for Qt's ShaderEffect (its uniform block, and
    // fragCoord with y up as on Shadertoy) and compiles it, unless the cached one is newer.
    Process {
        id: compile

        property string shader

        command: ["sh", "-c", `
            src="$1"; out="$2"
            # The frame ShaderLayer saves goes here.
            mkdir -p "$3" "$(dirname "$out")" || exit 1
            [ -s "$out" ] && [ "$out" -nt "$src" ] && exit 0
            tmp="$out.$$"
            {
                cat <<'HEAD'
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float iTime;
    vec2 res;
};
#define iResolution vec3(res, 1.0)
#define iMouse vec4(0.0)
#define iFrame int(iTime * 30.0)
#line 1
HEAD
                cat "$src"
                cat <<'FOOT'

void main() {
    vec4 c = vec4(0.0);
    mainImage(c, vec2(qt_TexCoord0.x, 1.0 - qt_TexCoord0.y) * res);
    fragColor = vec4(c.rgb, 1.0) * qt_Opacity;
}
FOOT
            } > "$tmp.frag"
            /usr/lib64/qt6/bin/qsb --qt6 -o "$tmp" "$tmp.frag"; code=$?
            rm -f "$tmp.frag"
            [ $code -eq 0 ] && mv -f "$tmp" "$out"
            exit $code
        `, "sh", shader, root.qsbOf(shader), root.frameDir]
        stderr: StdioCollector {
            id: compileErr
        }
        onExited: code => {
            if (code === 0) {
                const c = Object.assign({}, root.compiled);
                c[compile.shader] = (c[compile.shader] ?? 0) + 1;
                root.compiled = c;
            } else {
                console.warn("gravity: could not compile shader", compile.shader, compileErr.text.trim());
            }
            Qt.callLater(root.nextShader);
        }
    }

    property var queue: []
    property var asked: ({})

    // Makes the video's frame in the background if it isn't cached yet. Shaders are
    // compiled instead; their frame comes from ShaderLayer once one runs.
    function ensureFrame(path: string): void {
        if (isShader(path)) {
            ensureShader(path);
            return;
        }
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
            [ -s "$2" ] && exit 0
            mkdir -p "$(dirname "$2")" || exit 1
            tmp="$2.$$.jpg"
            ffmpeg -loglevel error -i "$1" -frames:v 1 -q:v 3 -y "$tmp"
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
