import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.services

// Lock state machine:
//   idle -> locked     session lock engaged; the wallpaper blurs in behind the clock
//        -> unlocking  password accepted; the content fades and the blur clears
//        -> idle       session unlocked
Scope {
    id: root

    property string phase: "idle"
    property string buffer: ""
    property string message: ""
    readonly property bool pamActive: pam.active

    readonly property int outroDuration: 420

    signal failed

    function lock(): void {
        if (phase !== "idle")
            return;
        buffer = "";
        message = "";
        Gravity.hold = true;
        phase = "locked";
        sessionLock.locked = true;
    }

    function handleKey(event: var): void {
        if (phase !== "locked" || pam.active)
            return;
        message = "";
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (buffer.length > 0)
                pam.start();
        } else if (event.key === Qt.Key_Backspace) {
            buffer = event.modifiers & Qt.ControlModifier ? "" : buffer.slice(0, -1);
        } else if (event.key === Qt.Key_Escape) {
            buffer = "";
        } else if (event.text && /^[^\x00-\x1F\x7F]+$/.test(event.text)) {
            buffer += event.text;
        }
    }

    WlSessionLock {
        id: sessionLock

        LockSurface {
            lock: root
        }
    }

    PamContext {
        id: pam

        configDirectory: Quickshell.shellPath("pam")
        config: "gravity-lock"

        onResponseRequiredChanged: if (responseRequired)
            respond(root.buffer)

        onPamMessage: if (messageIsError)
            root.message = message

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.phase = "unlocking";
                unlockTimer.restart();
            } else {
                if (root.message === "")
                    root.message = "That's not it. Try again";
                root.buffer = "";
                root.failed();
            }
        }
    }

    // Let the outro play before the session lock lets go.
    Timer {
        id: unlockTimer

        interval: root.outroDuration
        onTriggered: {
            sessionLock.locked = false;
            root.phase = "idle";
            root.buffer = "";
            Gravity.hold = false;
        }
    }

    IdleMonitor {
        enabled: Config.idleLockMinutes > 0
        timeout: Config.idleLockMinutes * 60
        onIsIdleChanged: if (isIdle)
            root.lock()
    }

    // `gravity-shell lock` (bound to Super+Alt+L in niri).
    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }

        function isLocked(): bool {
            return root.phase !== "idle";
        }
    }
}
