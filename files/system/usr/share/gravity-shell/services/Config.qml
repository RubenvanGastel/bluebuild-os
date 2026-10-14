pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// User settings, read from ~/.config/gravity-shell/config.json (all keys optional).
// The file is watched, so edits apply immediately.
Singleton {
    id: root

    readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/gravity-shell/config.json"

    // Optional image drawn behind the floating debris. Empty = painted Hekseville sky.
    property alias wallpaper: adapter.wallpaper
    // Set to false to freeze the background (saves battery).
    property alias animatedBackground: adapter.animatedBackground
    property alias debrisCount: adapter.debrisCount
    property alias starCount: adapter.starCount
    // Random gravity shifts every minute or so.
    property alias ambientShifts: adapter.ambientShifts
    // 0 disables auto-lock.
    property alias idleLockMinutes: adapter.idleLockMinutes
    property alias use24h: adapter.use24h

    FileView {
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: adapter

            property string wallpaper: ""
            property bool animatedBackground: true
            property int debrisCount: 18
            property int starCount: 90
            property bool ambientShifts: true
            property int idleLockMinutes: 10
            property bool use24h: true
        }
    }
}
