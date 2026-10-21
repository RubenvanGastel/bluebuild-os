import QtQuick
import Quickshell.Networking
import qs.services

// Network glyph: ethernet while a cable is connected, otherwise the Wi-Fi signal strength,
// dim when Wi-Fi is off or not connected.
Text {
    id: root

    readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property bool wifiOn: Networking.wifiEnabled && Networking.wifiHardwareEnabled
    readonly property var wifiConnected: (wifiDevice?.networks.values ?? []).find(n => n.connected) ?? null

    visible: wired !== null || wifiDevice !== null
    // Nerd Font glyphs, as in the quick panel's Wi-Fi tile.
    text: wired ? "\u{f0200}" : !wifiOn ? "\u{f05aa}" : wifiConnected ? String.fromCodePoint(0xf091f + Math.max(0, Math.min(3, Math.floor(wifiConnected.signalStrength * 4 - 0.01))) * 3) : "\u{f092f}"
    color: wired || wifiConnected ? Theme.text : Theme.textDim
    font.family: "Symbols Nerd Font"
    font.pixelSize: 17
}
