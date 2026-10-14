import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services

// Animated floating-city wallpaper on every screen.
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

        GravityScene {
            id: scene

            anchors.fill: parent

            // On login the city rises up from below and settles into place.
            NumberAnimation on intro {
                from: 0
                to: 1
                duration: 2600
                easing.type: Easing.OutCubic
            }
        }
    }
}
