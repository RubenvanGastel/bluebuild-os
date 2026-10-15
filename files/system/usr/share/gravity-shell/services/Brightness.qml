pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen backlight. Reads the level from /sys/class/backlight and sets it through logind
// (org.freedesktop.login1.Session.SetBrightness), which works without root or extra tools.
// `gravity-shell ipc call brightness increase` / `decrease` (niri's brightness keys).
Singleton {
    id: root

    // Backlight device, e.g. "amdgpu_bl1"; empty when there is none (desktops).
    property string device: ""
    property int max: 0
    property int current: 0
    readonly property bool available: device !== "" && max > 0
    readonly property real level: available ? current / max : 0

    // Emitted when the level was changed from the shell, for the OSD.
    signal changed

    // Step in percent of the full range, with a floor so the screen never goes black.
    function step(percent: real): void {
        if (!available)
            return;
        const value = Math.round(Math.max(max * 0.01, Math.min(max, current + max * percent / 100)));
        current = value;
        set.value = value;
        set.running = true;
        changed();
    }

    Process {
        id: probe

        running: true
        command: ["sh", "-c", 'for d in /sys/class/backlight/*; do [ -e "$d/brightness" ] || continue; echo "$(basename "$d") $(cat "$d/max_brightness") $(cat "$d/brightness")"; break; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(" ");
                if (parts.length === 3) {
                    root.device = parts[0];
                    root.max = parseInt(parts[1]);
                    root.current = parseInt(parts[2]);
                }
            }
        }
    }

    // Picks up changes made elsewhere (e.g. the firmware) before the next step.
    Process {
        id: refresh

        command: ["cat", "/sys/class/backlight/" + root.device + "/brightness"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text);
                if (!isNaN(v) && !set.running)
                    root.current = v;
            }
        }
    }

    Process {
        id: set

        property int value

        command: ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session", "SetBrightness", "ssu", "backlight", root.device, String(value)]
        onExited: code => {
            if (code !== 0)
                console.warn("gravity: could not set the brightness");
        }
    }

    IpcHandler {
        target: "brightness"

        function increase(): void {
            root.step(5);
        }

        function decrease(): void {
            root.step(-5);
        }

        function get(): real {
            refresh.running = true;
            return root.level;
        }
    }
}
