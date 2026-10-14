import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.services

// Lock state machine:
//   idle -> covering   curtain snapshots the desktop and lets it float away
//        -> locked     session lock engaged; digits fall into place
//        -> unlocking  password accepted; content floats off, scene time freezes,
//                      fresh reveal curtains render that frozen frame
//        -> revealing  session unlocked under the curtain; desktop drops back in
//        -> idle
Scope {
    id: root

    property string phase: "idle"
    property string buffer: ""
    property string message: ""
    property real fall: 0
    readonly property bool pamActive: pam.active
    // Snapshot of each screen taken just before locking: name -> grab result url.
    property var snapshots: ({})
    property var grabs: ({})

    readonly property real dim: 0.28
    readonly property int coverDuration: 820
    readonly property int outroDuration: 520
    readonly property int revealDuration: 760

    signal failed

    function lock(): void {
        if (phase !== "idle")
            return;
        buffer = "";
        message = "";
        snapshots = {};
        grabs = {};
        Gravity.hold = true;
        phase = "covering";
        coverFallback.restart();
    }

    function storeSnapshot(screen: string, result: var): void {
        // Keep the grab result alive; its url is only valid as long as it exists.
        grabs = Object.assign({}, grabs, { [screen]: result });
        snapshots = Object.assign({}, snapshots, { [screen]: result.url });
    }

    function coverDone(): void {
        if (phase !== "covering")
            return;
        coverFallback.stop();
        sessionLock.locked = true;
    }

    function revealDone(): void {
        if (phase !== "revealing")
            return;
        phase = "idle";
        buffer = "";
        snapshots = {};
        grabs = {};
        Gravity.hold = false;
    }

    function handleKey(event: var): void {
        if (phase !== "locked" || pam.active || fall > 0)
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

        onSecureChanged: if (secure && root.phase === "covering")
            root.phase = "locked"

        LockSurface {
            lock: root
        }
    }

    // Cover curtains exist while covering; reveal curtains from the moment the password
    // is accepted until the desktop is back.
    Variants {
        model: root.phase === "covering" ? Quickshell.screens : []

        Curtain {
            lock: root
            mode: "cover"
        }
    }

    Variants {
        model: root.phase === "unlocking" || root.phase === "revealing" ? Quickshell.screens : []

        Curtain {
            lock: root
            mode: "reveal"
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
                // Freeze the scene so the lock surface and the fresh curtains agree.
                Gravity.freeze();
                unlockTimer.restart();
            } else {
                if (root.message === "")
                    root.message = "That's not it. Try again";
                root.failed();
                dropGems.restart();
            }
        }
    }

    // Wrong password: the gems tumble out of the sky, then the field clears.
    SequentialAnimation {
        id: dropGems

        NumberAnimation {
            target: root
            property: "fall"
            from: 0
            to: 1
            duration: 750
            easing.type: Easing.InQuad
        }
        ScriptAction {
            script: {
                root.buffer = "";
                root.fall = 0;
            }
        }
    }

    // Give the outro time to play and the reveal curtains time to draw their first frame.
    Timer {
        id: unlockTimer

        interval: root.outroDuration + 60
        onTriggered: {
            sessionLock.locked = false;
            Gravity.thaw();
            root.phase = "revealing";
            revealFallback.restart();
        }
    }

    // Safety nets: never get stuck halfway.
    Timer {
        id: coverFallback
        interval: 2500
        onTriggered: root.coverDone()
    }

    Timer {
        id: revealFallback
        interval: root.revealDuration + 1500
        onTriggered: root.revealDone()
    }

    IdleMonitor {
        enabled: Config.idleLockMinutes > 0
        timeout: Config.idleLockMinutes * 60
        onIsIdleChanged: if (isIdle)
            root.lock()
    }

    // `qs -c gravity ipc call lock lock` (or `gravity-shell lock`) from niri keybinds.
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
