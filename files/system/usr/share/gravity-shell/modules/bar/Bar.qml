import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// The bar along the top edge of every screen (its look is in BarSurface.qml).
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData

        screen: modelData
        color: "transparent"
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: surface.implicitHeight
        exclusiveZone: Theme.barHeight
        WlrLayershell.namespace: "gravity-bar"
        WlrLayershell.layer: WlrLayer.Top

        // Only the strip takes clicks; the corners below it stay click-through.
        mask: Region {
            item: surface.strip
        }

        BarSurface {
            id: surface

            width: parent.width
            output: win.modelData.name
            barWindow: win
        }
    }
}
