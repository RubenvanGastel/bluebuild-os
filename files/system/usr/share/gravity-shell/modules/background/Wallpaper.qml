import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services

// The wallpaper (Config.wallpaper) on every screen, cross-fading when it changes.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData

        screen: modelData
        color: Theme.night
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        // niri's config places this namespace inside the overview backdrop.
        WlrLayershell.namespace: "gravity-wallpaper"

        FadeImage {
            anchors.fill: parent
            // Wait for the config, so a custom wallpaper doesn't load after the default.
            source: Config.ready ? Config.wallpaperPath : ""
            sourceSize: Qt.size(win.modelData.width * win.modelData.devicePixelRatio, win.modelData.height * win.modelData.devicePixelRatio)
            // Cached so the picker's preview can reuse it instead of decoding it again.
            cache: true
            // A video pauses while the wallpaper picker or the lock screen hides it.
            playing: !Media.locked && Media.coveredScreen !== win.modelData.name
        }
    }
}
