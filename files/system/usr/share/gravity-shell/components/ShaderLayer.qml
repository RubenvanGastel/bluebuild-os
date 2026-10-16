import QtQuick
import qs.services

// A Shadertoy-style shader wallpaper (compiled by Media), kept light: it renders at
// `resolution` of the item's size and is scaled up, and its time only moves `fps` times a
// second, so the screen redraws that often and no more. Loaded on demand by FadeImage.
//
// Time starts at 0, and that first frame is saved as the shader's still (the poster,
// matugen colours, the lock screen), so it takes over from its still without a jump.
Item {
    id: root

    property string path
    property bool playing: true
    property real resolution: 0.5
    property int fps: 30

    // True once the shader has compiled; it draws over the still from then on.
    readonly property bool ready: effectLoader.item?.status === ShaderEffect.Compiled

    // Shader time in seconds; it only starts once the first frame has been seen.
    property real t: 0
    property bool ticking: false

    onPathChanged: {
        t = 0;
        ticking = false;
    }

    Item {
        id: canvas

        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(Math.max(1, Math.round(width * root.resolution)), Math.max(1, Math.round(height * root.resolution)))

        // Made once the shader is compiled: without one, ShaderEffect falls back to a
        // default that expects a texture.
        Loader {
            id: effectLoader

            anchors.fill: parent
            active: Media.shaderUrl(root.path) !== ""

            sourceComponent: ShaderEffect {
                fragmentShader: Media.shaderUrl(root.path)

                // The shader's uniforms (see the wrapper in services/Media.qml).
                property real iTime: root.t
                property vector2d res: Qt.vector2d(canvas.layer.textureSize.width, canvas.layer.textureSize.height)
            }
        }
    }

    onReadyChanged: if (ready)
        firstFrame.restart()

    // A moment for the first frame to be drawn; then save it as the still if that hasn't
    // been done this session, and start the clock.
    Timer {
        id: firstFrame

        interval: 150
        onTriggered: {
            if (!Media.posters[root.path]) {
                const path = root.path;
                canvas.grabToImage(result => {
                    if (result.saveToFile(Media.frameOf(path)))
                        Media.posterSaved(path);
                });
            }
            root.ticking = true;
        }
    }

    Timer {
        running: root.ticking && root.playing && root.visible
        repeat: true
        interval: Math.round(1000 / root.fps)
        onTriggered: root.t += interval / 1000
    }
}
