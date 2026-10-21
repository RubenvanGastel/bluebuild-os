import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services

// Keybind cheatsheet (`gravity-shell ipc call keybinds toggle`, Mod+F1).
// Read from the `binds` block of the niri config each time it opens: every comment after a
// blank line starts a category ("// Window focus"), and a bind shows its
// hotkey-overlay-title, or else its action ("Focus column left"); hotkey-overlay-title=null
// hides one, like in niri's own overlay. Runs like Mod+1..9 collapse into one row.
// The screen dims and a card springs up from below with every category in one view, as
// blocks spread over balanced columns. Esc or a click outside closes.
Scope {
    id: root

    // `shown` keeps the window up while the card drops away after `open` goes false.
    property bool open: false
    property bool shown: false
    property var targetScreen: Quickshell.screens[0]

    // [{ name, icon, binds: [{ keys: ["Mod", "Shift", "Q"], text }] }]
    property var categories: []

    // Sizes of a category block, shared by the column layout and the blocks themselves.
    readonly property int blockPad: 12
    readonly property int headerHeight: 36
    readonly property int rowHeight: 30
    readonly property int gap: 12

    function blockHeight(category: var): int {
        return blockPad * 2 + headerHeight + category.binds.length * rowHeight;
    }

    // Splits the categories, in order, over at most `count` columns so that the tallest
    // column is as short as it can be (the linear partition problem; a few dozen
    // categories at most, so trying every split is instant).
    function columns(count: int): var {
        const n = categories.length;
        const k = Math.max(1, Math.min(count, n));
        // prefix[i]: height of the first i blocks stacked.
        const prefix = [0];
        for (const c of categories)
            prefix.push(prefix[prefix.length - 1] + blockHeight(c) + gap);
        // best[j][i]: tallest column when the first i blocks go into j columns; cut[j][i]:
        // where the last of those columns starts.
        const best = [prefix.map(() => Infinity)];
        const cut = [[]];
        best[0][0] = 0;
        for (let j = 1; j <= k; j++) {
            best.push([]);
            cut.push([]);
            for (let i = 0; i <= n; i++) {
                best[j][i] = Infinity;
                for (let s = 0; s <= i; s++) {
                    const h = Math.max(best[j - 1][s], prefix[i] - prefix[s]);
                    if (h < best[j][i]) {
                        best[j][i] = h;
                        cut[j][i] = s;
                    }
                }
            }
        }
        const cols = [];
        let end = n;
        for (let j = k; j > 0; j--) {
            const start = cut[j][end];
            cols.unshift(categories.slice(start, end).map((c, i) => Object.assign({ order: start + i }, c)));
            end = start;
        }
        return cols.filter(c => c.length > 0);
    }

    function toggle(): void {
        if (open) {
            open = false;
            return;
        }
        Panels.closeQuick();
        Panels.closeTray();
        Panels.closeMonitor();
        Panels.closeBattery();
        targetScreen = Quickshell.screens.find(s => s.name === (Object.values(Niri.workspaces).find(w => w.is_focused)?.output ?? "")) ?? Quickshell.screens[0];
        // Re-read, so edits to the config show up; until then the last read stays.
        reader.running = true;
        shown = true;
        open = true;
    }

    // Icons for the category names in the stock config; anything else gets a keyboard.
    function iconFor(name: string): string {
        const n = name.toLowerCase();
        const icons = [
            [/move.*workspace/, "\u{f0054}"],
            [/workspace/, "\u{f0570}"],
            [/monitor|output|screen/, "\u{f0379}"],
            [/resiz|size|width|height/, "\u{f004c}"],
            [/state|layout/, "\u{f056e}"],
            [/mov/, "\u{f0041}"],
            [/focus/, "\u{f04fe}"],
            [/media|audio|volume|bright/, "\u{f057e}"],
            [/system|session|power/, "\u{f0425}"],
            [/shell|widget/, "\u{f072c}"],
            [/app/, "\u{f003b}"]
        ];
        return icons.find(([re]) => re.test(n))?.[1] ?? "\u{f030c}";
    }

    // niri key names as they read on a keycap.
    readonly property var keyNames: ({
            mod: "Super",
            ctrl: "Ctrl",
            control: "Ctrl",
            shift: "Shift",
            alt: "Alt",
            super: "Super",
            win: "Super",
            iso_level3_shift: "AltGr",
            return: "Enter",
            escape: "Esc",
            delete: "Del",
            backspace: "Backspace",
            print: "PrtSc",
            left: "←",
            right: "→",
            up: "↑",
            down: "↓",
            page_up: "PgUp",
            page_down: "PgDn",
            prior: "PgUp",
            next: "PgDn",
            bracketleft: "[",
            bracketright: "]",
            minus: "−",
            equal: "=",
            plus: "+",
            comma: ",",
            period: ".",
            slash: "/",
            backslash: "\\",
            semicolon: ";",
            apostrophe: "'",
            grave: "`",
            wheelscrollup: "Scroll ↑",
            wheelscrolldown: "Scroll ↓",
            wheelscrollleft: "Scroll ←",
            wheelscrollright: "Scroll →",
            touchpadscrollup: "Swipe ↑",
            touchpadscrolldown: "Swipe ↓",
            touchpadscrollleft: "Swipe ←",
            touchpadscrollright: "Swipe →",
            xf86audioraisevolume: "Volume +",
            xf86audiolowervolume: "Volume −",
            xf86audiomute: "Mute",
            xf86audiomicmute: "Mic mute",
            xf86monbrightnessup: "Brightness +",
            xf86monbrightnessdown: "Brightness −",
            xf86audioprev: "Previous",
            xf86audionext: "Next"
        })

    function keyName(key: string): string {
        const name = keyNames[key.toLowerCase()];
        if (name)
            return name;
        if (key.length === 1)
            return key.toUpperCase();
        // XF86AudioPlay -> Play
        return key.replace(/^XF86(Audio|Mon)?/i, "").replace(/([a-z])([A-Z])/g, "$1 $2");
    }

    function unquote(s: string): string {
        if (!s.startsWith("\""))
            return s;
        try {
            return JSON.parse(s);
        } catch (e) {
            return s.slice(1, -1);
        }
    }

    // One bind node, e.g. `Mod+Q hotkey-overlay-title="Close Window" { close-window; }`.
    // Returns { key, text }, or null for a hidden bind or a line that isn't one.
    function parseBind(node: string): var {
        const brace = node.search(/\{(?=(?:[^"]*"[^"]*")*[^"]*$)/);
        const close = node.lastIndexOf("}");
        if (brace < 0 || close < brace)
            return null;
        const head = node.slice(0, brace).trim();
        const key = head.split(/\s+/)[0];
        const title = head.match(/hotkey-overlay-title=(null|"(?:[^"\\]|\\.)*")/);
        if (title?.[1] === "null")
            return null;
        if (title)
            return { key, text: unquote(title[1]) };

        // No title: describe the action, the way niri's overlay does.
        const tokens = (node.slice(brace + 1, close).match(/"(?:[^"\\]|\\.)*"|[^\s;]+/g) ?? [])
            .filter(t => t.startsWith("\"") || !t.includes("="))
            .map(unquote);
        if (tokens.length === 0)
            return null;
        const [action, ...args] = tokens;
        const verb = action === "spawn" || action === "spawn-sh" ? "Run" : action.charAt(0).toUpperCase() + action.slice(1).replace(/-/g, " ");
        return { key, text: [verb, ...args].join(" ") };
    }

    // Mod+1 "Focus workspace 1" ... Mod+9 "Focus workspace 9" -> Mod+1–9 "Focus workspace 1–9".
    function collapseRuns(binds: var): var {
        const out = [];
        let i = 0;
        while (i < binds.length) {
            const a = binds[i];
            const keyDigit = a.key.match(/^(.*?)(\d)$/);
            const textDigit = a.text.match(/^(.*?)(\d)$/);
            let j = i + 1;
            if (keyDigit && textDigit && keyDigit[2] === textDigit[2]) {
                while (j < binds.length) {
                    const d = String(Number(keyDigit[2]) + j - i);
                    if (binds[j].key !== keyDigit[1] + d || binds[j].text !== textDigit[1] + d)
                        break;
                    j++;
                }
            }
            if (j - i >= 3) {
                const range = keyDigit[2] + "–" + binds[j - 1].key.slice(-1);
                out.push({ key: keyDigit[1] + range, text: textDigit[1] + range });
            } else {
                j = i + 1;
                out.push(a);
            }
            i = j;
        }
        return out;
    }

    function parse(text: string): void {
        const found = [];
        let category = null;
        let inBinds = false;
        let afterBlank = true;
        // A bind spread over several lines is gathered until its braces close.
        let node = "";
        let depth = 0;

        for (const raw of text.split("\n")) {
            const line = raw.trim();
            if (!inBinds) {
                inBinds = /^binds\s*\{/.test(line);
                continue;
            }
            if (depth === 0) {
                if (line === "}")
                    break;
                if (line === "") {
                    afterBlank = true;
                    continue;
                }
                if (line.startsWith("//")) {
                    if (afterBlank) {
                        category = { name: line.replace(/^\/\/+\s*/, ""), binds: [] };
                        found.push(category);
                    }
                    afterBlank = false;
                    continue;
                }
                afterBlank = false;
                // "/-" comments out the node.
                if (line.startsWith("/-"))
                    continue;
            }
            node += " " + line.replace(/\/\/.*$/, "");
            const bare = line.replace(/"(?:[^"\\]|\\.)*"/g, "");
            depth += (bare.match(/\{/g) ?? []).length - (bare.match(/\}/g) ?? []).length;
            if (depth > 0)
                continue;
            depth = 0;
            const bind = parseBind(node.trim());
            node = "";
            if (!bind)
                continue;
            if (!category) {
                category = { name: "Keybinds", binds: [] };
                found.push(category);
            }
            category.binds.push(bind);
        }

        categories = found.filter(c => c.binds.length > 0).map(c => ({
                    name: c.name,
                    icon: iconFor(c.name),
                    binds: collapseRuns(c.binds).map(b => ({
                            keys: b.key.split("+").filter(k => k !== "").map(keyName),
                            text: b.text
                        }))
                }));
    }

    // niri reads $NIRI_CONFIG, else ~/.config/niri/config.kdl, else /etc/niri/config.kdl.
    Process {
        id: reader

        running: true
        command: ["sh", "-c", "f=\"${NIRI_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl}\"; [ -f \"$f\" ] || f=/etc/niri/config.kdl; cat \"$f\""]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    IpcHandler {
        target: "keybinds"

        function toggle(): void {
            root.toggle();
        }
    }

    LazyLoader {
        active: root.shown

        PanelWindow {
            id: win

            screen: root.targetScreen
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "gravity-keybinds"
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // 0..1: the screen dimming, and the card from below the edge to in place.
            property real fade: 0
            property real rise: 0

            Component.onCompleted: enter.start()

            Connections {
                target: root

                function onOpenChanged(): void {
                    if (root.open) {
                        leave.stop();
                        enter.start();
                    } else {
                        enter.stop();
                        leave.start();
                    }
                }
            }

            ParallelAnimation {
                id: enter

                NumberAnimation {
                    target: win
                    property: "fade"
                    to: 1
                    duration: Theme.normal
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: win
                    property: "rise"
                    to: 1
                    duration: 520
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.3
                }
            }

            // Gravity takes it: the card falls away and the screen brightens again.
            SequentialAnimation {
                id: leave

                ParallelAnimation {
                    NumberAnimation {
                        target: win
                        property: "rise"
                        to: 0
                        duration: 300
                        easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                        target: win
                        property: "fade"
                        to: 0
                        duration: 300
                        easing.type: Easing.InQuad
                    }
                }
                ScriptAction {
                    script: root.shown = false
                }
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.night
                opacity: 0.6 * win.fade
            }

            // A click outside the card closes.
            MouseArea {
                anchors.fill: parent
                onClicked: root.open = false
            }

            Rectangle {
                id: card

                readonly property int pad: 28
                // As many columns of at least 340 px as fit.
                readonly property int columnCount: Math.max(1, Math.floor((width - pad * 2 + root.gap) / (340 + root.gap)))
                readonly property real columnWidth: (width - pad * 2 - root.gap * (columnCount - 1)) / columnCount

                anchors.horizontalCenter: parent.horizontalCenter
                y: (parent.height - height) / 2 + (1 - win.rise) * (parent.height / 2 + height)
                opacity: Math.min(1, win.rise * 2)
                width: Math.min(parent.width - 96, 1760)
                height: Math.min(parent.height - 96, title.height + 20 + grid.height + pad * 2)
                radius: 40
                color: Theme.surface

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.45)
                    shadowBlur: 0.8
                    shadowVerticalOffset: 6
                }

                // Swallows clicks on the card itself, so they don't close it.
                MouseArea {
                    anchors.fill: parent
                }

                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_F1 || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.open = false;
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_PageDown) {
                        scroller.flick(0, -1500);
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_PageUp) {
                        scroller.flick(0, 1500);
                    } else {
                        return;
                    }
                    event.accepted = true;
                }

                Text {
                    id: title

                    x: card.pad + 8
                    y: card.pad
                    text: root.categories.length > 0 ? "Keybinds" : "No keybinds found in the niri config"
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 24
                    font.weight: Font.Bold
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: card.pad + 8
                    anchors.baseline: title.baseline
                    text: "Esc closes"
                    color: Theme.textDim
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }

                // Only scrolls when the binds don't fit on the screen.
                Flickable {
                    id: scroller

                    x: card.pad
                    anchors.top: title.bottom
                    anchors.topMargin: 20
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: card.pad
                    width: card.width - card.pad * 2
                    contentHeight: grid.height
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Row {
                        id: grid

                        spacing: root.gap

                        Repeater {
                            model: root.columns(card.columnCount)

                            Column {
                                id: column

                                required property var modelData

                                width: card.columnWidth
                                spacing: root.gap

                                Repeater {
                                    model: column.modelData

                                    // One category: a tonal block with its name and binds.
                                    Rectangle {
                                        id: block

                                        required property var modelData

                                        width: card.columnWidth
                                        height: root.blockHeight(modelData)
                                        radius: 24
                                        color: Theme.deep

                                        // The blocks rise one after another, as if each feels
                                        // the pull a moment later.
                                        transform: Translate {
                                            y: (1 - Math.max(0, Math.min(1, win.rise * 1.6 - block.modelData.order * 0.05))) * 40
                                        }

                                        Row {
                                            x: root.blockPad + 6
                                            y: root.blockPad
                                            height: root.headerHeight
                                            spacing: 10

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: block.modelData.icon
                                                color: Theme.gold
                                                font.family: "Symbols Nerd Font"
                                                font.pixelSize: 18
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: block.modelData.name
                                                textFormat: Text.PlainText
                                                color: Theme.text
                                                font.family: Theme.font
                                                font.pixelSize: 16
                                                font.weight: Font.Bold
                                            }
                                        }

                                        Column {
                                            x: root.blockPad
                                            y: root.blockPad + root.headerHeight

                                            Repeater {
                                                model: block.modelData.binds

                                                Item {
                                                    id: bind

                                                    required property var modelData

                                                    width: card.columnWidth - root.blockPad * 2
                                                    height: root.rowHeight

                                                    Text {
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: 6
                                                        anchors.right: caps.left
                                                        anchors.rightMargin: 10
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: bind.modelData.text
                                                        textFormat: Text.PlainText
                                                        elide: Text.ElideRight
                                                        color: Theme.textDim
                                                        font.family: Theme.font
                                                        font.pixelSize: 14
                                                        font.weight: Font.Bold
                                                    }

                                                    // A keycap per key: the modifiers quiet, the
                                                    // key itself tonal.
                                                    Row {
                                                        id: caps

                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 4

                                                        Repeater {
                                                            model: bind.modelData.keys

                                                            Rectangle {
                                                                id: cap

                                                                required property string modelData
                                                                required property int index
                                                                readonly property bool main: index === bind.modelData.keys.length - 1

                                                                width: Math.max(height, capText.implicitWidth + 14)
                                                                height: 24
                                                                radius: 9
                                                                color: main ? Theme.tonal : Theme.dusk

                                                                Text {
                                                                    id: capText

                                                                    anchors.centerIn: parent
                                                                    text: cap.modelData
                                                                    textFormat: Text.PlainText
                                                                    color: cap.main ? Theme.tonalInk : Theme.textDim
                                                                    font.family: Theme.font
                                                                    font.pixelSize: 12
                                                                    font.weight: Font.Bold
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
