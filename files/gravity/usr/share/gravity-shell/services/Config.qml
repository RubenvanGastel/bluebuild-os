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
    // "default": the built-in palette (GNOME blue). "accent": generated from `accent` with
    // matugen. "wallpaper": picked from the wallpaper with matugen.
    property alias colors: adapter.colors
    // Seed colour for "accent" colours, as #rrggbb.
    property alias accent: adapter.accent
    // matugen scheme for "accent" and "wallpaper" colours, e.g. scheme-tonal-spot, scheme-vibrant,
    // scheme-expressive, scheme-content, scheme-fidelity, scheme-monochrome.
    property alias colorScheme: adapter.colorScheme
    // Who picks light or dark: "manual", "wallpaper" (by its brightness) or "sun" (light
    // from sunrise to sunset at the location below). See Appearance.qml.
    property alias appearanceMode: adapter.appearanceMode
    // Where you are, for sunrise and sunset: a place name to show, and its coordinates.
    // Empty name = not set.
    property alias locationName: adapter.locationName
    property alias latitude: adapter.latitude
    property alias longitude: adapter.longitude
    // 0 disables auto-lock.
    property alias idleLockMinutes: adapter.idleLockMinutes
    property alias use24h: adapter.use24h
    // Language of the shell: "" follows the system, else a code from I18n.languages.
    property alias language: adapter.language
    // The date beside the time in the bar.
    property alias showDate: adapter.showDate
    // Screen edge the bar runs along: "top", "bottom", "left" or "right".
    property alias barPosition: adapter.barPosition
    // "edge", "floating" or "frame" (Theme.barStyle).
    property alias barStyle: adapter.barStyle
    // What the bar shows. With the status pill (network, Bluetooth and volume) hidden, the
    // quick panel still opens with `gravity-shell ipc call quickPanel toggle`. The battery
    // pill only shows on laptops.
    property alias barWorkspaces: adapter.barWorkspaces
    property alias barTitle: adapter.barTitle
    property alias barClock: adapter.barClock
    // The audio visualiser beside the clock, while a media player is around; it opens the
    // media panel.
    property alias barMedia: adapter.barMedia
    // Frames a second of the visualisers (cava's framerate).
    property alias cavaFps: adapter.cavaFps
    // How the visualisers draw the spectrum: "bars", "wave" or "dots".
    property alias visualizerStyle: adapter.visualizerStyle
    property alias barStats: adapter.barStats
    property alias barTray: adapter.barTray
    property alias barBattery: adapter.barBattery
    property alias barStatus: adapter.barStatus
    // Whether apps take the shell's colours: GTK/GNOME apps (gtk.css and the nearest GNOME
    // accent), Qt and KDE apps (qt6ct's palette and KDE's colours), Ghostty, Vesktop (a
    // Vencord theme) and Zen (userChrome.css). Off returns each to its own colours. Only
    // Ghostty is on by default; the others are opt-in in the settings.
    property alias themeGtk: adapter.themeGtk
    property alias themeQt: adapter.themeQt
    property alias themeGhostty: adapter.themeGhostty
    property alias themeVesktop: adapter.themeVesktop
    property alias themeZen: adapter.themeZen
    // See-through surfaces with niri's blur behind them: the shell's own, Ghostty's, Zen's
    // and (with their colours on) GTK apps' and Vesktop's. Off returns each to solid. `blur` alone uses
    // niri's xray blur, of the wallpaper only, made once and shared; `blurWindows` blurs
    // whatever is behind, windows included, which niri redraws whenever that changes.
    property alias blur: adapter.blur
    property alias blurWindows: adapter.blurWindows
    // How strong niri's blur is, 0..1 (its `blur { offset }`; 0.4 is niri's own default).
    property alias blurStrength: adapter.blurStrength
    // Monitors (services/Displays.qml). `displays`: per monitor, by niri's "make model
    // serial", the mode ("WxH@Hz" of its own, "custom:<n>" for one of `customModes`, empty
    // for its preferred one), scale (0 = niri's), vrr ("off", "on", "on-demand") and the
    // custom modes added for it. `displayLayouts`: per set of monitors connected together,
    // how they are used ("extend", "mirror", "internal", "external") and where each is.
    // A set never seen before extends, every monitor in its preferred mode.
    property alias displays: adapter.displays
    property alias displayLayouts: adapter.displayLayouts

    // False until the config file has been read (or found missing).
    property bool ready: false

    readonly property string wallpaperPath: wallpaper !== "" ? wallpaper : defaultWallpaper

    function setWallpaper(file: string): void {
        adapter.wallpaper = file;
        save();
    }

    function setColors(mode: string): void {
        adapter.colors = mode === "wallpaper" || mode === "accent" ? mode : "default";
        save();
    }

    // Switches to "accent" colours from this one (#rrggbb, or rrggbb).
    function setAccent(hex: string): void {
        const c = hex.trim().replace(/^#?/, "#").toLowerCase();
        if (!/^#[0-9a-f]{6}$/.test(c))
            return;
        adapter.accent = c;
        adapter.colors = "accent";
        save();
    }

    function setColorScheme(scheme: string): void {
        adapter.colorScheme = scheme;
        save();
    }

    function setLocation(name: string, lat: real, lon: real): void {
        adapter.locationName = name;
        adapter.latitude = lat;
        adapter.longitude = lon;
        save();
    }

    // Any setting by name, as the settings card does.
    function set(key: string, value: var): void {
        if (!(key in defaults) || root.same(adapter[key], value))
            return;
        adapter[key] = value;
        save();
    }

    // Settings that are objects compare by what they hold.
    function same(a: var, b: var): bool {
        return typeof a === "object" || typeof b === "object" ? JSON.stringify(a) === JSON.stringify(b) : a === b;
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
            accent: "#3584e4",
            colorScheme: "scheme-tonal-spot",
            appearanceMode: "manual",
            locationName: "",
            latitude: 0,
            longitude: 0,
            idleLockMinutes: 10,
            use24h: true,
            language: "",
            showDate: true,
            barPosition: "top",
            barStyle: "edge",
            barWorkspaces: true,
            barTitle: true,
            barClock: true,
            barMedia: true,
            cavaFps: 60,
            visualizerStyle: "bars",
            barStats: true,
            barTray: true,
            barBattery: true,
            barStatus: true,
            themeGtk: false,
            themeQt: false,
            themeGhostty: true,
            themeVesktop: false,
            themeZen: false,
            blur: false,
            blurWindows: false,
            blurStrength: 0.4,
            displays: ({}),
            displayLayouts: ({})
        })

    // The config folder may not exist yet on a fresh account.
    Process {
        id: mkdir

        command: ["mkdir", "-p", root.dir]
        onExited: {
            const changed = {};
            for (const key in root.defaults)
                if (!root.same(adapter[key], root.defaults[key]))
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
            property string accent: root.defaults.accent
            property string colorScheme: root.defaults.colorScheme
            property string appearanceMode: root.defaults.appearanceMode
            property string locationName: root.defaults.locationName
            property real latitude: root.defaults.latitude
            property real longitude: root.defaults.longitude
            property int idleLockMinutes: root.defaults.idleLockMinutes
            property bool use24h: root.defaults.use24h
            property string language: root.defaults.language
            property bool showDate: root.defaults.showDate
            property string barPosition: root.defaults.barPosition
            property string barStyle: root.defaults.barStyle
            property bool barWorkspaces: root.defaults.barWorkspaces
            property bool barTitle: root.defaults.barTitle
            property bool barClock: root.defaults.barClock
            property bool barMedia: root.defaults.barMedia
            property int cavaFps: root.defaults.cavaFps
            property string visualizerStyle: root.defaults.visualizerStyle
            property bool barStats: root.defaults.barStats
            property bool barTray: root.defaults.barTray
            property bool barBattery: root.defaults.barBattery
            property bool barStatus: root.defaults.barStatus
            property bool themeGtk: root.defaults.themeGtk
            property bool themeQt: root.defaults.themeQt
            property bool themeGhostty: root.defaults.themeGhostty
            property bool themeVesktop: root.defaults.themeVesktop
            property bool themeZen: root.defaults.themeZen
            property bool blur: root.defaults.blur
            property bool blurWindows: root.defaults.blurWindows
            property real blurStrength: root.defaults.blurStrength
            property var displays: root.defaults.displays
            property var displayLayouts: root.defaults.displayLayouts
        }
    }
}
