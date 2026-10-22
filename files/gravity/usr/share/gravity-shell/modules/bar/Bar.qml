import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// The bar along one edge of every screen (Theme.barEdge; its look is in BarSurface.qml).
// The bar window ignores reserved space, so it is drawn from the screen's own edges; empty
// struts beside it keep windows clear of the bar and, with the frame style, of the frame.
Variants {
    model: Quickshell.screens

    Scope {
        id: scope

        required property ShellScreen modelData

        readonly property bool frame: Theme.barStyle === "frame"

        PanelWindow {
            id: win

            screen: scope.modelData
            color: "transparent"
            // With the frame, the whole screen (the frame's corners curve in at all four).
            anchors {
                top: scope.frame || Theme.barEdge !== "bottom"
                bottom: scope.frame || Theme.barEdge !== "top"
                left: scope.frame || Theme.barEdge !== "right"
                right: scope.frame || Theme.barEdge !== "left"
            }
            implicitWidth: surface.depth
            implicitHeight: surface.depth
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "gravity-bar"
            WlrLayershell.layer: WlrLayer.Top

            // Only the strip takes clicks; the corners beside it stay click-through.
            mask: Region {
                item: surface.strip
            }

            BarSurface {
                id: surface

                anchors.fill: parent
                output: scope.modelData.name
                barWindow: win
            }
        }

        Strut {
            screen: scope.modelData
            edge: Theme.barEdge
            size: Theme.barOuter
        }

        Strut {
            screen: scope.modelData
            edge: ({ top: "bottom", bottom: "top", left: "right", right: "left" })[Theme.barEdge]
            size: Theme.frameSize
        }

        Strut {
            screen: scope.modelData
            edge: Theme.barVertical ? "top" : "left"
            size: Theme.frameSize
        }

        Strut {
            screen: scope.modelData
            edge: Theme.barVertical ? "bottom" : "right"
            size: Theme.frameSize
        }

        // Reserves `size` along one screen edge and draws nothing.
        component Strut: PanelWindow {
            required property string edge
            required property int size

            visible: size > 0
            color: "transparent"
            anchors {
                top: edge !== "bottom"
                bottom: edge !== "top"
                left: edge !== "right"
                right: edge !== "left"
            }
            implicitWidth: size
            implicitHeight: size
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: size
            WlrLayershell.namespace: "gravity-strut"
            WlrLayershell.layer: WlrLayer.Bottom
            mask: Region {}
        }
    }
}
