import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// IPC for keybinds: `gravity-shell ipc call volume increase`, `... powerProfile cycle`.
Scope {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real step: 0.05

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    function changeVolume(delta: real): void {
        const audio = sink?.audio;
        if (!sink?.ready || !audio)
            return;
        audio.muted = false;
        // Up to 100%; the bar's scroll wheel can still go beyond that.
        audio.volume = Math.max(0, Math.min(1, Math.round((audio.volume + delta) * 100) / 100));
    }

    IpcHandler {
        target: "volume"

        function increase(): void {
            root.changeVolume(root.step);
        }

        function decrease(): void {
            root.changeVolume(-root.step);
        }

        function muteOutput(): void {
            if (root.sink?.audio)
                root.sink.audio.muted = !root.sink.audio.muted;
        }

        function muteInput(): void {
            if (root.source?.audio)
                root.source.audio.muted = !root.source.audio.muted;
        }

        function get(): real {
            return root.sink?.audio?.volume ?? 0;
        }
    }

    // Power saver -> balanced -> performance (when the hardware has it) -> power saver.
    IpcHandler {
        target: "powerProfile"

        function cycle(): void {
            switch (PowerProfiles.profile) {
            case PowerProfile.PowerSaver:
                PowerProfiles.profile = PowerProfile.Balanced;
                break;
            case PowerProfile.Balanced:
                PowerProfiles.profile = PowerProfiles.hasPerformanceProfile ? PowerProfile.Performance : PowerProfile.PowerSaver;
                break;
            default:
                PowerProfiles.profile = PowerProfile.PowerSaver;
            }
        }

        function get(): string {
            return PowerProfile.toString(PowerProfiles.profile);
        }
    }
}
