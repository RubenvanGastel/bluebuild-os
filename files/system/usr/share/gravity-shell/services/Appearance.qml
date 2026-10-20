pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Light or dark, for the shell and every app. GNOME's color-scheme setting is the switch:
// libadwaita apps and (through the desktop portal) browsers and Flatpaks follow it, and
// it is watched, so a change made elsewhere (e.g. GNOME Settings) reaches the shell too.
// GTK 3 apps don't read it, so their theme is switched along with it between adw-gtk3
// and adw-gtk3-dark (unless you picked a different GTK theme yourself).
//
// Config.appearanceMode picks who decides:
//   "manual"     you (choose(), the Light/Dark buttons)
//   "wallpaper"  light when the wallpaper is bright on average, dark when it is dark
//   "sun"        light between sunrise and sunset at Config.latitude/longitude, worked
//                out here (no network needed once the place is set)
Singleton {
    id: root

    property bool light: false
    // False until the setting has been read.
    property bool ready: false

    readonly property string mode: ["wallpaper", "sun"].includes(Config.appearanceMode) ? Config.appearanceMode : "manual"
    readonly property bool automatic: mode !== "manual"
    readonly property bool hasLocation: Config.locationName !== ""

    readonly property real brightThreshold: 0.35

    // "sun": today's sunrise and sunset (null in a polar day or night), whether the sun is
    // up, and when that changes next.
    property var sunrise: null
    property var sunset: null
    property bool sunUp: true
    property var nextChange: null

    // What the automatic mode wants; null when it can't tell (yet).
    readonly property var wanted: mode === "wallpaper" ? (wallpaperBrightness < 0 ? null : wallpaperBrightness > brightThreshold) : mode === "sun" ? (hasLocation ? sunUp : null) : null

    onWantedChanged: {
        follow();
        updateShown();
    }
    onReadyChanged: {
        follow();
        updateShown();
    }

    function follow(): void {
        if (ready && automatic && wanted !== null && wanted !== light)
            setLight(wanted);
    }

    // Light or dark by hand: back to manual mode.
    function choose(on: bool): void {
        Config.set("appearanceMode", "manual");
        setLight(on);
    }

    function toggle(): void {
        choose(!light);
    }

    function setMode(m: string): void {
        Config.set("appearanceMode", ["wallpaper", "sun"].includes(m) ? m : "manual");
    }

    // niri freezes the screen first and crossfades to the new look once the apps have
    // redrawn, as GNOME does. `light` follows when the setting has changed (the watch below),
    // so the shell, too, changes behind the frozen picture rather than before it.
    function setLight(on: bool): void {
        // One switch at a time; a click during one is done right after it.
        if (write.running) {
            write.next = on;
            return;
        }
        write.command = ["sh", "-c", 'niri msg action do-screen-transition 2>/dev/null; gsettings set org.gnome.desktop.interface color-scheme "$0"', on ? "prefer-light" : "prefer-dark"];
        write.running = true;
    }

    Process {
        id: write

        property var next: null

        onExited: code => {
            if (code !== 0)
                console.warn("gravity: could not set the colour scheme");
            if (next !== null) {
                const on = next;
                next = null;
                root.setLight(on);
            }
        }
    }

    // Prints the value once, then a line for every change. "default" counts as light,
    // as it does for libadwaita.
    Process {
        id: watch

        running: true
        command: ["sh", "-c", "gsettings get org.gnome.desktop.interface color-scheme && exec gsettings monitor org.gnome.desktop.interface color-scheme"]
        stdout: SplitParser {
            onRead: line => {
                root.light = !line.includes("prefer-dark");
                root.ready = true;
                gtk.running = false;
                gtk.running = true;
            }
        }
        onExited: {
            root.ready = true;
            rewatch.start();
        }
    }

    Timer {
        id: rewatch

        interval: 5000
        onTriggered: watch.running = true
    }

    Process {
        id: gtk

        command: ["sh", "-c", `
            cur=$(gsettings get org.gnome.desktop.interface gtk-theme) || exit 1
            case "$cur" in
                "'Adwaita'"|"'Adwaita-dark'"|"'adw-gtk3'"|"'adw-gtk3-dark'") ;;
                *) exit 0 ;;
            esac
            [ -d /usr/share/themes/adw-gtk3 ] || exit 0
            want=adw-gtk3$1
            [ "$cur" = "'$want'" ] || gsettings set org.gnome.desktop.interface gtk-theme "$want"
        `, "sh", root.light ? "" : "-dark"]
    }

    // --- by the wallpaper ---------------------------------------------------------------------
    // While the wallpaper picker is open: the wallpaper it has selected. The shell (Theme)
    // previews that one's light or dark; the apps change once it is applied.
    property string previewPath: ""

    // Brightness by wallpaper path, measured once each, so browsing back and forth is
    // instant. ffmpeg averages the image (or a video's first frame) down to one grey pixel.
    property var brightness: ({})
    readonly property real wallpaperBrightness: brightness[Config.wallpaperPath] ?? -1
    // While the picker is open: its wallpapers, measured ahead (nearest the selected one
    // first) so each is known by the time you get to it.
    property var upcoming: []

    // Whether light or dark is known for this wallpaper: always, unless the wallpaper picks
    // it and it isn't measured yet. Theme waits for it before making colours, so it doesn't
    // make the wrong mode's first and then switch.
    function knows(path: string): bool {
        return mode !== "wallpaper" || brightness[path] !== undefined;
    }

    // What the shell shows: the previewed wallpaper's light or dark while browsing, otherwise
    // what the automatic mode wants (so it doesn't flick back to the old one while the
    // setting is still being written), otherwise what is set. A wallpaper that isn't
    // measured yet keeps what is shown, rather than flashing the other mode in between.
    property bool shownLight: false
    property bool shownSet: false

    function updateShown(): void {
        const path = previewPath !== "" ? previewPath : Config.wallpaperPath;
        if (mode === "wallpaper") {
            const b = brightness[path];
            if (b !== undefined)
                show(b > brightThreshold);
            else if (!shownSet && ready)
                show(light);
            return;
        }
        if (automatic && wanted !== null)
            show(wanted);
        else if (ready)
            show(light);
    }

    function show(on: bool): void {
        shownLight = on;
        shownSet = true;
    }

    onLightChanged: updateShown()
    onBrightnessChanged: {
        updateShown();
        saveBrightness.restart();
    }
    Component.onCompleted: updateShown()

    // Measures the previewed wallpaper, the applied one and then the picker's others when
    // they aren't known yet, one at a time; each finished run looks again.
    function measureNext(): void {
        if (mode !== "wallpaper" || !Config.ready || !cacheLoaded || measure.running)
            return;
        const at = Math.max(0, upcoming.indexOf(previewPath));
        const near = upcoming.map((p, i) => [p, Math.abs(i - at)]).sort((a, b) => a[1] - b[1]).map(e => e[0]);
        const path = [previewPath, Config.wallpaperPath, ...near].find(p => p !== "" && brightness[p] === undefined);
        if (!path)
            return;
        measure.path = path;
        measure.running = true;
    }

    onModeChanged: {
        measureNext();
        updateShown();
    }
    onPreviewPathChanged: {
        measureNext();
        updateShown();
    }
    onUpcomingChanged: measureNext()

    Connections {
        target: Config

        function onWallpaperPathChanged(): void {
            root.measureNext();
            root.updateShown();
        }
        function onReadyChanged(): void {
            root.measureNext();
        }
    }

    Process {
        id: measure

        property string path

        command: ["sh", "-c", 'ffmpeg -loglevel error -i "$0" -frames:v 1 -vf "scale=1:1:flags=area,format=gray" -f rawvideo - | od -An -tu1', path]
        stdout: StdioCollector {
            id: grey
        }
        onExited: {
            const v = parseInt(grey.text.trim());
            if (isNaN(v))
                console.warn("gravity: could not measure the brightness of", measure.path);
            // A failed one counts as dark, so it isn't tried again and again.
            root.brightness = Object.assign({}, root.brightness, { [measure.path]: isNaN(v) ? 0 : v / 255 });
            root.measureNext();
        }
    }

    // Measurements are kept across restarts, by path; a wallpaper replaced under the same
    // name keeps its old one until the cache is removed.
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/gravity-shell"
    property bool cacheLoaded: false

    onCacheLoadedChanged: measureNext()

    FileView {
        id: brightnessFile

        path: root.cacheDir + "/brightness.json"
        printErrors: false
        blockLoading: true

        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (data && typeof data === "object")
                    root.brightness = Object.assign(data, root.brightness);
            } catch (e) {}
            root.cacheLoaded = true;
        }
        onLoadFailed: root.cacheLoaded = true
    }

    Timer {
        id: saveBrightness

        interval: 2000
        onTriggered: {
            if (!root.cacheLoaded)
                return;
            saveProc.running = false;
            saveProc.text = JSON.stringify(root.brightness);
            saveProc.running = true;
        }
    }

    // Written to a temporary file and moved into place, like Theme's colours.
    Process {
        id: saveProc

        property string text

        command: ["sh", "-c", 'mkdir -p "$0" && printf "%s" "$1" > "$0/brightness.json.tmp" && mv -f "$0/brightness.json.tmp" "$0/brightness.json"', root.cacheDir, text]
    }

    // --- by the sun ---------------------------------------------------------------------------
    // Sunrise and sunset on the day of `date` (NOAA's approximation, within a minute or so),
    // as Dates; {polar: "day"|"night"} when the sun doesn't rise or set that day.
    function sunTimes(date: var, lat: real, lon: real): var {
        const rad = Math.PI / 180;
        const base = Date.UTC(date.getFullYear(), date.getMonth(), date.getDate());
        const day = Math.round((base - Date.UTC(date.getFullYear(), 0, 1)) / 86400000) + 1;
        const g = 2 * Math.PI / 365 * (day - 1);
        const eqtime = 229.18 * (0.000075 + 0.001868 * Math.cos(g) - 0.032077 * Math.sin(g) - 0.014615 * Math.cos(2 * g) - 0.040849 * Math.sin(2 * g));
        const decl = 0.006918 - 0.399912 * Math.cos(g) + 0.070257 * Math.sin(g) - 0.006758 * Math.cos(2 * g) + 0.000907 * Math.sin(2 * g) - 0.002697 * Math.cos(3 * g) + 0.00148 * Math.sin(3 * g);
        // The sun's centre 0.833° below the horizon: refraction and its radius.
        const cosHa = Math.cos(90.833 * rad) / (Math.cos(lat * rad) * Math.cos(decl)) - Math.tan(lat * rad) * Math.tan(decl);
        if (cosHa > 1)
            return { polar: "night" };
        if (cosHa < -1)
            return { polar: "day" };
        const ha = Math.acos(cosHa) / rad;
        return {
            rise: new Date(base + (720 - 4 * (lon + ha) - eqtime) * 60000),
            set: new Date(base + (720 - 4 * (lon - ha) - eqtime) * 60000)
        };
    }

    function updateSun(): void {
        if (!hasLocation) {
            sunrise = sunset = nextChange = null;
            return;
        }
        const now = new Date();
        const today = sunTimes(now, Config.latitude, Config.longitude);
        const tomorrow = sunTimes(new Date(now.getTime() + 86400000), Config.latitude, Config.longitude);
        sunrise = today.rise ?? null;
        sunset = today.set ?? null;
        if (today.polar) {
            sunUp = today.polar === "day";
            nextChange = null;
        } else if (now < today.rise) {
            sunUp = false;
            nextChange = today.rise;
        } else if (now < today.set) {
            sunUp = true;
            nextChange = today.set;
        } else {
            sunUp = false;
            nextChange = tomorrow.rise ?? null;
        }
    }

    // Checked every minute rather than timed to the second, so a suspend in between can't
    // make it miss the change.
    Timer {
        running: root.mode === "sun" || root.hasLocation
        repeat: true
        triggeredOnStart: true
        interval: 60000
        onTriggered: root.updateSun()
    }

    Connections {
        target: Config

        function onLatitudeChanged(): void {
            root.updateSun();
        }
        function onLongitudeChanged(): void {
            root.updateSun();
        }
    }

    // `gravity-shell ipc call appearance toggle`, `... set light|dark` (both manual),
    // `... auto wallpaper|sun|manual`
    IpcHandler {
        target: "appearance"

        function toggle(): void {
            root.toggle();
        }

        function set(mode: string): void {
            root.choose(mode === "light");
        }

        function auto(mode: string): void {
            root.setMode(mode);
        }

        function get(): string {
            return (root.light ? "light" : "dark") + (root.automatic ? " (" + root.mode + ")" : "");
        }
    }
}
