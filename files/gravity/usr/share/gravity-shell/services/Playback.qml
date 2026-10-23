pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The media player the bar and the media panel follow: the one playing (the most recently
// started, with several), else the one that played last, else any. `select` picks another
// one in the panel.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    // Identity of the player picked by hand or that last started playing.
    property string lastIdentity: ""

    readonly property MprisPlayer player: {
        const list = players;
        return list.find(p => p.identity === lastIdentity && p.isPlaying) ?? list.find(p => p.isPlaying) ?? list.find(p => p.identity === lastIdentity) ?? list[0] ?? null;
    }
    readonly property bool playing: player?.isPlaying ?? false
    readonly property bool hasPlayer: player !== null

    function select(p: MprisPlayer): void {
        lastIdentity = p?.identity ?? "";
    }

    // Remembers whichever player starts playing.
    Instantiator {
        model: Mpris.players

        Connections {
            required property MprisPlayer modelData

            target: modelData

            function onIsPlayingChanged(): void {
                if (modelData.isPlaying)
                    root.lastIdentity = modelData.identity;
            }
        }
    }

    // "m:ss" (or "h:mm:ss").
    function time(seconds: real): string {
        const s = Math.max(0, Math.floor(seconds));
        const h = Math.floor(s / 3600);
        const m = Math.floor(s / 60) % 60;
        const ss = String(s % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${ss}` : `${m}:${ss}`;
    }
}
