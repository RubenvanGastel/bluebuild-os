pragma Singleton

import QtQuick
import Quickshell

// Hekseville at dusk: deep indigo void, Kat's violet gravity glow, warm gold lamplight.
Singleton {
    readonly property color night: "#0d0920"
    readonly property color deep: "#1a1340"
    readonly property color dusk: "#3a2868"
    readonly property color haze: "#6d4a8c"
    readonly property color horizon: "#d98a5c"

    readonly property color nebula: "#7b5cff"
    readonly property color glow: "#b9a3ff"
    readonly property color gold: "#f4c66d"
    readonly property color amber: "#ec9550"
    readonly property color rose: "#ff7eb0"
    readonly property color cream: "#f7ecd6"

    readonly property color text: "#efe8ff"
    readonly property color textDim: "#a99ccc"
    readonly property color panel: Qt.rgba(0.06, 0.04, 0.15, 0.74)
    readonly property color panelBorder: Qt.rgba(0.96, 0.78, 0.43, 0.30)

    readonly property string font: "sans-serif"
    readonly property string displayFont: "serif"

    readonly property int fast: 180
    readonly property int normal: 320
    readonly property int slow: 620
    readonly property int verySlow: 1000

    // Material "emphasized decelerate": things that arrive and settle.
    readonly property var settle: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    // Emphasized accelerate: things that leave.
    readonly property var depart: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
}
