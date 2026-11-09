pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Monitors: the ones connected, as niri sees them (`niri msg --json outputs`, read again
// whenever udev says one came or went), and niri's output config for them from the
// settings, which Theme writes into niri's include (niriConfig). Per monitor (by make,
// model and serial, so settings follow it from port to port): its mode, a custom mode or
// modeline, scale and VRR. Per set of monitors connected together: extend, mirror, only
// the built-in one or only the others, and where each is. A monitor or set never seen
// before gets niri's defaults: on, in its preferred mode, to the right of the others.
// Changes that can leave a screen dark revert after `confirmTime` unless kept.
Singleton {
    id: root

    // Connected outputs by connector name, as niri reports them, on or off.
    property var outputs: ({})
    // False until niri has been asked once, so the config isn't written without them.
    property bool ready: false

    // Built-in first, then by connector.
    readonly property var list: Object.values(outputs).sort((a, b) => (isInternal(b.name) - isInternal(a.name)) || a.name.localeCompare(b.name))
    readonly property var internal: list.filter(o => isInternal(o.name))
    readonly property var external: list.filter(o => !isInternal(o.name))
    // Mirror and "only" need a built-in and another monitor.
    readonly property bool both: internal.length > 0 && external.length > 0

    // The set connected now, and how it is used.
    readonly property string layoutKey: list.map(o => key(o)).sort().join(" + ")
    readonly property var layout: Config.displayLayouts[layoutKey] ?? ({})
    readonly property string mode: both && ["extend", "mirror", "internal", "external"].includes(layout.mode) ? layout.mode : "extend"

    // Outputs showing a mirror of the built-in one: no bar of their own there.
    readonly property var mirrors: mode === "mirror" && hasMirror ? external.map(o => o.name) : []
    property bool hasMirror: false

    function isInternal(name: string): bool {
        return /^(eDP|LVDS|DSI)-/i.test(name);
    }

    // niri's "make model serial".
    function key(o: var): string {
        return [o.make, o.model, o.serial].map(v => v || "Unknown").join(" ");
    }

    // How niri's config names it: make, model and serial, or the connector when another
    // connected monitor has the same ones.
    function matchName(o: var): string {
        return list.filter(p => key(p) === key(o)).length > 1 ? o.name : key(o);
    }

    function label(o: var): string {
        if (isInternal(o.name))
            return I18n.tr("Built-in display");
        return o.model && o.model !== "Unknown" ? o.model : o.make && o.make !== "Unknown" ? o.make : o.name;
    }

    function settingsOf(o: var): var {
        return Config.displays[key(o)] ?? {};
    }

    function enabled(o: var): bool {
        return mode === "internal" ? isInternal(o.name) : mode === "external" ? !isInternal(o.name) : true;
    }

    // "WxH@Hz" as niri writes it, to three decimals.
    function modeName(m: var): string {
        return `${m.width}x${m.height}@${(m.refresh_rate / 1000).toFixed(3)}`;
    }

    // The scale niri gives it when none is set (as Mutter does): the quarter step from 1 to
    // 4 closest to its pixel density over 135 dpi (110 from 20" up), keeping at least
    // 800×480 logical pixels. 1 when its size is unknown. For a mode of `w`×`h`.
    function autoScale(o: var, w: int, h: int): real {
        const [mmW, mmH] = o.physical_size ?? [0, 0];
        if (!mmW || !mmH || !w || !h)
            return 1;
        const inches = Math.hypot(mmW, mmH) / 25.4;
        const perfect = Math.hypot(w, h) / inches / (inches < 20 ? 135 : 110);
        let best = 1, bestDistance = Infinity;
        for (let step = 4; step <= 16; step++) {
            const s = step / 4;
            if (Math.round(w / s) * Math.round(h / s) < 800 * 480)
                continue;
            if (Math.abs(s - perfect) < bestDistance) {
                best = s;
                bestDistance = Math.abs(s - perfect);
            }
        }
        return best;
    }

    // The custom mode chosen for it, if any.
    function customOf(o: var): var {
        const s = settingsOf(o);
        const at = /^custom:(\d+)$/.exec(s.mode ?? "");
        return at ? (s.customModes ?? [])[Number(at[1])] ?? null : null;
    }

    // The custom mode as a modeline: given, or worked out with GTF (which CRTs expect).
    // Null for niri's own CVT timings.
    function modelineOf(c: var): string {
        if (c.timing === "modeline")
            return parseModeline(c.modeline) ? c.modeline.trim() : "";
        if (c.timing === "gtf")
            return gtf(c.width, c.height, c.refresh);
        return "";
    }

    // A modeline's numbers and sync polarities, as niri takes them, or null:
    // clock hdisp hsyncstart hsyncend htotal vdisp vsyncstart vsyncend vtotal, then
    // +hsync/-hsync and +vsync/-vsync (an X11 "Modeline name" in front is left out).
    function parseModeline(text: string): var {
        const parts = (text ?? "").replace(/^\s*modeline\s+("[^"]*"\s+)?/i, "").replace(/"/g, "").trim().split(/\s+/);
        if (parts.length < 11)
            return null;
        const n = parts.slice(0, 9).map(Number);
        const h = parts[9].toLowerCase(), v = parts[10].toLowerCase();
        if (n.some(x => !isFinite(x) || x <= 0) || !["+hsync", "-hsync"].includes(h) || !["+vsync", "-vsync"].includes(v))
            return null;
        if (!(n[1] < n[2] && n[2] < n[3] && n[3] < n[4] && n[5] < n[6] && n[6] < n[7] && n[7] < n[8]))
            return null;
        return { numbers: n, hsync: h, vsync: v };
    }

    // Rounds halves to even, as gtf's rint does.
    function rint(x: real): real {
        const r = Math.round(x);
        return Math.abs(x % 1) === 0.5 && r % 2 !== 0 ? r - 1 : r;
    }

    // VESA GTF timings, as the gtf tool works them out (progressive, no margins).
    function gtf(w: int, h: int, hz: real): string {
        const gran = 8, porch = 1, vsync = 3, minSyncBackPorch = 550;
        const c = (40 - 20) * 128 / 256 + 20, m = 128 / 256 * 600;
        const hPixels = rint(w / gran) * gran;
        const hPeriodEst = (1 / hz - minSyncBackPorch / 1e6) / (h + porch) * 1e6;
        const vSyncBackPorch = rint(minSyncBackPorch / hPeriodEst);
        const vTotal = h + vSyncBackPorch + porch;
        const hPeriod = hPeriodEst / (hz / (1 / hPeriodEst / vTotal * 1e6));
        const duty = c - m * hPeriod / 1000;
        const hBlank = rint(hPixels * duty / (100 - duty) / (2 * gran)) * 2 * gran;
        const hTotal = hPixels + hBlank;
        const hSync = rint(0.08 * hTotal / gran) * gran;
        const hFront = hBlank / 2 - hSync;
        return `${(hTotal / hPeriod).toFixed(2)} ${hPixels} ${hPixels + hFront} ${hPixels + hFront + hSync} ${hTotal} ${h} ${h + porch} ${h + porch + vsync} ${vTotal} -hsync +vsync`;
    }

    function quote(s: string): string {
        return '"' + s.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
    }

    // niri's output config for the monitors connected now (empty for niri's defaults).
    readonly property string niriConfig: {
        const blocks = [];
        for (const o of list) {
            const s = settingsOf(o);
            const lines = [];
            if (!enabled(o)) {
                lines.push("off");
            } else {
                const c = customOf(o);
                const line = c ? modelineOf(c) : "";
                if (line) {
                    const p = parseModeline(line);
                    lines.push(`modeline ${p.numbers.join(" ")} "${p.hsync}" "${p.vsync}"`);
                } else if (c) {
                    lines.push(`mode custom=true "${c.width}x${c.height}@${c.refresh}"`);
                } else if (s.mode && o.modes.some(m => modeName(m) === s.mode)) {
                    lines.push(`mode "${s.mode}"`);
                }
                if (s.scale > 0)
                    lines.push(`scale ${s.scale}`);
                const at = (layout.positions ?? {})[key(o)];
                if (mode === "extend" && at)
                    lines.push(`position x=${Math.round(at.x)} y=${Math.round(at.y)}`);
                if (s.vrr === "on")
                    lines.push("variable-refresh-rate");
                else if (s.vrr === "on-demand")
                    lines.push("variable-refresh-rate on-demand=true");
            }
            if (lines.length)
                blocks.push(`output ${quote(matchName(o))} {\n${lines.map(l => "    " + l).join("\n")}\n}`);
        }
        return blocks.length ? "// Displays (gravity-shell Settings > Displays).\n" + blocks.join("\n") + "\n" : "";
    }

    // --- arranging them ----------------------------------------------------------------

    // The size it will have in niri's layout with these settings: its mode (or custom
    // mode) over its scale (or the one niri would pick), turned with it. Exact: niri rounds
    // the size it reports, and a fraction of a pixel too close counts as overlapping.
    function sizeWith(o: var, s: var): var {
        const at = /^custom:(\d+)$/.exec(s.mode ?? "");
        const c = at ? (s.customModes ?? [])[Number(at[1])] : null;
        const named = !at && s.mode ? o.modes.find(m => modeName(m) === s.mode) : null;
        const m = c ?? named ?? o.modes.find(m => m.is_preferred) ?? o.modes[0];
        if (!m)
            return { w: o.logical?.width ?? 0, h: o.logical?.height ?? 0 };
        const scale = s.scale > 0 ? s.scale : autoScale(o, m.width, m.height);
        const turned = /90|270/.test(o.logical?.transform ?? "");
        return { w: (turned ? m.height : m.width) / scale, h: (turned ? m.width : m.height) / scale };
    }

    // The monitors that are on, where niri has them, at their exact size.
    readonly property var rects: list.filter(o => enabled(o) && o.logical).map(o => {
            const m = o.modes[o.current_mode ?? -1];
            const scale = o.logical.scale || 1;
            const turned = /90|270/.test(o.logical.transform);
            return {
                key: key(o),
                name: o.name,
                label: label(o),
                x: o.logical.x,
                y: o.logical.y,
                w: m ? (turned ? m.height : m.width) / scale : o.logical.width,
                h: m ? (turned ? m.width : m.height) / scale : o.logical.height
            };
        })

    function overlaps(a: var, b: var): bool {
        const e = 0.01;
        return a.x < b.x + b.w - e && b.x < a.x + a.w - e && a.y < b.y + b.h - e && b.y < a.y + a.h - e;
    }

    // Sharing a stretch of an edge, which the pointer can cross.
    function touching(a: var, b: var): bool {
        const sideBySide = (Math.abs(a.x + a.w - b.x) <= 1 || Math.abs(b.x + b.w - a.x) <= 1) && a.y < b.y + b.h - 1 && b.y < a.y + a.h - 1;
        const stacked = (Math.abs(a.y + a.h - b.y) <= 1 || Math.abs(b.y + b.h - a.y) <= 1) && a.x < b.x + b.w - 1 && b.x < a.x + a.w - 1;
        return sideBySide || stacked;
    }

    // Along the side it touches: lined up with the other's start, end or middle when within
    // reach, otherwise at `at`, still sharing a stretch of that side.
    function along(at: real, size: real, start: real, length: real): real {
        const reach = Math.max(30, Math.min(size, length) * 0.12);
        for (const want of [start, start + length - size, start + (length - size) / 2])
            if (Math.abs(at - want) < reach)
                return Math.round(want);
        const share = Math.min(size, length) * 0.15;
        return Math.round(Math.max(start - size + share, Math.min(at, start + length - share)));
    }

    // The free spot nearest (x, y) for `a` against one of `others`: whole pixels, rounded
    // away from the one it touches. Where it is if there is none.
    function snapTo(a: var, x: real, y: real, others: var): var {
        let best = null, bestDistance = Infinity;
        for (const b of others) {
            const spots = [
                { x: Math.ceil(b.x + b.w), y: along(y, a.h, b.y, b.h) },
                { x: Math.floor(b.x - a.w), y: along(y, a.h, b.y, b.h) },
                { x: along(x, a.w, b.x, b.w), y: Math.ceil(b.y + b.h) },
                { x: along(x, a.w, b.x, b.w), y: Math.floor(b.y - a.h) }
            ];
            for (const spot of spots) {
                const placed = { x: spot.x, y: spot.y, w: a.w, h: a.h };
                if (others.some(o => overlaps(placed, o)))
                    continue;
                const distance = Math.hypot(spot.x - x, spot.y - y);
                if (distance < bestDistance) {
                    best = spot;
                    bestDistance = distance;
                }
            }
        }
        return best ?? { x: Math.round(a.x), y: Math.round(a.y) };
    }

    // Puts monitors that no longer touch the others, or overlap them (after one changed
    // size), back against them, nearest first; `anchor` (a connector) stays where it is.
    // `sizes` gives sizes by key that are about to change. The positions, or null when
    // nothing needs to move.
    function repacked(anchor: string, sizes: var): var {
        const all = rects.map(r => Object.assign({}, r, sizes[r.key] ?? {}));
        if (mode !== "extend" || all.length < 2)
            return null;
        const first = all.find(r => r.name === anchor) ?? all[0];
        const placed = [first];
        let moved = false;
        const rest = all.filter(r => r !== first);
        while (rest.length) {
            // The one nearest to those placed goes next.
            rest.sort((a, b) => Math.min(...placed.map(p => Math.hypot(a.x - p.x, a.y - p.y))) - Math.min(...placed.map(p => Math.hypot(b.x - p.x, b.y - p.y))));
            const r = rest.shift();
            if (placed.some(p => touching(r, p)) && !placed.some(p => overlaps(r, p))) {
                placed.push(r);
                continue;
            }
            placed.push(Object.assign({}, r, snapTo(r, r.x, r.y, placed)));
            moved = true;
        }
        if (!moved)
            return null;
        const positions = {};
        for (const p of placed)
            positions[p.key] = { x: Math.round(p.x), y: Math.round(p.y) };
        return positions;
    }

    // The monitor with the pointer (niri's focused one), which keeps its place.
    readonly property string focusedOutput: Object.values(Niri.workspaces).find(w => w.is_focused)?.output ?? ""

    // A safety net for sizes that changed some other way (a monitor's own, or niri placing
    // one itself): once niri has them, any that came loose go back. Reverting a change
    // also takes these positions back, as they are part of it.
    // Saved positions that overlap at the sizes the monitors have are ones niri turned
    // down (placing them itself): where niri put them is saved instead.
    onRectsChanged: Qt.callLater(() => {
        const positions = root.repacked(root.focusedOutput, {});
        if (positions) {
            root.setPositions(positions);
            return;
        }
        const saved = root.layout.positions ?? {};
        const placedAsSaved = root.rects.map(r => Object.assign({}, r, saved[r.key] ?? {}));
        if (root.mode === "extend" && placedAsSaved.some((a, i) => placedAsSaved.some((b, j) => i < j && root.overlaps(a, b)))) {
            const actual = {};
            for (const r of root.rects)
                actual[r.key] = { x: r.x, y: r.y };
            root.setPositions(actual);
        }
    })

    // --- changing them ------------------------------------------------------------------

    // While a change waits to be kept: the settings from before it, and the seconds left.
    property bool confirming: false
    property var backup: null
    property int countdown: 0
    readonly property int confirmTime: 15

    // Makes a change that may leave a screen dark or out of range; it reverts unless kept.
    function risky(change: var): void {
        if (!confirming)
            backup = { displays: Config.displays, displayLayouts: Config.displayLayouts };
        change();
        confirming = true;
        countdown = confirmTime;
        tick.restart();
    }

    function keep(): void {
        confirming = false;
        backup = null;
        tick.stop();
    }

    function revert(): void {
        if (backup) {
            Config.set("displays", backup.displays);
            Config.set("displayLayouts", backup.displayLayouts);
        }
        keep();
    }

    Timer {
        id: tick

        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown--;
            if (root.countdown <= 0)
                root.revert();
        }
    }

    function setLayout(patch: var): void {
        Config.set("displayLayouts", Object.assign({}, Config.displayLayouts, { [layoutKey]: Object.assign({}, layout, patch) }));
    }

    function setMode(m: string): void {
        if (m !== mode)
            risky(() => setLayout({ mode: m }));
    }

    // Where each monitor is, by key, in logical pixels.
    function setPositions(positions: var): void {
        setLayout({ positions: positions });
    }

    // A change of mode or scale changes its size: the others move with it in the same go,
    // so niri never finds them overlapping (and places them elsewhere itself).
    function setDisplay(o: var, patch: var): void {
        const next = Object.assign({}, settingsOf(o), patch);
        const positions = "mode" in patch || "scale" in patch || "customModes" in patch ? repacked(focusedOutput, { [key(o)]: sizeWith(o, next) }) : null;
        Config.set("displays", Object.assign({}, Config.displays, { [key(o)]: next }));
        if (positions)
            setPositions(positions);
    }

    // Mode ("WxH@Hz", "custom:<n>" or "" for its preferred one) and scale may not show.
    function setDisplayRisky(o: var, patch: var): void {
        risky(() => setDisplay(o, patch));
    }

    // A custom mode ({ width, height, refresh, timing: "cvt", "gtf" or "modeline",
    // modeline }), which is then used.
    function addCustomMode(o: var, c: var): void {
        const modes = [...(settingsOf(o).customModes ?? []), c];
        risky(() => setDisplay(o, { customModes: modes, mode: "custom:" + (modes.length - 1) }));
    }

    function removeCustomMode(o: var, index: int): void {
        const s = settingsOf(o);
        const modes = (s.customModes ?? []).filter((_, i) => i !== index);
        const at = /^custom:(\d+)$/.exec(s.mode ?? "");
        let mode = s.mode ?? "";
        if (at && Number(at[1]) === index)
            mode = "";
        else if (at && Number(at[1]) > index)
            mode = "custom:" + (Number(at[1]) - 1);
        const change = () => setDisplay(o, { customModes: modes, mode: mode });
        if (mode !== (s.mode ?? ""))
            risky(change);
        else
            change();
    }

    // `gravity-shell ipc call displays mode extend` (or mirror, internal, external) for a
    // keybind; keep and revert answer the prompt without a pointer, as when a screen went
    // dark.
    IpcHandler {
        target: "displays"

        function mode(m: string): void {
            if (["extend", "mirror", "internal", "external"].includes(m))
                root.setMode(m);
        }
        function get(): string {
            return root.mode;
        }
        function keep(): void {
            root.keep();
        }
        function revert(): void {
            root.revert();
        }
    }

    // --- following niri ---------------------------------------------------------------

    function refresh(): void {
        query.running = false;
        query.running = true;
    }

    Process {
        id: query

        command: ["niri", "msg", "--json", "outputs"]
        stdout: StdioCollector {
            id: queryOut
        }
        onExited: code => {
            if (code !== 0)
                return;
            try {
                const data = JSON.parse(queryOut.text);
                if (JSON.stringify(data) !== JSON.stringify(root.outputs))
                    root.outputs = data;
                root.ready = true;
            } catch (e) {}
        }
    }

    Component.onCompleted: {
        refresh();
        mirrorCheck.running = true;
    }

    // A monitor plugged in or out: niri takes a moment to set it up, so twice.
    Process {
        id: hotplug

        running: true
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=drm"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("change") || line.includes("add") || line.includes("remove")) {
                    soon.restart();
                    later.restart();
                }
            }
        }
        onExited: hotplugRestart.start()
    }

    Timer {
        id: hotplugRestart

        interval: 5000
        onTriggered: hotplug.running = true
    }

    Timer {
        id: soon

        interval: 700
        onTriggered: root.refresh()
    }

    Timer {
        id: later

        interval: 2500
        onTriggered: root.refresh()
    }

    // niri applies a new config (and monitors switching on or off) with the screens Qt
    // sees following; ask again for the modes and positions it settled on.
    onNiriConfigChanged: later.restart()

    Connections {
        target: Quickshell

        function onScreensChanged(): void {
            soon.restart();
        }
    }

    // Mirroring: wl-mirror shows the built-in display fullscreen on each other monitor.
    Process {
        id: mirrorCheck

        command: ["sh", "-c", "command -v wl-mirror"]
        onExited: code => root.hasMirror = code === 0
    }

    Variants {
        model: root.mirrors

        Process {
            id: mirror

            required property string modelData

            running: root.internal.length > 0
            command: ["wl-mirror", "--fullscreen-output", modelData, root.internal[0]?.name ?? ""]
            // It quits when its output goes away for a moment; back while still mirroring.
            onExited: if (root.mirrors.includes(modelData))
                restart.start()

            property Timer restart: Timer {
                interval: 1500
                onTriggered: mirror.running = true
            }
        }
    }
}
