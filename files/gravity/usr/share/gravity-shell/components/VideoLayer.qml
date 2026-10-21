import QtQuick
import QtMultimedia

// A muted, looping video, cropped to fill. Loaded on demand by FadeImage, so the shell
// still works (with the video's poster frame) when Qt Multimedia isn't installed.
Item {
    id: root

    property string path
    property bool playing: true

    // True once frames are coming in.
    readonly property bool ready: player.playbackState === MediaPlayer.PlayingState && (player.mediaStatus === MediaPlayer.BufferedMedia || player.mediaStatus === MediaPlayer.LoadedMedia)

    MediaPlayer {
        id: player

        source: root.path !== "" ? "file://" + root.path : ""
        loops: MediaPlayer.Infinite
        videoOutput: output
        // No audioOutput: wallpapers are silent.

        onSourceChanged: root.sync()
        onMediaStatusChanged: if (mediaStatus === MediaPlayer.InvalidMedia)
            console.warn("gravity: cannot play", root.path, errorString)
    }

    VideoOutput {
        id: output

        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }

    function sync(): void {
        if (playing && path !== "")
            player.play();
        else
            player.pause();
    }

    onPlayingChanged: sync()
    Component.onCompleted: sync()
}
