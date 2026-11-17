pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The "current" MPRIS player: whatever is playing, else the first one.
Singleton {
    id: root

    readonly property var player: Mpris.players.values.find(p => p.isPlaying)
        ?? Mpris.players.values[0]
        ?? null

    readonly property bool present: player !== null
    readonly property bool playing: player?.isPlaying ?? false
    readonly property string title: player?.trackTitle || player?.identity || ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string art: player?.trackArtUrl ?? ""
    readonly property string trackId: player ? `${artist}·${title}` : ""

    readonly property real length: player?.lengthSupported ? player.length : 0
    readonly property real position: player?.positionSupported ? player.position : 0

    // MPRIS doesn't push position updates; poke the property while playing
    // so anything bound to it moves.
    Timer {
        interval: 1000
        repeat: true
        running: root.playing && (root.player?.positionSupported ?? false)
        onTriggered: root.player.positionChanged()
    }

    function toggle() {
        if (player?.canTogglePlaying) player.togglePlaying();
    }
    function next() {
        if (player?.canGoNext) player.next();
    }
    function previous() {
        if (player?.canGoPrevious) player.previous();
    }

    function fmt(secs) {
        const s = Math.max(0, Math.floor(secs));
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }
}
