import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.modules.bar
import qs.services

// Wallpaper picker (`gravity-shell wallpaper`, Mod+Y).
// The wallpaper zooms out into a preview, and three wallpapers rise from the bottom and
// float there. Left/Right scrolls them, Enter applies, Esc closes.
// Lists only the wallpaper folder (Config.wallpaperDir, by default <XDG Pictures>/Wallpapers)
// and picks the colour source, and light or dark (by hand, by the wallpaper or by time of
// day).
Scope {
    id: root

    // `shown` keeps the window visible while the closing animation plays after `open` drops.
    property bool shown: false
    // The window is made on first use and kept (hidden) for a while, so opening it again
    // soon doesn't have to build the scene in the middle of the animation. After
    // `keepFor` ms closed it is unloaded to give its memory (preview, thumbnails, video
    // decoders) back.
    property bool made: false
    readonly property int keepFor: 30000

    onShownChanged: {
        if (shown)
            unloadTimer.stop();
        else
            unloadTimer.restart();
    }

    Timer {
        id: unloadTimer

        interval: root.keepFor
        onTriggered: if (!root.shown)
            root.made = false
    }
    // Screen the picker opens on: the focused one (niri), chosen when it opens.
    property var targetScreen: Quickshell.screens[0]
    property bool open: false
    property var files: []
    // Display names for files that have one (Wallpaper Engine items), by path.
    property var titles: ({})

    // Which wallpapers the carousel shows: images and videos from the wallpaper folder,
    // and Wallpaper Engine Workshop items, apart. Kept while the shell runs; a filter
    // that no longer matches anything shows all.
    property string filter: "all"
    readonly property var filters: [
        { id: "all", label: "All" },
        { id: "images", label: "Images" },
        { id: "videos", label: "Videos" },
        { id: "workshop", label: "Workshop" }
    ]

    function isWorkshop(path: string): bool {
        return path.includes("/steamapps/workshop/content/431960/");
    }

    function matches(path: string, f: string): bool {
        switch (f) {
        case "images":
            return !isWorkshop(path) && !Media.isVideo(path);
        case "videos":
            return !isWorkshop(path) && Media.isVideo(path);
        case "workshop":
            return isWorkshop(path);
        default:
            return true;
        }
    }

    function count(f: string): int {
        return files.filter(p => matches(p, f)).length;
    }

    readonly property var shownFiles: {
        const list = files.filter(p => matches(p, filter));
        return list.length > 0 ? list : files;
    }
    // The folder actually listed, as resolved by the scan; created if missing.
    property string dir: ""

    readonly property string home: Quickshell.env("HOME")
    readonly property string userDir: Config.wallpaperDir.replace(/^~(?=$|\/)/, home)
    // Shown to the user, with ~ for the home folder.
    readonly property string prettyDir: dir.startsWith(home + "/") ? "~" + dir.slice(home.length) : dir

    function toggle(): void {
        if (open) {
            open = false;
        } else {
            targetScreen = Quickshell.screens.find(s => s.name === (Object.values(Niri.workspaces).find(w => w.is_focused)?.output ?? "")) ?? Quickshell.screens[0];
            scan.running = true;
            made = true;
            shown = true;
            open = true;
        }
    }

    // Accepts absolute paths, ~/ paths and file:// urls.
    function setWallpaper(path: string): void {
        const p = path.replace(/^file:\/\//, "").replace(/^~(?=\/)/, home);
        if (p !== "")
            Config.setWallpaper(p);
    }

    Process {
        id: scan

        // Prints the folder on the first line, then its images, then the video wallpapers
        // subscribed to in Wallpaper Engine's Steam Workshop (as "path<TAB>title"; scene
        // and web wallpapers need Wallpaper Engine itself and are left out).
        command: ["sh", "-c", `
            d="$1"
            if [ -z "$d" ]; then
                p=$(xdg-user-dir PICTURES 2>/dev/null)
                [ -n "$p" ] && [ "$p" != "$HOME" ] || p="$HOME/Pictures"
                d="$p/Wallpapers"
            fi
            mkdir -p "$d" 2>/dev/null
            echo "$d"
            find -L "$d" -maxdepth 3 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.jxl" -o -iname "*.avif" -o -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.m4v" \\) 2>/dev/null | sort

            # Steam (Flatpak or native) and every library folder it knows about.
            for s in "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam" "$HOME/.local/share/Steam" "$HOME/.steam/steam"; do
                [ -f "$s/steamapps/libraryfolders.vdf" ] || continue
                echo "$s"
                sed -n 's/^[[:space:]]*"path"[[:space:]]*"\\(.*\\)"$/\\1/p' "$s/steamapps/libraryfolders.vdf"
            done | while read -r lib; do
                realpath -q "$lib/steamapps/workshop/content/431960"
            done | sort -u | while read -r ws; do
                for item in "$ws"/*/; do
                    j="$item/project.json"
                    grep -qi '"type"[[:space:]]*:[[:space:]]*"video"' "$j" 2>/dev/null || continue
                    f=$(sed -n 's/.*"file"[[:space:]]*:[[:space:]]*"\\([^"]*\\)".*/\\1/p' "$j" | head -n 1)
                    [ -n "$f" ] && [ -f "$item$f" ] || continue
                    t=$(sed -n 's/.*"title"[[:space:]]*:[[:space:]]*"\\([^"]*\\)".*/\\1/p' "$j" | head -n 1)
                    printf '%s\\t%s\\n' "$(realpath "$item$f")" "$t"
                done
            done
        `, "sh", root.userDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l !== "");
                root.dir = lines.shift() ?? "";
                const titles = {};
                const list = lines.map(l => {
                    const [path, title] = l.split("\t");
                    if (title)
                        titles[path] = title;
                    return path;
                });
                root.titles = titles;
                // The current wallpaper is always in the list, even from elsewhere.
                if (!list.includes(Config.wallpaperPath))
                    list.unshift(Config.wallpaperPath);
                // Posters for the videos, made in the background.
                list.forEach(p => Media.ensureFrame(p));
                // Only on a real change: a new list rebuilds every card.
                if (JSON.stringify(list) !== JSON.stringify(root.files))
                    root.files = list;
            }
        }
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            root.toggle();
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function get(): string {
            return Config.wallpaperPath;
        }
    }

    // `gravity-shell ipc call theme set wallpaper|accent|default`, `... theme scheme vibrant`,
    // `... theme accent "#3584e4"`
    IpcHandler {
        target: "theme"

        function set(mode: string): void {
            Config.setColors(mode);
        }

        function scheme(name: string): void {
            Config.setColorScheme(name.startsWith("scheme-") ? name : "scheme-" + name);
        }

        // Switches to accent colours from this one (#rrggbb).
        function accent(hex: string): void {
            Config.setAccent(hex);
        }

        function get(): string {
            return Config.colors === "default" ? "default" : Config.colors + " " + Config.colorScheme;
        }
    }

    component Chip: Rectangle {
        id: chip

        required property string label
        property bool selected: false

        signal clicked

        implicitWidth: chipText.implicitWidth + 28
        implicitHeight: 32
        radius: height / 2
        opacity: enabled ? 1 : 0.4
        // Like the bar: accent pill when selected, tonal otherwise.
        color: selected ? Theme.gold : chipMouse.containsMouse ? Theme.hover(Theme.tonal, 1.25) : Theme.tonal

        Behavior on color {
            ColorAnimation {
                duration: Theme.fast
            }
        }

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: chip.selected ? Theme.goldInk : Theme.tonalInk
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.Bold
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    LazyLoader {
        active: root.made

        PanelWindow {
            id: win

            screen: root.targetScreen
            visible: root.shown
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "gravity-wallpaper-picker"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // 0..1 animation progress: the whole overlay fading in, the wallpaper zooming
            // out into the preview, and the cards rising into the air.
            property real fade: 0
            property real zoom: 0
            property real rise: 0

            // Scene time for the floating cards.
            property real t: 0

            readonly property string selected: root.shownFiles[carousel.currentIndex] ?? Config.wallpaperPath

            // Colours (and light or dark, when the wallpaper picks it) follow the selected
            // wallpaper while browsing; back to the applied one when the picker closes.
            Binding {
                target: Theme
                property: "previewPath"
                value: win.selected
                when: root.open
            }
            Binding {
                target: Appearance
                property: "previewPath"
                value: win.selected
                when: root.open
            }
            Binding {
                target: Appearance
                property: "upcoming"
                value: root.shownFiles
                when: root.open
            }

            // Once the overlay is fully opaque the desktop wallpaper is hidden: pause it.
            Binding {
                target: Media
                property: "coveredScreen"
                value: win.screen?.name ?? ""
                when: root.shown && win.fade >= 1
            }

            FrameAnimation {
                running: root.shown
                onTriggered: {
                    win.t += frameTime;
                }
            }

            function easeOutBack(x: real): real {
                const c1 = 1.70158, c3 = c1 + 1;
                return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2);
            }

            // Rise progress of the n-th card from the left, staggered.
            function lift(n: real): real {
                return easeOutBack(Math.max(0, Math.min(1, rise * 1.7 - n * 0.14)));
            }

            // Held keys and the wheel step at most this often (ms), so the cards keep up.
            readonly property int repeatInterval: 190
            property real lastStep: 0

            function scroll(dir: int, repeated: bool): void {
                const now = Date.now();
                if (repeated && now - lastStep < repeatInterval)
                    return;
                lastStep = now;
                if (dir > 0)
                    carousel.incrementCurrentIndex();
                else
                    carousel.decrementCurrentIndex();
            }

            function apply(): void {
                root.setWallpaper(win.selected);
                root.open = false;
            }

            function syncIndex(): void {
                const i = root.shownFiles.indexOf(Config.wallpaperPath);
                if (i >= 0)
                    carousel.currentIndex = i;
            }

            // The filter being switched to; the chips show it at once, the cards follow
            // once they've dropped out of view.
            property string pendingFilter: root.filter
            readonly property string shownFilter: filterAnim.running ? pendingFilter : root.filter

            // The cards drop, the list changes behind them and the new cards rise in. Asking
            // again midway drops them from wherever they are.
            function setFilter(f: string): void {
                if (f === shownFilter)
                    return;
                pendingFilter = f;
                filterAnim.restart();
            }

            // Keeps the selected wallpaper if the new filter shows it, else the applied
            // one, else the first.
            function applyFilter(): void {
                const keep = selected;
                root.filter = pendingFilter;
                const i = root.shownFiles.indexOf(keep);
                carousel.currentIndex = i >= 0 ? i : Math.max(0, root.shownFiles.indexOf(Config.wallpaperPath));
            }

            // Next or previous filter that has something in it.
            function cycleFilter(dir: int): void {
                const ids = root.filters.map(f => f.id).filter(id => id === "all" || root.count(id) > 0);
                const i = ids.indexOf(shownFilter);
                setFilter(ids[((i < 0 ? 0 : i) + dir + ids.length) % ids.length]);
            }

            SequentialAnimation {
                id: filterAnim

                NumberAnimation {
                    target: win
                    property: "rise"
                    to: 0
                    duration: 200
                    easing.type: Easing.InQuad
                }
                ScriptAction {
                    script: win.applyFilter()
                }
                NumberAnimation {
                    target: win
                    property: "rise"
                    to: 1
                    duration: 700
                }
            }

            // The open animation waits until the preview shows the current wallpaper, so it
            // starts as an exact copy of the desktop instead of an empty frame. Should the
            // image not load, it starts anyway after a moment.
            property bool started: false
            // True once the open animation is done. The cards' video players wait for it:
            // setting up a decoder takes long enough to make the animation stutter, and the
            // poster (the video's first frame) shows meanwhile.
            property bool settled: false

            // Back to the start state each time it opens.
            function prepare(): void {
                openAnim.stop();
                closeAnim.stop();
                filterAnim.stop();
                fade = 0;
                zoom = 0;
                rise = 0;
                started = false;
                settled = false;
                previewDelay.stop();
                previewDelay.path = Config.wallpaperPath;
                syncIndex();
                carousel.forceActiveFocus();
                fallback.restart();
                begin(false);
            }

            function begin(force: bool): void {
                if (started || !root.open)
                    return;
                if (!force && previewImage.current !== Config.wallpaperPath)
                    return;
                started = true;
                openAnim.start();
            }

            Timer {
                id: fallback

                interval: 400
                onTriggered: win.begin(true)
            }

            Component.onCompleted: prepare()

            Connections {
                target: root

                function onOpenChanged(): void {
                    if (root.open) {
                        win.prepare();
                    } else {
                        openAnim.stop();
                        fallback.stop();
                        // A switch still under way lands at once; the cards drop anyway.
                        if (filterAnim.running) {
                            filterAnim.stop();
                            win.applyFilter();
                        }
                        closeAnim.start();
                    }
                }

                function onFilesChanged(): void {
                    win.syncIndex();
                }
            }

            // Everything moves at once: the overlay fades in quickly while the wallpaper
            // zooms out, and the cards start rising just after.
            ParallelAnimation {
                id: openAnim

                onFinished: win.settled = true

                NumberAnimation {
                    target: win
                    property: "fade"
                    to: 1
                    duration: 140
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: win
                    property: "zoom"
                    to: 1
                    duration: 560
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.emphasized
                }
                SequentialAnimation {
                    PauseAnimation {
                        duration: 90
                    }
                    NumberAnimation {
                        target: win
                        property: "rise"
                        to: 1
                        duration: 820
                    }
                }
            }

            // The reverse, overlapped: cards drop, the wallpaper grows back to full screen,
            // and the overlay already fades out during the last part of the zoom, so it
            // never stops at full screen.
            SequentialAnimation {
                id: closeAnim

                ParallelAnimation {
                    NumberAnimation {
                        target: win
                        property: "rise"
                        to: 0
                        duration: 340
                    }
                    SequentialAnimation {
                        PauseAnimation {
                            duration: 80
                        }
                        NumberAnimation {
                            target: win
                            property: "zoom"
                            to: 0
                            duration: 420
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.emphasized
                        }
                    }
                    SequentialAnimation {
                        PauseAnimation {
                            duration: 340
                        }
                        NumberAnimation {
                            target: win
                            property: "fade"
                            to: 0
                            duration: 180
                            easing.type: Easing.InQuad
                        }
                    }
                }
                // Hidden now: get the preview and carousel ready for the next open.
                ScriptAction {
                    script: {
                        root.shown = false;
                        previewDelay.stop();
                        previewDelay.path = Config.wallpaperPath;
                        win.syncIndex();
                    }
                }
            }

            Item {
                id: stage

                anchors.fill: parent
                opacity: win.fade

                Rectangle {
                    anchors.fill: parent
                    color: Theme.night
                }

                // Wheel and touchpad browse from anywhere in the picker, vertically or
                // sideways. A wheel notch is 120 (angle units); a touchpad sends many small
                // pixel deltas, which add up so a swipe moves a few cards rather than one
                // per event. A WheelHandler listens to one axis, so there is one per axis;
                // each only acts when its axis is the main one, so diagonals count once.
                QtObject {
                    id: wheel

                    property real sum: 0

                    function take(event: var, horizontal: bool): void {
                        const px = event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0;
                        const v = px ? event.pixelDelta : event.angleDelta;
                        if ((Math.abs(v.x) > Math.abs(v.y)) !== horizontal)
                            return;
                        // Swiping right moves the list left (to the next one), like a browser.
                        const d = horizontal ? v.x : v.y;
                        if (d === 0)
                            return;
                        // Turning around starts over instead of first undoing the other way.
                        sum = Math.sign(sum) === Math.sign(d) ? sum + d : d;
                        if (Math.abs(sum) >= (px ? 60 : 120)) {
                            win.scroll(sum < 0 ? 1 : -1, true);
                            sum = 0;
                        }
                    }
                }

                WheelHandler {
                    orientation: Qt.Vertical
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => wheel.take(event, false)
                }

                WheelHandler {
                    orientation: Qt.Horizontal
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => wheel.take(event, true)
                }

                // Click on empty space to close.
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.open = false
                }

                // --- the wallpaper, zoomed out into a preview ---------------------------
                Item {
                    id: preview

                    readonly property real shrink: 0.4

                    // Always full size and zoomed with a scale, which the GPU does for free;
                    // resizing it every frame would redo the clipping and the image crop.
                    // Sizes inside are divided by the scale so they look the same on screen.
                    width: stage.width
                    height: stage.height
                    transformOrigin: Item.Top
                    scale: 1 - preview.shrink * win.zoom
                    y: stage.height * 0.03 * win.zoom

                    RectangularShadow {
                        anchors.fill: parent
                        radius: frame.radius
                        blur: 40 / preview.scale
                        spread: 0
                        offset.y: 12 / preview.scale
                        color: Qt.rgba(0, 0, 0, 0.55 * win.zoom)
                    }

                    ClippingRectangle {
                        id: frame

                        anchors.fill: parent
                        radius: 28 * win.zoom / preview.scale
                        color: Theme.deep

                        FadeImage {
                            id: previewImage

                            anchors.fill: parent
                            fadeFirst: false
                            // Shares the desktop's decoded image (same file and size), so it's
                            // there at once when the picker shows instead of decoding again.
                            cache: true
                            // Until the open animation starts, swap images without a fade.
                            instant: !win.started
                            onCurrentChanged: win.begin(false)
                            // Paused while the picker is hidden.
                            playing: root.shown
                            source: previewDelay.path
                            duration: Theme.normal
                            sourceSize: Qt.size(win.screen.width * win.screen.devicePixelRatio, win.screen.height * win.screen.devicePixelRatio)
                        }

                        // A live copy of the bar, exactly where the real one is. As the
                        // overlay fades in it takes the real bar's place, then zooms out
                        // with the wallpaper, like a small copy of the desktop. Just a
                        // picture: clicks go to the preview.
                        BarSurface {
                            anchors.fill: parent
                            output: win.screen?.name ?? ""
                            barWindow: win
                            enabled: false
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.apply()
                    }

                    // Full-size decodes are slow, so the preview waits until scrolling pauses.
                    Timer {
                        id: previewDelay

                        property string path: Config.wallpaperPath

                        interval: 140
                        onTriggered: path = win.selected
                    }

                    Connections {
                        target: win

                        function onSelectedChanged(): void {
                            previewDelay.restart();
                        }
                    }
                }

                // --- colours -------------------------------------------------------------
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: preview.y + preview.height * preview.scale + 14 - (1 - win.zoom) * 30
                    spacing: 8
                    opacity: win.zoom

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        Chip {
                            label: "Default colours"
                            selected: Config.colors === "default"
                            onClicked: Config.setColors("default")
                        }

                        Chip {
                            label: "Accent colour"
                            selected: Config.colors === "accent"
                            onClicked: Config.setColors("accent")
                        }

                        Chip {
                            label: "From wallpaper"
                            selected: Config.colors === "wallpaper"
                            onClicked: Config.setColors("wallpaper")
                        }

                        Rectangle {
                            visible: Config.colors !== "default"
                            width: 1
                            height: 20
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.alpha(Theme.text, 0.2)
                        }

                        Repeater {
                            model: Config.colors !== "default" ? Theme.schemes : []

                            Chip {
                                required property var modelData

                                label: modelData.label
                                selected: Config.colorScheme === modelData.id
                                onClicked: Config.setColorScheme(modelData.id)
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: Config.colors !== "default" && Theme.error !== ""
                        text: Theme.error + ", using the default colours"
                        color: Theme.rose
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }
                }

                // --- filters ---------------------------------------------------------------
                // In the empty space left of the preview, sliding in as it zooms out. Empty
                // ones stay in their place, dimmed and out of reach (the keys skip them).
                Column {
                    x: stage.width * (1 - preview.scale) / 2 - width - 28 - (1 - win.zoom) * 30
                    y: preview.y + 8
                    spacing: 8
                    opacity: win.zoom
                    visible: root.files.length > 1

                    Repeater {
                        model: root.filters

                        Chip {
                            required property var modelData

                            anchors.right: parent.right
                            enabled: modelData.id === "all" || root.count(modelData.id) > 0
                            label: modelData.label + "  " + root.count(modelData.id)
                            selected: win.shownFilter === modelData.id
                            onClicked: win.setFilter(modelData.id)
                        }
                    }
                }

                // --- light or dark ---------------------------------------------------------
                // Right of the preview, mirroring the filters. By hand it switches at once;
                // by the wallpaper the preview follows the selected one, and the apps change
                // once it is applied.
                Column {
                    x: stage.width * (1 + preview.scale) / 2 + 28 + (1 - win.zoom) * 30
                    y: preview.y + 8
                    spacing: 8
                    opacity: win.zoom

                    Repeater {
                        model: [
                            { label: "Light", light: true },
                            { label: "Dark", light: false },
                            { label: "By wallpaper", mode: "wallpaper" },
                            { label: "Time of day", mode: "sun" }
                        ]

                        Chip {
                            required property var modelData

                            // Time of day needs a place (for sunrise and sunset), set in the settings.
                            enabled: modelData.mode !== "sun" || Appearance.hasLocation
                            label: modelData.label
                            selected: modelData.mode ? Appearance.mode === modelData.mode : !Appearance.automatic && Appearance.light === modelData.light
                            onClicked: modelData.mode ? Appearance.setMode(modelData.mode) : Appearance.choose(modelData.light)
                        }
                    }

                    Text {
                        visible: Appearance.mode === "wallpaper"
                        leftPadding: 4
                        text: Appearance.brightness[win.selected] === undefined ? "Measuring…" : (Appearance.brightness[win.selected] > Appearance.brightThreshold ? "Light" : "Dark") + " for this one"
                        color: Theme.textDim
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }

                // --- three wallpapers floating in the air ---------------------------------
                // Three in full view, and the edge of the next one peeking in from each side
                // of the screen.
                PathView {
                    id: carousel

                    // Scale of the cards one and two slots from the middle.
                    readonly property real nearScale: 0.85
                    readonly property real farScale: 0.8
                    // How much of the far cards shows at the screen edge.
                    readonly property real peek: width * 0.035
                    // Card width follows the slot width, but stays short enough to fit
                    // under the preview; the slots then place the far cards' edges.
                    readonly property real cardW: Math.round(Math.min(0.82 * (width / 2 - peek) / (2 - 0.41 * farScale), stage.height * 0.22 / 0.62))
                    readonly property real cardH: Math.round(cardW * 0.62)
                    readonly property real spacing: (width / 2 - peek + farScale * cardW / 2) / 2
                    readonly property real cy: height / 2

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: stage.height * 0.055
                    height: cardH * 1.25

                    model: root.shownFiles
                    focus: true
                    // Seven on the path: three in view, two peeking, and one waiting off
                    // screen on each side to slide in.
                    pathItemCount: Math.min(7, root.shownFiles.length)
                    preferredHighlightBegin: 0.5
                    preferredHighlightEnd: 0.5
                    highlightRangeMode: PathView.StrictlyEnforceRange
                    highlightMoveDuration: 380
                    snapMode: PathView.SnapOneItem
                    interactive: false

                    path: Path {
                        startX: carousel.width / 2 - carousel.pathItemCount * carousel.spacing / 2
                        startY: carousel.cy
                        PathLine {
                            x: carousel.width / 2 + carousel.pathItemCount * carousel.spacing / 2
                            y: carousel.cy
                        }
                    }

                    Component.onCompleted: win.syncIndex()

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                            win.scroll(1, event.isAutoRepeat);
                        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                            win.scroll(-1, event.isAutoRepeat);
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                            win.apply();
                        } else if (event.key === Qt.Key_Escape) {
                            root.open = false;
                        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J || event.key === Qt.Key_Tab) {
                            win.cycleFilter(1);
                        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K || event.key === Qt.Key_Backtab) {
                            win.cycleFilter(-1);
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }

                    delegate: Item {
                        id: card

                        required property string modelData
                        required property int index

                        // Position relative to the middle, in card slots (-3..3).
                        readonly property real d: (x + width / 2 - carousel.width / 2) / carousel.spacing
                        readonly property real ad: Math.abs(d)
                        readonly property real p: win.lift(d + 2)
                        readonly property bool middle: ad < 0.5
                        // Hovered at some point while the picker is open: its video stays
                        // loaded, paused where the pointer left it, instead of snapping
                        // back to its poster.
                        property bool seen: false

                        width: carousel.cardW
                        height: carousel.cardH

                        Connections {
                            target: root

                            function onShownChanged(): void {
                                if (!root.shown)
                                    card.seen = false;
                            }
                        }
                        z: 10 - ad
                        scale: 1 - (1 - carousel.nearScale) * Math.min(ad, 1) - (carousel.nearScale - carousel.farScale) * Math.max(0, Math.min(ad, 2) - 1)
                        // The peeking cards are dimmed, and fade out as they leave the screen.
                        opacity: ad <= 1 ? 1 : ad <= 2 ? 1 - (ad - 1) * 0.35 : Math.max(0, 0.65 - (ad - 2) * 1.3)

                        // Each card bobs and tilts gently on its own; while
                        // rising or falling it comes from below the screen.
                        rotation: Math.sin(win.t * 0.8 + index * 2.1) * 1.4
                        transform: Translate {
                            y: Math.sin(win.t * 1.3 + card.index * 1.7) * carousel.cardH * 0.035 + (1 - card.p) * win.height * 0.6
                        }

                        RectangularShadow {
                            anchors.fill: parent
                            radius: cardFrame.radius
                            blur: 30
                            offset.y: 14 + Math.sin(win.t * 1.3 + card.index * 1.7) * 4
                            color: Qt.rgba(0, 0, 0, 0.5)
                        }

                        // Drawn flat into a texture with a transparent rim, which is then
                        // tilted with smooth filtering: tilted directly, the card's straight
                        // edges would be jagged steps that crawl as it bobs.
                        Item {
                            anchors.fill: parent
                            anchors.margins: -2
                            layer.enabled: true
                            layer.smooth: true

                            ClippingRectangle {
                                id: cardFrame

                                anchors.fill: parent
                                anchors.margins: 2
                                radius: 20
                                color: Theme.deep
                                border.width: card.middle ? 3 : 0
                                border.color: Theme.gold

                                // The highlighted card and the one under the pointer play
                                // their video; one hovered before is paused; the others
                                // show their poster.
                                FadeImage {
                                    anchors.fill: parent
                                    source: card.modelData
                                    sourceSize: Qt.size(480, 300)
                                    cache: true
                                    duration: Theme.fast
                                    live: (card.middle || card.seen) && root.shown && win.settled
                                    playing: root.open && (card.middle || cardMouse.containsMouse)
                                }
                            }
                        }

                        MouseArea {
                            id: cardMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: if (containsMouse)
                                card.seen = true
                            onClicked: {
                                if (card.middle)
                                    win.apply();
                                else
                                    win.scroll(card.d > 0 ? 1 : -1, false);
                            }
                        }
                    }
                }

                // --- name and hints -----------------------------------------------------
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: stage.height * 0.015
                    spacing: 2
                    opacity: win.zoom

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.titles[win.selected] ?? win.selected.split("/").pop()
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: (root.files.length <= 1 ? "Put images in " + root.prettyDir + " to see them here" : "←  →  browse    ·    ↑  ↓  filter    ·    Enter  apply    ·    Esc  close    ·    " + root.prettyDir)
                        color: Theme.textDim
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }
}
