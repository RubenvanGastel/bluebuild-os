import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services

// Overlay that bridges the desktop and the lock surface, so locking never cuts.
//
// mode "cover":  snapshot the desktop, show it 1:1, then let it float up and blur away
//                into the gravity scene. Ends looking exactly like a fresh lock surface.
// mode "reveal": created fresh while still locked, so its first frame matches the lock
//                surface. After the unlock it lets the desktop drop back into place.
PanelWindow {
    id: win

    required property ShellScreen modelData
    required property var lock
    required property string mode

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
    WlrLayershell.namespace: "gravity-lock-curtain"
    // Swallow keys during the transition so nothing types into the apps beneath.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property url snapshot: lock.snapshots[modelData.name] ?? ""

    // Everything we draw. In cover mode it stays invisible until the snapshot is ready.
    Item {
        id: stage

        anchors.fill: parent
        opacity: win.mode === "reveal" ? 1 : 0

        GravityScene {
            id: scene

            anchors.fill: parent
            ripples: false
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.night
            opacity: win.lock.dim
        }

        // The desktop, as a picture.
        Item {
            id: desk

            anchors.fill: parent
            opacity: win.mode === "cover" ? 1 : 0
            transformOrigin: Item.Center

            ScreencopyView {
                id: live

                anchors.fill: parent
                visible: win.mode === "cover"
                captureSource: win.mode === "cover" ? win.modelData : null
                onHasContentChanged: if (hasContent && win.mode === "cover")
                    win.snapshotReady()
            }

            Image {
                anchors.fill: parent
                visible: win.mode === "reveal"
                source: win.mode === "reveal" ? win.snapshot : ""
                asynchronous: false
                cache: false
            }

            property real blur: 0
            layer.enabled: blur > 0
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                blurEnabled: true
                blurMax: 48
                blur: desk.blur
            }
        }
    }

    function snapshotReady(): void {
        if (coverAnim.running || win.lock.phase !== "covering")
            return;
        stage.opacity = 1;
        live.grabToImage(result => win.lock.storeSnapshot(win.modelData.name, result));
        coverAnim.start();
    }

    // No screencopy support: just fade the scene in.
    Timer {
        running: win.mode === "cover"
        interval: 280
        onTriggered: if (!coverAnim.running && stage.opacity === 0) {
            desk.opacity = 0;
            coverAnim.start();
        }
    }

    ParallelAnimation {
        id: coverAnim

        onFinished: win.lock.coverDone()

        NumberAnimation {
            target: stage
            property: "opacity"
            to: 1
            duration: 260
        }
        NumberAnimation {
            target: desk
            property: "y"
            to: -win.height * 0.14
            duration: win.lock.coverDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.depart
        }
        NumberAnimation {
            target: desk
            property: "scale"
            to: 0.9
            duration: win.lock.coverDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.depart
        }
        NumberAnimation {
            target: desk
            property: "rotation"
            to: -1.5
            duration: win.lock.coverDuration
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: desk
            property: "blur"
            to: 1
            duration: win.lock.coverDuration * 0.7
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: desk
            property: "opacity"
            to: 0
            duration: win.lock.coverDuration
            easing.type: Easing.InQuad
        }
    }

    // Starts as soon as the session is unlocked and this curtain is on screen.
    SequentialAnimation {
        id: revealAnim

        running: win.mode === "reveal" && win.lock.phase === "revealing"
        onFinished: win.lock.revealDone()

        ScriptAction {
            script: {
                desk.y = -win.height * 0.14;
                desk.scale = 0.9;
                desk.rotation = -1.5;
                desk.blur = 1;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: desk
                property: "opacity"
                to: win.snapshot.toString() !== "" ? 1 : 0
                duration: win.lock.revealDuration * 0.6
                easing.type: Easing.OutQuad
            }
            // Gravity returns: the desktop falls back into place and settles.
            NumberAnimation {
                target: desk
                property: "y"
                to: 0
                duration: win.lock.revealDuration
                easing.type: Easing.OutBack
                easing.overshoot: 0.9
            }
            NumberAnimation {
                target: desk
                property: "scale"
                to: 1
                duration: win.lock.revealDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.settle
            }
            NumberAnimation {
                target: desk
                property: "rotation"
                to: 0
                duration: win.lock.revealDuration
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: desk
                property: "blur"
                to: 0
                duration: win.lock.revealDuration * 0.8
                easing.type: Easing.OutCubic
            }
            // Without a snapshot the scene simply dissolves.
            NumberAnimation {
                target: stage
                property: "opacity"
                to: win.snapshot.toString() !== "" ? 1 : 0
                duration: win.lock.revealDuration
                easing.type: Easing.InQuad
            }
        }
        // Cross-fade the (slightly stale) picture into the live desktop beneath.
        NumberAnimation {
            target: stage
            property: "opacity"
            to: 0
            duration: 200
        }
    }
}
