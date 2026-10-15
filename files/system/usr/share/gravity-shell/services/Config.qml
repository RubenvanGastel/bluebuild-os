pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// User settings, read from ~/.config/gravity-shell/config.json (all keys optional).
// The file is watched, so edits apply immediately. The wallpaper picker writes it too.
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/gravity-shell"
    readonly property string path: dir + "/config.json"

    readonly property string defaultWallpaper: "/usr/share/backgrounds/fedora-workstation/petals_dark.webp"

    // Image on the desktop and (blurred) on the lock screen. Empty = defaultWallpaper.
    property alias wallpaper: adapter.wallpaper
    // The folder the picker lists. Empty = "Wallpapers" in your XDG Pictures folder
    // (whatever it is called in your language, e.g. ~/Afbeeldingen/Wallpapers).
    property alias wallpaperDir: adapter.wallpaperDir
    // "default": the built-in Gravity palette. "wallpaper": colours picked from the
    // wallpaper with matugen.
    property alias colors: adapter.colors
    // matugen scheme for "wallpaper" colours, e.g. scheme-tonal-spot, scheme-vibrant,
    // scheme-expressive, scheme-content, scheme-fidelity, scheme-monochrome.
    property alias colorScheme: adapter.colorScheme
    // Random gravity shifts every minute or so (the bar sways).
    property alias ambientShifts: adapter.ambientShifts
    // 0 disables auto-lock.
    property alias idleLockMinutes: adapter.idleLockMinutes
    property alias use24h: adapter.use24h

    // False until the config file has been read (or found missing).
    property bool ready: false

    readonly property string wallpaperPath: wallpaper !== "" ? wallpaper : defaultWallpaper

    function setWallpaper(file: string): void {
        adapter.wallpaper = file;
        save();
    }

    function setColors(mode: string): void {
        adapter.colors = mode === "wallpaper" ? "wallpaper" : "default";
        save();
    }

    function setColorScheme(scheme: string): void {
        adapter.colorScheme = scheme;
        save();
    }

    function save(): void {
        mkdir.running = true;
    }

    // Built-in defaults. Only settings that differ from these are written to the file, so
    // a default that changes in a later version of the shell still reaches you.
    readonly property var defaults: ({
            wallpaper: "",
            wallpaperDir: "",
            colors: "default",
            colorScheme: "scheme-tonal-spot",
            ambientShifts: true,
            idleLockMinutes: 10,
            use24h: true
        })

    // The config folder may not exist yet on a fresh account.
    Process {
        id: mkdir

        command: ["mkdir", "-p", root.dir]
        onExited: {
            const changed = {};
            for (const key in root.defaults)
                if (adapter[key] !== root.defaults[key])
                    changed[key] = adapter[key];
            file.setText(JSON.stringify(changed, null, 2) + "\n");
        }
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true
        // Read before the first frame, so the right wallpaper shows straight away.
        blockLoading: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.ready = true
        onLoadFailed: root.ready = true

        JsonAdapter {
            id: adapter

            property string wallpaper: root.defaults.wallpaper
            property string wallpaperDir: root.defaults.wallpaperDir
            property string colors: root.defaults.colors
            property string colorScheme: root.defaults.colorScheme
            property bool ambientShifts: root.defaults.ambientShifts
            property int idleLockMinutes: root.defaults.idleLockMinutes
            property bool use24h: root.defaults.use24h
        }
    }
}
