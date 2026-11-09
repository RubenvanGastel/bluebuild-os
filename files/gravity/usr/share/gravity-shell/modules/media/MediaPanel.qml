import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.services

// Media panel, opened from the visualiser beside the clock (or `gravity-shell ipc call media
// toggle`). Like the battery panel it is the bar growing into the screen under its pill:
// the album art with the title, artist and album, a large visualiser, where the track is
// (drag to seek), the controls (shuffle, previous, play/pause, next, repeat) and, with more
// than one player, which one to follow. Esc or a click outside closes.
Scope {
    id: root

    readonly property bool open: Panels.media !== ""
    // Keeps the window up while the card goes away after closing.
    property bool shown: false
    // Screen it is on; kept while closing, when Panels.media is already empty.
    property string screenName: ""

    onOpenChanged: if (open) {
        screenName = Panels.media;
        shown = true;
    }

    readonly property MprisPlayer player: Playback.player

    // MPRIS doesn't send the position as it moves; ask for it while the panel shows.
    Timer {
        interval: 500
        repeat: true
        running: root.open && Playback.playing
        onTriggered: root.player?.positionChanged()
    }

    LazyLoader {
        active: root.shown

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === root.screenName) ?? Quickshell.screens[0]
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "gravity-media"
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            // Click-through while it goes away.
            mask: root.open ? null : passThrough
            // The panel's surface is see-through with blur on; niri blurs behind it.
            BackgroundEffect.blurRegion: Theme.blur ? sheet.blurRegion : null

            Region {
                id: passThrough
            }

            // The bar's surface growing into the panel, and the contents showing in it once
            // there is room. As the battery panel.
            property real grow: 0
            property real reveal: 0

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

            ParallelAnimation {
                id: enter

                NumberAnimation {
                    target: win
                    property: "grow"
                    to: 1
                    duration: 420
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.emphasized
                }
                SequentialAnimation {
                    PauseAnimation {
                        duration: 140
                    }
                    NumberAnimation {
                        target: win
                        property: "reveal"
                        to: 1
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // The reverse: the contents go first, then the surface pulls back.
            SequentialAnimation {
                id: leave

                ParallelAnimation {
                    NumberAnimation {
                        target: win
                        property: "reveal"
                        to: 0
                        duration: 120
                        easing.type: Easing.InQuad
                    }
                    SequentialAnimation {
                        PauseAnimation {
                            duration: 60
                        }
                        NumberAnimation {
                            target: win
                            property: "grow"
                            to: 0
                            duration: 280
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.depart
                        }
                    }
                }
                ScriptAction {
                    script: root.shown = false
                }
            }

            // Click anywhere else to close.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: Panels.closeMedia()
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: Panels.closeMedia()
                Keys.onSpacePressed: root.player?.togglePlaying()
            }

            // Centred on the pill (just past the middle of the bar without it), kept clear
            // of the bar's ends.
            BarSheet {
                id: sheet

                anchors.fill: parent
                at: Panels.mediaAt >= 0 ? Panels.mediaAt : length / 2 + 120
                fullWidth: 460
                fullHeight: content.implicitHeight + 40
                grow: win.grow

                Column {
                    id: content

                    x: 20
                    y: 20 - (1 - win.reveal) * 10
                    opacity: win.reveal
                    width: parent.width - 40
                    spacing: 16

                    // --- the track ---------------------------------------------------------
                    Item {
                        width: parent.width
                        height: 112

                        ClippingRectangle {
                            id: art

                            width: 112
                            height: 112
                            radius: 22
                            color: Theme.tonal

                            Text {
                                anchors.centerIn: parent
                                visible: cover.status !== Image.Ready
                                text: "\u{f075a}"
                                color: Theme.tonalInk
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 44
                            }

                            Image {
                                id: cover

                                anchors.fill: parent
                                source: root.player?.trackArtUrl ?? ""
                                sourceSize: Qt.size(224, 224)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                opacity: status === Image.Ready ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.normal
                                    }
                                }
                            }
                        }

                        Column {
                            anchors.left: art.right
                            anchors.leftMargin: 16
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Text {
                                width: parent.width
                                text: root.player?.identity ?? ""
                                visible: text !== ""
                                elide: Text.ElideRight
                                color: Theme.gold
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }

                            Text {
                                width: parent.width
                                text: root.player ? (root.player.trackTitle || I18n.tr("Unknown title")) : I18n.tr("Nothing playing")
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                                elide: Text.ElideRight
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 20
                                font.weight: Font.Bold
                            }

                            Text {
                                width: parent.width
                                text: root.player?.trackArtist ?? ""
                                visible: text !== ""
                                elide: Text.ElideRight
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }

                            Text {
                                width: parent.width
                                text: root.player?.trackAlbum ?? ""
                                visible: text !== ""
                                elide: Text.ElideRight
                                color: Theme.textDim
                                font.family: Theme.font
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }
                        }
                    }

                    // --- the visualiser ------------------------------------------------------
                    Rectangle {
                        width: parent.width
                        height: 150
                        radius: 20
                        color: Theme.deep

                        Canvas {
                            id: spectrum

                            anchors.fill: parent
                            anchors.margins: 14

                            Connections {
                                target: Cava

                                function onValuesChanged(): void {
                                    if (root.open)
                                        spectrum.requestPaint();
                                }
                            }
                            Connections {
                                target: Theme

                                function onGoldChanged(): void {
                                    spectrum.requestPaint();
                                }
                            }

                            Connections {
                                target: Config

                                function onVisualizerStyleChanged(): void {
                                    spectrum.requestPaint();
                                }
                            }

                            // Standing on a baseline about three quarters down, the accent
                            // fading to the tertiary colour at the top, with a faint
                            // reflection under the line. Config.visualizerStyle draws rounded
                            // bars, one smooth wave through their tops, or columns of dots
                            // lit from the baseline up (the rest faint).
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                const v = Cava.values;
                                const n = v.length;
                                const gap = 3;
                                const w = (width - gap * (n - 1)) / n;
                                const base = height * 0.74;
                                const grad = ctx.createLinearGradient(0, 0, 0, base);
                                grad.addColorStop(0, Theme.amber);
                                grad.addColorStop(1, Theme.gold);
                                const level = i => Math.max(0, Math.min(1, v[i]));
                                const alpha = Playback.playing ? 1 : 0.4;
                                const shine = Playback.playing ? 0.18 : 0.08;

                                if (Config.visualizerStyle === "wave") {
                                    // The tops of the bars, with curves between the midpoints.
                                    const pts = [];
                                    for (let i = 0; i < n; i++)
                                        pts.push([i * (w + gap) + w / 2, base - Math.max(2, level(i) * base)]);
                                    const outline = scaleY => {
                                        ctx.beginPath();
                                        ctx.moveTo(0, base);
                                        ctx.lineTo(0, base - (base - pts[0][1]) * scaleY);
                                        for (let i = 0; i < n - 1; i++)
                                            ctx.quadraticCurveTo(pts[i][0], base - (base - pts[i][1]) * scaleY, (pts[i][0] + pts[i + 1][0]) / 2, base - (base - (pts[i][1] + pts[i + 1][1]) / 2) * scaleY);
                                        ctx.lineTo(width, base - (base - pts[n - 1][1]) * scaleY);
                                        ctx.lineTo(width, base);
                                        ctx.closePath();
                                    };
                                    ctx.globalAlpha = alpha;
                                    ctx.fillStyle = grad;
                                    outline(1);
                                    ctx.fill();
                                    // The reflection: the same shape flipped under the line,
                                    // squashed to a third.
                                    ctx.save();
                                    ctx.translate(0, 2 * base + 4);
                                    ctx.scale(1, -1);
                                    ctx.beginPath();
                                    ctx.rect(0, base - (height - base - 4), width, height - base - 4);
                                    ctx.clip();
                                    ctx.globalAlpha = shine;
                                    ctx.fillStyle = Theme.gold;
                                    outline(0.3);
                                    ctx.fill();
                                    ctx.restore();
                                    return;
                                }

                                for (let i = 0; i < n; i++) {
                                    const h = Math.max(w, level(i) * base);
                                    const x = i * (w + gap);
                                    const r = w / 2;
                                    if (Config.visualizerStyle === "dots") {
                                        // Round dots a bar wide, a gap apart, lit up to the level.
                                        const step = w + gap;
                                        const lit = Math.max(1, Math.round(level(i) * base / step));
                                        for (let d = 0; d < Math.floor(base / step); d++) {
                                            ctx.globalAlpha = d < lit ? alpha : shine;
                                            ctx.fillStyle = d < lit ? grad : Theme.gold;
                                            ctx.beginPath();
                                            ctx.arc(x + r, base - r - d * step, r, 0, 2 * Math.PI);
                                            ctx.fill();
                                        }
                                        continue;
                                    }
                                    ctx.globalAlpha = alpha;
                                    ctx.fillStyle = grad;
                                    ctx.beginPath();
                                    ctx.roundedRect(x, base - h, w, h, r, r);
                                    ctx.fill();
                                    ctx.globalAlpha = shine;
                                    ctx.fillStyle = Theme.gold;
                                    ctx.beginPath();
                                    ctx.roundedRect(x, base + 4, w, Math.min(height - base - 4, h * 0.3), r, r);
                                    ctx.fill();
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !Cava.available
                            text: I18n.tr("cava is not installed")
                            color: Theme.textDim
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                    }

                    // --- where the track is ----------------------------------------------------
                    Column {
                        width: parent.width
                        spacing: 4
                        visible: root.player !== null && root.player.lengthSupported && root.player.length > 0

                        Item {
                            id: seek

                            readonly property real length: root.player?.length ?? 0
                            readonly property real f: drag.pressed ? drag.f : length > 0 ? Math.max(0, Math.min(1, (root.player?.position ?? 0) / length)) : 0

                            width: parent.width
                            height: 24

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(0, handle.x - 4)
                                height: drag.containsMouse || drag.pressed ? 12 : 8
                                radius: height / 2
                                color: Theme.gold

                                Behavior on height {
                                    NumberAnimation {
                                        duration: Theme.fast
                                        easing.type: Easing.OutBack
                                    }
                                }
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: handle.x + handle.width + 4
                                width: Math.max(0, seek.width - x)
                                height: drag.containsMouse || drag.pressed ? 12 : 8
                                radius: height / 2
                                color: Theme.tonal

                                Behavior on height {
                                    NumberAnimation {
                                        duration: Theme.fast
                                        easing.type: Easing.OutBack
                                    }
                                }
                            }

                            // An upright handle, as the quick panel's sliders have.
                            Rectangle {
                                id: handle

                                anchors.verticalCenter: parent.verticalCenter
                                x: seek.f * (seek.width - width)
                                width: 4
                                height: 24
                                radius: 2
                                color: Theme.gold
                            }

                            MouseArea {
                                id: drag

                                property real f: 0

                                anchors.fill: parent
                                enabled: root.player?.canSeek ?? false
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onPressed: mouse => f = Math.max(0, Math.min(1, mouse.x / width))
                                onPositionChanged: mouse => {
                                    if (pressed)
                                        f = Math.max(0, Math.min(1, mouse.x / width));
                                }
                                onReleased: if (root.player)
                                    root.player.position = f * seek.length
                            }
                        }

                        Item {
                            width: parent.width
                            height: 16

                            Text {
                                text: Playback.time(seek.f * seek.length)
                                color: Theme.textDim
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }

                            Text {
                                anchors.right: parent.right
                                text: Playback.time(seek.length)
                                color: Theme.textDim
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }
                        }
                    }

                    // --- controls --------------------------------------------------------------
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10
                        visible: root.player !== null

                        Control {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: root.player?.shuffle ? "\u{f049d}" : "\u{f049e}"
                            on: root.player?.shuffle ?? false
                            enabled: root.player?.shuffleSupported ?? false
                            onClicked: root.player.shuffle = !root.player.shuffle
                        }

                        Control {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "\u{f04ae}"
                            size: 52
                            enabled: root.player?.canGoPrevious ?? false
                            onClicked: root.player.previous()
                        }

                        // Play/pause, large in the accent; it squares off while playing, as
                        // M3 Expressive's play buttons do.
                        Control {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: Playback.playing ? "\u{f03e4}" : "\u{f040a}"
                            size: 68
                            filled: true
                            squared: Playback.playing
                            enabled: root.player?.canTogglePlaying ?? false
                            onClicked: root.player.togglePlaying()
                        }

                        Control {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "\u{f04ad}"
                            size: 52
                            enabled: root.player?.canGoNext ?? false
                            onClicked: root.player.next()
                        }

                        Control {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: root.player?.loopState === MprisLoopState.Track ? "\u{f0458}" : root.player?.loopState === MprisLoopState.Playlist ? "\u{f0456}" : "\u{f0457}"
                            on: (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                            enabled: root.player?.loopSupported ?? false
                            // Off, the whole list, then the one track.
                            onClicked: root.player.loopState = root.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist : root.player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
                        }
                    }

                    // --- which player ----------------------------------------------------------
                    Flow {
                        width: parent.width
                        spacing: 6
                        visible: Playback.players.length > 1

                        Repeater {
                            model: Playback.players

                            Rectangle {
                                id: chip

                                required property var modelData
                                readonly property bool selected: modelData === root.player

                                width: chipText.implicitWidth + 28
                                height: 32
                                radius: selected ? 10 : 16
                                color: selected ? Theme.gold : chipMouse.containsMouse ? Theme.hover(Theme.tonal, 1.25) : Theme.tonal

                                Behavior on radius {
                                    NumberAnimation {
                                        duration: Theme.normal
                                        easing.type: Easing.OutBack
                                    }
                                }

                                Text {
                                    id: chipText

                                    anchors.centerIn: parent
                                    text: (chip.modelData.isPlaying ? "\u{f040a}  " : "") + chip.modelData.identity
                                    color: chip.selected ? Theme.goldInk : Theme.tonalInk
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                }

                                MouseArea {
                                    id: chipMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Playback.select(chip.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // A round icon button: tonal, or filled with the accent; `on` marks a toggle that is set.
    component Control: Rectangle {
        id: control

        property string icon
        property int size: 44
        property bool filled: false
        property bool on: false
        property bool squared: false

        signal clicked

        width: size
        height: size
        radius: squared ? size * 0.3 : size / 2
        opacity: enabled ? 1 : 0.4
        color: filled || on ? (controlMouse.containsMouse ? Theme.hover(Theme.gold, 1.12) : Theme.gold) : controlMouse.containsMouse ? Theme.hover(Theme.tonal, 1.25) : Theme.tonal

        Behavior on radius {
            NumberAnimation {
                duration: Theme.normal
                easing.type: Easing.OutBack
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Theme.fast
            }
        }

        Text {
            anchors.centerIn: parent
            text: control.icon
            color: control.filled || control.on ? Theme.goldInk : Theme.tonalInk
            font.family: "Symbols Nerd Font"
            font.pixelSize: Math.round(control.size * 0.42)
        }

        MouseArea {
            id: controlMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (control.enabled)
                control.clicked()
        }
    }
}
