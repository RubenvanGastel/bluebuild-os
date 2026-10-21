import QtQuick
import Quickshell.Bluetooth
import qs.services

// Bluetooth glyph: dim while off, gold while a device is connected. Hidden without an
// adapter.
Text {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    readonly property bool connected: on && (adapter?.devices.values ?? []).some(d => d.connected)

    visible: adapter !== null
    text: !on ? "\u{f00b2}" : connected ? "\u{f00b1}" : "\u{f00af}"
    color: !on ? Theme.textDim : connected ? Theme.gold : Theme.text
    font.family: "Symbols Nerd Font"
    font.pixelSize: 17
}
