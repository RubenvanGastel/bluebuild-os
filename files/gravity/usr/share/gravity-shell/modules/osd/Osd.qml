import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import qs.services

// On-screen display for volume, mic mute and brightness: a solid pill that rises from the
// bottom of the focused screen with a spring, shows an accent icon, a level slider that
// moves like the quick panel's, and the value, then drops away again when left alone.
Scope {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    // What is shown: "volume", "mic" or "brightness".
    property string kind: "volume"
    property real value: 0
    property bool muted: false

    // `shown` keeps the window up while it drops away after `open` goes false.
    property bool open: false
    property bool shown: false

    // PipeWire reports the current volume when it starts and when the default device
    // changes; those shouldn't pop up the OSD.
    property bool settled: false

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    function show(kind: string, value: real, muted: bool): void {
        // Not while the quick panel is open: its sliders already show the level.
        if (!settled || Panels.quick !== "")
            return;
        root.kind = kind;
        root.value = value;
        root.muted = muted;
        shown = true;
        open = true;
        hideTimer.restart();
    }

    Timer {
        id: settleTimer

        running: true
        interval: 1500
        onTriggered: root.settled = true
    }

    onSinkChanged: {
        settled = false;
        settleTimer.restart();
    }
    onSourceChanged: {
        settled = false;
        settleTimer.restart();
    }

    Connections {
        target: root.sink?.audio ?? null

        function onVolumeChanged(): void {
            root.show("volume", root.sink.audio.volume, root.sink.audio.muted);
        }

        function onMutedChanged(): void {
            root.show("volume", root.sink.audio.volume, root.sink.audio.muted);
        }
    }

    Connections {
        target: root.source?.audio ?? null

        function onMutedChanged(): void {
            root.show("mic", root.source.audio.volume, root.source.audio.muted);
        }
    }

    Connections {
        target: Brightness

        function onChanged(): void {
            root.show("brightness", Brightness.level, false);
        }
    }

    Timer {
        id: hideTimer

        interval: 1400
        onTriggered: root.open = false
    }

    // Nerd Font glyphs (Symbols Nerd Font, installed with the image).
    readonly property string icon: {
        if (kind === "brightness")
            return value < 0.34 ? "\u{f00de}" : value < 0.67 ? "\u{f00df}" : "\u{f00e0}";
        if (kind === "mic")
            return muted ? "\u{f036d}" : "\u{f036c}";
        if (muted || value <= 0.001)
            return "\u{f075f}";
        return value < 0.34 ? "\u{f057f}" : value < 0.67 ? "\u{f0580}" : "\u{f057e}";
    }
    readonly property string label: kind === "mic" ? (muted ? "Mic off" : "Mic on") : muted ? "Muted" : Math.round(value * 100) + "%"

    LazyLoader {
        active: root.shown

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === (Object.values(Niri.workspaces).find(w => w.is_focused)?.output ?? "")) ?? Quickshell.screens[0]
            color: "transparent"
            anchors.bottom: true
            margins.bottom: 40
            implicitWidth: pill.width + 48
            implicitHeight: pill.height + 48
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "gravity-osd"
            // Never takes clicks.
            mask: Region {}

            // 0..1: hidden below the screen edge .. in place.
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

            NumberAnimation {
                id: enter
                target: win
                property: "rise"
                to: 1
                duration: 460
                easing.type: Easing.OutBack
                easing.overshoot: 1.6
            }

            // Gravity takes it: it falls back down and is gone.
            SequentialAnimation {
                id: leave

                NumberAnimation {
                    target: win
                    property: "rise"
                    to: 0
                    duration: 320
                    easing.type: Easing.InQuad
                }
                ScriptAction {
                    script: root.shown = false
                }
            }

            Rectangle {
                id: pill

                anchors.horizontalCenter: parent.horizontalCenter
                y: 12 + (1 - win.rise) * (height + 60)
                opacity: Math.min(1, win.rise * 2)
                width: 340
                height: 60
                radius: height / 2
                color: Theme.surface

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.45)
                    shadowBlur: 0.6
                    shadowVerticalOffset: 4
                }

                // Icon in an accent circle; tonal when muted.
                Rectangle {
                    id: badge

                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 40
                    radius: 20
                    color: root.muted ? Theme.tonal : Theme.gold

                    // A little pop when the icon changes (crossing a volume or brightness
                    // step) or on muting, as in the quick panel.
                    Connections {
                        target: root

                        function onIconChanged(): void {
                            pop.restart();
                        }

                        function onMutedChanged(): void {
                            pop.restart();
                        }
                    }

                    SequentialAnimation {
                        id: pop

                        NumberAnimation {
                            target: badge
                            property: "scale"
                            to: 1.14
                            duration: 90
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: badge
                            property: "scale"
                            to: 1
                            duration: 420
                            easing.type: Easing.OutBack
                            easing.overshoot: 3
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.fast
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.icon
                        color: root.muted ? Theme.tonalInk : Theme.goldInk
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 20
                    }
                }

                // Level slider, as in the quick panel: the handle chases the level on a
                // spring with a little overshoot and leans the way it is going; each
                // change makes the track swell and the handle stretch for a moment. It
                // fills up from empty as the OSD rises, and drains as it drops away.
                Item {
                    id: slider

                    readonly property real f: win.rise > 0.6 ? Math.max(0, Math.min(1, root.value)) : 0
                    // Briefly true after each change, like the quick panel's slider under
                    // the pointer.
                    property bool active: false

                    // The level as drawn, springing after `f`.
                    property real shown: f

                    Behavior on shown {
                        SpringAnimation {
                            spring: 3.5
                            damping: 0.28
                            epsilon: 0.0005
                        }
                    }

                    Connections {
                        target: root

                        function onValueChanged(): void {
                            slider.bump();
                        }

                        function onMutedChanged(): void {
                            slider.bump();
                        }
                    }

                    function bump(): void {
                        active = true;
                        settle.restart();
                    }

                    Timer {
                        id: settle

                        interval: 420
                        onTriggered: slider.active = false
                    }

                    anchors.left: badge.right
                    anchors.leftMargin: 14
                    anchors.right: valueText.left
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    height: 40
                    visible: root.kind !== "mic"

                    readonly property real trackHeight: active ? 18 : 14

                    // Filled part, up to the handle.
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, handle.x - 4)
                        height: slider.trackHeight
                        radius: height / 2
                        color: root.muted ? Theme.textDim : Theme.gold

                        Behavior on height {
                            NumberAnimation {
                                duration: Theme.fast
                                easing.type: Easing.OutBack
                                easing.overshoot: 2
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.normal
                            }
                        }
                    }

                    // The rest, after the handle.
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: handle.x + handle.width + 4
                        width: Math.max(0, slider.width - x)
                        height: slider.trackHeight
                        radius: height / 2
                        color: Theme.tonal

                        Behavior on height {
                            NumberAnimation {
                                duration: Theme.fast
                                easing.type: Easing.OutBack
                                easing.overshoot: 2
                            }
                        }
                    }

                    Rectangle {
                        id: handle

                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(1, slider.shown)) * (slider.width - width)
                        width: slider.active ? 6 : 5
                        height: slider.active ? 34 : 28
                        radius: width / 2
                        color: root.muted ? Theme.textDim : Theme.gold
                        // Leans into the way it is moving: the further it lags behind the
                        // level, the more; it straightens (and wobbles past) as it settles.
                        rotation: Math.max(-22, Math.min(22, (slider.f - slider.shown) * 160))

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.fast
                            }
                        }
                        Behavior on height {
                            NumberAnimation {
                                duration: Theme.normal
                                easing.type: Easing.OutBack
                                easing.overshoot: 2.5
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.normal
                            }
                        }
                    }
                }

                Text {
                    id: valueText

                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.kind === "mic" ? parent.width - badge.width - 50 : 52
                    horizontalAlignment: root.kind === "mic" ? Text.AlignLeft : Text.AlignRight
                    text: root.label
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    // Pops a touch bigger on each change.
                    scale: slider.active ? 1.12 : 1
                    transformOrigin: root.kind === "mic" ? Item.Left : Item.Right

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.normal
                            easing.type: Easing.OutBack
                            easing.overshoot: 2
                        }
                    }
                }
            }
        }
    }
}
