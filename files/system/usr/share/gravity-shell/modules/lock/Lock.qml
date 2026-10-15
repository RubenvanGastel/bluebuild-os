import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.services

// Lock state machine:
//   idle -> capturing  each screen is captured as it is now (windows and all)
//        -> locked     session lock engaged; the lock screen starts from that capture,
//                      so nothing jumps, then blurs it into the wallpaper behind the clock
//        -> unlocking  password accepted; everything runs back to the sharp capture
//        -> idle       session unlocked, the real desktop takes over
Scope {
    id: root

    property string phase: "idle"
    property string buffer: ""
    property string message: ""
    readonly property bool pamActive: pam.active

    readonly property int outroDuration: 520

    // Screen name -> grabToImage result of that screen just before locking. The result
    // objects own the images, so they're kept here until the lock is gone.
    property var captures: ({})

    signal failed

    function lock(): void {
        if (phase !== "idle")
            return;
        buffer = "";
        message = "";
        captures = {};
        Gravity.hold = true;
        phase = "capturing";
        captureTimeout.restart();
    }

    function addCapture(name: string, result: var): void {
        if (phase !== "capturing")
            return;
        const c = Object.assign({}, captures);
        c[name] = result;
        captures = c;
        if (Quickshell.screens.every(s => captures[s.name]))
            engage();
    }

    function engage(): void {
        if (phase !== "capturing")
            return;
        captureTimeout.stop();
        phase = "locked";
        sessionLock.locked = true;
    }

    // Without screencopy (or if it is slow), lock anyway; it then starts from the wallpaper.
    Timer {
        id: captureTimeout

        interval: 400
        onTriggered: root.engage()
    }

    // Before locking: a click-through overlay per screen showing a screencopy of it, which
    // looks exactly like the screen, so it is invisible. Its first frame is grabbed into an
    // image the lock surfaces can use.
    LazyLoader {
        active: root.phase === "capturing"

        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: grabber

                required property ShellScreen modelData

                screen: modelData
                color: "transparent"
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "gravity-lock-capture"
                mask: Region {}

                ScreencopyView {
                    id: copy

                    anchors.fill: parent
                    captureSource: grabber.modelData
                    live: false

                    onHasContentChanged: if (hasContent)
                        grabToImage(result => root.addCapture(grabber.modelData.name, result), Qt.size(grabber.modelData.width * grabber.modelData.devicePixelRatio, grabber.modelData.height * grabber.modelData.devicePixelRatio))
                }
            }
        }
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
            root.captures = {};
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
            return root.phase === "locked" || root.phase === "unlocking";
        }
    }
}
