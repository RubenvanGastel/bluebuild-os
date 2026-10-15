import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.services

// Wallpaper picker (`gravity-shell wallpaper`, Mod+Shift+W).
// The wallpaper zooms out into a preview, and three wallpapers rise from the bottom and
// float in the gravity field. Left/Right scrolls them, Enter applies, Esc closes.
// Lists only the wallpaper folder (Config.wallpaperDir, by default <XDG Pictures>/Wallpapers)
// and picks the colour source.
Scope {
    id: root

    // `shown` keeps the window visible while the closing animation plays after `open` drops.
    property bool shown: false
    // The window is made on first use and then kept (hidden), so later opens don't have to
    // build the scene again in the middle of the animation.
    property bool made: false
    // Screen the picker opens on: the focused one (niri), chosen when it opens.
    property var targetScreen: Quickshell.screens[0]
    property bool open: false
    property var files: []
    // The folder actually listed, as resolved by the scan; created if missing.
    property string dir: ""

    readonly property string home: Quickshell.env("HOME")
    readonly property string userDir: Config.wallpaperDir.replace(/^~(?=$|\/)/, home)
    // Shown to the user, with ~ for the home folder.
    readonly property string prettyDir: dir.startsWith(home + "/") ? "~" + dir.slice(home.length) : dir

    readonly property var schemes: [
        { id: "scheme-tonal-spot", label: "Tonal" },
        { id: "scheme-vibrant", label: "Vibrant" },
        { id: "scheme-expressive", label: "Expressive" },
        { id: "scheme-content", label: "Content" },
        { id: "scheme-fidelity", label: "Fidelity" },
        { id: "scheme-fruit-salad", label: "Fruit salad" },
        { id: "scheme-rainbow", label: "Rainbow" },
        { id: "scheme-neutral", label: "Neutral" },
        { id: "scheme-monochrome", label: "Mono" }
    ]

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

        // Prints the folder on the first line, then its images.
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
        `, "sh", root.userDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = text.split("\n").filter(l => l !== "");
                root.dir = list.shift() ?? "";
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

    // `gravity-shell ipc call theme set wallpaper|default`, `... theme scheme vibrant`
    IpcHandler {
        target: "theme"

        function set(mode: string): void {
            Config.setColors(mode);
        }

        function scheme(name: string): void {
            Config.setColorScheme(name.startsWith("scheme-") ? name : "scheme-" + name);
        }

        function get(): string {
            return Config.colors === "wallpaper" ? Config.colorScheme : "default";
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
        // Like the bar: accent pill when selected, tonal otherwise.
        color: selected ? Theme.gold : chipMouse.containsMouse ? Qt.lighter(Theme.tonal, 1.25) : Theme.tonal

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

            // Scene time and gravity offset for the floating cards.
            property real t: 0
            property point g: Qt.point(0, 0)

            readonly property string selected: root.files[carousel.currentIndex] ?? Config.wallpaperPath

            // Colours follow the selected wallpaper while browsing; back to the applied one
            // when the picker closes.
            Binding {
                target: Theme
                property: "previewPath"
                value: win.selected
                when: root.open
            }

            FrameAnimation {
                running: root.shown
                onTriggered: {
                    win.t += frameTime;
                    win.g = Gravity.active ? Gravity.offsetAt(Gravity.now()) : Qt.point(0, 0);
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

            function scroll(dir: int): void {
                if (dir > 0)
                    carousel.incrementCurrentIndex();
                else
                    carousel.decrementCurrentIndex();
                // Moving right swings things to the left, like a push.
                Gravity.kick(-dir * 0.7, -0.15, 0.8);
            }

            function apply(): void {
                root.setWallpaper(win.selected);
                root.open = false;
            }

            function syncIndex(): void {
                const i = root.files.indexOf(Config.wallpaperPath);
                if (i >= 0)
                    carousel.currentIndex = i;
            }

            // The open animation waits until the preview shows the current wallpaper, so it
            // starts as an exact copy of the desktop instead of an empty frame. Should the
            // image not load, it starts anyway after a moment.
            property bool started: false

            // Back to the start state each time it opens.
            function prepare(): void {
                openAnim.stop();
                closeAnim.stop();
                fade = 0;
                zoom = 0;
                rise = 0;
                started = false;
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
                            // Until the open animation starts, swap images without a fade.
                            instant: !win.started
                            onCurrentChanged: win.begin(false)
                            // Paused while the picker is hidden.
                            playing: root.shown
                            source: previewDelay.path
                            duration: Theme.normal
                            sourceSize: Qt.size(win.screen.width * win.screen.devicePixelRatio, win.screen.height * win.screen.devicePixelRatio)
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
                            selected: Config.colors !== "wallpaper"
                            onClicked: Config.setColors("default")
                        }

                        Chip {
                            label: "From wallpaper"
                            selected: Config.colors === "wallpaper"
                            onClicked: Config.setColors("wallpaper")
                        }

                        Rectangle {
                            visible: Config.colors === "wallpaper"
                            width: 1
                            height: 20
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.alpha(Theme.text, 0.2)
                        }

                        Repeater {
                            model: Config.colors === "wallpaper" ? root.schemes : []

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
                        visible: Config.colors === "wallpaper" && Theme.error !== ""
                        text: Theme.error + ", using the default colours"
                        color: Theme.rose
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.Bold
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

                    model: root.files
                    focus: true
                    // Seven on the path: three in view, two peeking, and one waiting off
                    // screen on each side to slide in.
                    pathItemCount: Math.min(7, root.files.length)
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
                            win.scroll(1);
                        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                            win.scroll(-1);
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                            win.apply();
                        } else if (event.key === Qt.Key_Escape) {
                            root.open = false;
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }

                    WheelHandler {
                        onWheel: event => {
                            const d = event.angleDelta.y !== 0 ? event.angleDelta.y : -event.angleDelta.x;
                            if (d !== 0)
                                win.scroll(d < 0 ? 1 : -1);
                        }
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
                        readonly property bool applied: modelData === Config.wallpaperPath

                        width: carousel.cardW
                        height: carousel.cardH
                        z: 10 - ad
                        scale: 1 - (1 - carousel.nearScale) * Math.min(ad, 1) - (carousel.nearScale - carousel.farScale) * Math.max(0, Math.min(ad, 2) - 1)
                        // The peeking cards are dimmed, and fade out as they leave the screen.
                        opacity: ad <= 1 ? 1 : ad <= 2 ? 1 - (ad - 1) * 0.35 : Math.max(0, 0.65 - (ad - 2) * 1.3)

                        // Each card bobs on its own and swings with the gravity field; while
                        // rising or falling it comes from below the screen.
                        rotation: Math.sin(win.t * 0.8 + index * 2.1) * 1.4 + win.g.x * 5
                        transform: Translate {
                            x: win.g.x * 26 * (1 + card.ad * 0.4)
                            y: Math.sin(win.t * 1.3 + card.index * 1.7) * carousel.cardH * 0.035 + win.g.y * 22 + (1 - card.p) * win.height * 0.6
                        }

                        RectangularShadow {
                            anchors.fill: parent
                            radius: cardFrame.radius
                            blur: 30
                            offset.y: 14 + Math.sin(win.t * 1.3 + card.index * 1.7) * 4
                            color: Qt.rgba(0, 0, 0, 0.5)
                        }

                        ClippingRectangle {
                            id: cardFrame

                            anchors.fill: parent
                            radius: 20
                            color: Theme.deep
                            border.width: card.middle ? 3 : 0
                            border.color: Theme.gold

                            // Videos play live on the three cards in view; the ones peeking
                            // in at the edges show their poster.
                            FadeImage {
                                anchors.fill: parent
                                source: card.modelData
                                sourceSize: Qt.size(480, 300)
                                duration: Theme.fast
                                live: card.ad < 1.5 && root.shown
                                playing: root.open
                            }
                        }

                        // A small gem marks the wallpaper that is set now.
                        Gem {
                            visible: card.applied
                            size: 16
                            spinning: false
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (card.middle)
                                    win.apply();
                                else
                                    win.scroll(card.d > 0 ? 1 : -1);
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
                        text: win.selected.split("/").pop()
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: (root.files.length <= 1 ? "Put images in " + root.prettyDir + " to see them here" : "←  →  browse    ·    Enter  apply    ·    Esc  close    ·    " + root.prettyDir)
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
