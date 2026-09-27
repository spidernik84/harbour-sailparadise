import QtQuick 2.0
import Amber.Mpris 1.0

// Publishes the player over MPRIS, which drives the lock screen media
// controls as well as Bluetooth (AVRCP) and wired headset buttons.
MprisPlayer {
    id: mpris

    property QtObject player

    serviceName: "sailparadise"
    identity: "SailParadise"
    desktopEntry: "harbour-sailparadise"
    supportedUriSchemes: ["file", "http", "https"]

    canControl: true
    canPlay: true
    canPause: true
    canGoNext: player.hasNext
    canGoPrevious: player.offline && player.offlineIndex >= 0
    canSeek: player.seekable

    playbackStatus: {
        if (player.active)
            return Mpris.Playing
        // A live stream cannot be paused, only an offline track can
        return player.offline && player.offlineIndex >= 0 ? Mpris.Paused : Mpris.Stopped
    }

    metaData {
        title: player.title !== "" ? player.title : (player.offline ? player.offlineTitle : player.channel.title)
        contributingArtist: player.artist !== "" ? player.artist : "Radio Paradise"
        albumTitle: player.album
        artUrl: player.cover
        duration: player.offline ? player.duration : 0
    }

    onPlayRequested: player.play()
    onPauseRequested: player.stop()
    onPlayPauseRequested: player.toggle()
    onStopRequested: player.stop()
    onNextRequested: player.next()
    onPreviousRequested: player.previous()
    onSeekRequested: _seekTo(player.position + offset)
    onSetPositionRequested: _seekTo(position)
    onPositionRequested: mpris.position = player.position

    function _seekTo(position) {
        var target = Math.max(0, Math.min(position, player.duration))
        player.seek(target)
        // Tell controllers about the jump, they extrapolate the position otherwise
        mpris.seeked(target)
    }
}
