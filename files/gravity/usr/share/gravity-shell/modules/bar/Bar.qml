import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// The bar along one edge of every screen (Theme.barEdge; its look is in BarSurface.qml).
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData

        screen: modelData
        color: "transparent"
        anchors {
            top: Theme.barEdge !== "bottom"
            bottom: Theme.barEdge !== "top"
            left: Theme.barEdge !== "right"
            right: Theme.barEdge !== "left"
        }
        implicitWidth: surface.depth
        implicitHeight: surface.depth
        exclusiveZone: Theme.barSize
        WlrLayershell.namespace: "gravity-bar"
        WlrLayershell.layer: WlrLayer.Top

        // Only the strip takes clicks; the corners beside it stay click-through.
        mask: Region {
            item: surface.strip
        }

        BarSurface {
            id: surface

            anchors.fill: parent
            output: win.modelData.name
            barWindow: win
        }
    }
}
