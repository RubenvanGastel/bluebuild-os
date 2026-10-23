pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Audio spectrum from cava, for the visualiser in the bar and the media panel: `values`
// holds `bars` levels (0..1), low frequencies first, at Config.cavaFps frames a second.
// cava only runs while something is playing or the media panel is open (and for a little
// while after, so pausing and playing again doesn't restart it), so it costs nothing while
// it is quiet. Without cava installed the levels stay at 0.
Singleton {
    id: root

    readonly property int bars: 48
    property var values: zeros()
    // False when cava is missing or failed to start.
    property bool available: true

    readonly property bool wanted: Config.ready && (Playback.playing && Config.barMedia || Panels.media !== "")
    readonly property int fps: Math.max(10, Math.min(240, Config.cavaFps))

    function zeros(): var {
        return new Array(bars).fill(0);
    }

    // `count` levels from `values`, each the loudest of the bars it covers.
    function grouped(count: int): var {
        const out = [];
        const per = bars / count;
        for (let i = 0; i < count; i++) {
            let m = 0;
            for (let j = Math.floor(i * per); j < Math.floor((i + 1) * per); j++)
                m = Math.max(m, values[j] ?? 0);
            out.push(m);
        }
        return out;
    }

    onWantedChanged: {
        if (wanted) {
            stop.stop();
            if (!cava.running)
                restart.restart();
        } else {
            stop.restart();
        }
    }
    onFpsChanged: if (cava.running)
        restart.restart()

    // A setting and the playback state changing together start cava once.
    Timer {
        id: restart

        interval: 150
        onTriggered: {
            cava.running = false;
            if (root.wanted)
                cava.running = true;
        }
    }

    // Stops it once nothing has played for a while.
    Timer {
        id: stop

        interval: 10000
        onTriggered: cava.running = false
    }

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/gravity-shell"

    // Raw output, one frame per line as "level;level;...;" from 0 to 1000, mono. Its audio
    // stream asks PipeWire (through its PulseAudio server) for 60 ms buffers: cava's own
    // default is so small that PipeWire shrinks the buffers of everything playing when it
    // starts, and grows them back when it stops, and each switch can make the sound drop
    // out for a moment.
    Process {
        id: cava

        command: ["sh", "-c", `
            command -v cava >/dev/null || exit 127
            mkdir -p "$0" || exit 1
            cat > "$0/cava.conf" <<EOF
[general]
framerate = $1
bars = $2
autosens = 1

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
bar_delimiter = 59
frame_delimiter = 10
channels = mono
mono_option = average
EOF
            PULSE_LATENCY_MSEC=60 exec cava -p "$0/cava.conf"
        `, root.cacheDir, String(root.fps), String(root.bars)]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.split(";");
                const v = new Array(root.bars);
                for (let i = 0; i < root.bars; i++)
                    v[i] = (parseInt(parts[i]) || 0) / 1000;
                root.values = v;
            }
        }
        onStarted: root.available = true
        onExited: code => {
            if (code === 127)
                root.available = false;
            root.values = root.zeros();
        }
    }
}
