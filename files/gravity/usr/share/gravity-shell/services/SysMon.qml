pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory and temperatures, for the monitor pill in the bar and its panel.
// The bar only needs CPU and memory use: /proc once a second, which is cheap. The panel's
// details (temperatures, GPU, clock speeds, the busiest processes) are only gathered
// while it is open (`detailed`).
Singleton {
    id: root

    // Set while the monitor panel is open.
    property bool detailed: false

    // --- CPU -------------------------------------------------------------------------
    property real cpu: 0
    // Per core, 0..1.
    property var cores: []
    property string cpuModel: ""
    // Average clock speed in MHz (detailed only).
    property real cpuFreq: 0

    // --- memory (kB, as /proc/meminfo has it) --------------------------------------
    property real memTotal: 0
    property real memAvailable: 0
    property real memCached: 0
    property real swapTotal: 0
    property real swapFree: 0
    readonly property real memUsed: memTotal - memAvailable
    readonly property real mem: memTotal > 0 ? memUsed / memTotal : 0
    readonly property real swap: swapTotal > 0 ? (swapTotal - swapFree) / swapTotal : 0

    // --- temperatures (°C) -----------------------------------------------------------
    property real cpuTemp: 0
    // Every sensor, as [{ name, temp }] (detailed only), and fans as [{ name, rpm }].
    property var temps: []
    property var fans: []

    // --- GPU (when the driver tells) -------------------------------------------------
    property real gpu: -1
    property real vramUsed: 0
    property real vramTotal: 0

    // --- the rest (detailed only) ----------------------------------------------------
    property var loadAvg: [0, 0, 0]
    property real uptime: 0
    // The busiest processes: [{ name, cpu (percent of one core), mem (kB) }].
    property var processes: []

    // The last minute, a sample a second, oldest first.
    readonly property int historyLength: 60
    property var cpuHistory: []
    property var memHistory: []

    // A temperature this high is shown as hot.
    readonly property real hot: 85

    // Found once at start: sensor files and what they are.
    property string cpuTempPath: ""
    property var sensors: []
    property var fanPaths: []
    property string gpuDir: ""

    function gib(kb: real): string {
        return (kb / 1048576).toFixed(1) + " GiB";
    }

    function push(list: var, v: real): var {
        const l = list.concat([v]);
        return l.length > historyLength ? l.slice(l.length - historyLength) : l;
    }

    // Previous /proc/stat totals, per line, for the use since the last sample.
    property var lastStat: ({})

    function parseStat(text: string): void {
        const prev = lastStat;
        const next = {};
        const cores = [];
        let all = cpu;
        for (const line of text.split("\n")) {
            if (!line.startsWith("cpu"))
                continue;
            const f = line.trim().split(/\s+/);
            const name = f[0];
            const n = f.slice(1, 9).map(Number);
            const idle = n[3] + n[4];
            const total = n.reduce((a, b) => a + b, 0);
            next[name] = { idle, total };
            const p = prev[name];
            const use = p && total > p.total ? 1 - (idle - p.idle) / (total - p.total) : 0;
            if (name === "cpu")
                all = use;
            else
                cores.push(Math.max(0, Math.min(1, use)));
        }
        lastStat = next;
        cpu = Math.max(0, Math.min(1, all));
        root.cores = cores;
        cpuHistory = push(cpuHistory, cpu);
    }

    function parseMeminfo(text: string): void {
        const m = {};
        for (const line of text.split("\n")) {
            const r = /^(\w+):\s+(\d+)/.exec(line);
            if (r)
                m[r[1]] = Number(r[2]);
        }
        memTotal = m.MemTotal ?? 0;
        memAvailable = m.MemAvailable ?? 0;
        memCached = (m.Cached ?? 0) + (m.Buffers ?? 0) + (m.SReclaimable ?? 0);
        swapTotal = m.SwapTotal ?? 0;
        swapFree = m.SwapFree ?? 0;
        memHistory = push(memHistory, mem);
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 1000
        onTriggered: {
            stat.reload();
            meminfo.reload();
            // Only the panel shows these.
            if (!root.detailed)
                return;
            if (root.cpuTempPath !== "")
                cpuTempFile.reload();
            if (root.gpuDir !== "")
                gpuBusy.reload();
        }
    }

    // Fresh figures as soon as the panel opens, not up to a second later.
    onDetailedChanged: if (detailed) {
        if (cpuTempPath !== "")
            cpuTempFile.reload();
        if (gpuDir !== "")
            gpuBusy.reload();
    }

    // The details take a moment (top samples for a while), so every two seconds.
    Timer {
        running: root.detailed
        repeat: true
        triggeredOnStart: true
        interval: 2000
        onTriggered: details.running = true
    }

    FileView {
        id: stat

        path: "/proc/stat"
        onLoaded: root.parseStat(text())
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
        onLoaded: root.parseMeminfo(text())
    }

    FileView {
        id: cpuTempFile

        path: root.cpuTempPath
        printErrors: false
        onLoaded: root.cpuTemp = parseInt(text()) / 1000
    }

    FileView {
        id: gpuBusy

        path: root.gpuDir !== "" ? root.gpuDir + "/gpu_busy_percent" : ""
        printErrors: false
        onLoaded: root.gpu = parseInt(text()) / 100
    }

    // Lists the temperature sensors and fans (hwmon), the GPU that reports its load, and
    // the CPU model.
    Process {
        running: true
        command: ["sh", "-c", `
            for h in /sys/class/hwmon/hwmon*; do
                n=$(cat "$h/name" 2>/dev/null)
                for t in "$h"/temp*_input; do
                    [ -r "$t" ] || continue
                    printf 'temp\\t%s\\t%s\\t%s\\n' "$n" "$(cat "\${t%_input}_label" 2>/dev/null)" "$t"
                done
                for f in "$h"/fan*_input; do
                    [ -r "$f" ] && printf 'fan\\t%s\\t\\t%s\\n' "$n" "$f"
                done
            done
            for g in /sys/class/drm/card*/device; do
                [ -r "$g/gpu_busy_percent" ] && { printf 'gpu\\t\\t\\t%s\\n' "$g"; break; }
            done
            printf 'model\\t%s\\n' "$(sed -n 's/^model name[[:space:]]*:[[:space:]]*//p' /proc/cpuinfo | head -n 1)"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const sensors = [];
                const fans = [];
                // Readable names; the CPU sensor is the package/die one.
                const names = { k10temp: "CPU", zenpower: "CPU", coretemp: "CPU", cpu_thermal: "CPU", amdgpu: "GPU", nouveau: "GPU", radeon: "GPU", i915: "GPU", xe: "GPU", nvme: "SSD", spd5118: "RAM", jc42: "RAM", acpitz: "Board", iwlwifi_1: "Wi-Fi" };
                const cpuLabels = ["Tctl", "Tdie", "Package id 0", ""];
                let cpuPick = null;
                for (const line of text.split("\n")) {
                    const [kind, hw, label, path] = line.split("\t");
                    if (kind === "model") {
                        root.cpuModel = hw.replace(/\s+w\/.*$/, "").replace(/\s+\d+-Core Processor$/, "").trim();
                    } else if (kind === "gpu") {
                        root.gpuDir = path;
                    } else if (kind === "fan") {
                        // Some laptops show the same fans through two drivers: one is enough.
                        if (fans.length === 0 || fans[0].hw === hw)
                            fans.push({ hw, path });
                    } else if (kind === "temp") {
                        const base = names[hw] ?? (/^(mt7|iwl|ath)/.test(hw) ? "Wi-Fi" : hw);
                        if (base === "CPU" && cpuLabels.includes(label) && (!cpuPick || cpuLabels.indexOf(label) < cpuLabels.indexOf(cpuPick.label)))
                            cpuPick = { label, path };
                        // One per device: its main reading, the first one.
                        if (/temp1_input$/.test(path))
                            sensors.push({ name: base, path });
                    }
                }
                if (!cpuPick) {
                    const acpi = sensors.find(s => s.name === "Board");
                    if (acpi)
                        cpuPick = { path: acpi.path };
                }
                // The interesting ones first.
                const order = ["CPU", "GPU", "RAM", "SSD", "Wi-Fi", "Board"];
                const rank = s => order.includes(s.name) ? order.indexOf(s.name) : order.length;
                sensors.sort((x, y) => rank(x) - rank(y));
                // Several of a kind (two SSDs) get numbered.
                for (const s of sensors) {
                    const same = sensors.filter(o => o.name === s.name);
                    if (same.length > 1)
                        s.label = s.name + " " + (same.indexOf(s) + 1);
                }
                root.sensors = sensors.map(s => ({ name: s.label ?? s.name, path: s.path }));
                root.fanPaths = fans.map(f => f.path);
                root.cpuTempPath = cpuPick?.path ?? "";
            }
        }
    }

    // Sensors, fans, clock speeds, load, uptime and the busiest processes. top takes two
    // samples so its CPU figures are for now, not averaged since each process started.
    Process {
        id: details

        command: ["sh", "-c", `
            for f in "$@"; do echo "s $(cat "$f" 2>/dev/null)"; done
            echo "f $(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null | awk '{ s += $1; n++ } END { if (n) print s / n / 1000 }')"
            echo "l $(cat /proc/loadavg)"
            echo "u $(cut -d' ' -f1 /proc/uptime)"
            [ -n "$GPU" ] && echo "v $(cat "$GPU/mem_info_vram_used" 2>/dev/null) $(cat "$GPU/mem_info_vram_total" 2>/dev/null)"
            # Memory from ps: top abbreviates big figures that don't fit its column.
            top -b -n 2 -d 0.7 -w 512 -o %CPU | awk '/^ *PID/ { n++; next } n == 2 && NF >= 12 && $12 != "top" { print $1, $9, $12; if (++c == 5) exit }' |
                while read -r pid cpu name; do echo "p $cpu $(ps -o rss= -p "$pid" | tr -d ' ') $name"; done
        `, "sh", ...root.sensors.map(s => s.path), ...root.fanPaths]
        environment: ({ GPU: root.gpuDir, LC_ALL: "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                const temps = [];
                const fans = [];
                const procs = [];
                let i = 0;
                for (const line of text.split("\n")) {
                    const f = line.split(" ");
                    switch (f[0]) {
                    case "s": {
                        const v = parseInt(f[1]);
                        if (i < root.sensors.length) {
                            if (!isNaN(v))
                                temps.push({ name: root.sensors[i].name, temp: v / 1000 });
                        } else if (!isNaN(v)) {
                            fans.push({ name: "Fan " + (fans.length + 1), rpm: v });
                        }
                        i++;
                        break;
                    }
                    case "f":
                        root.cpuFreq = parseFloat(f[1]) || 0;
                        break;
                    case "l":
                        root.loadAvg = f.slice(1, 4).map(Number);
                        break;
                    case "u":
                        root.uptime = parseFloat(f[1]) || 0;
                        break;
                    case "v":
                        root.vramUsed = (parseFloat(f[1]) || 0) / 1024;
                        root.vramTotal = (parseFloat(f[2]) || 0) / 1024;
                        break;
                    case "p":
                        procs.push({ name: f.slice(3).join(" "), cpu: parseFloat(f[1]) || 0, mem: parseFloat(f[2]) || 0 });
                        break;
                    }
                }
                root.temps = temps;
                root.fans = fans;
                root.processes = procs;
            }
        }
    }
}
