import QtQuick 2.0
import QtMultimedia 5.6
import Nemo.Configuration 1.0
import "../js/Channels.js" as Channels

// Plays a Radio Paradise channel and keeps the "now playing" metadata up to date.
Item {
    id: root

    readonly property int channelIndex: Channels.indexOfChannel(settings.channelId)
    readonly property var channel: Channels.channels[channelIndex]
    readonly property string quality: settings.quality

    // true while the user wants audio; the actual stream state may lag behind
    readonly property bool active: _wantPlaying
    readonly property bool playing: audio.playbackState === Audio.PlayingState
    readonly property bool buffering: _wantPlaying
                                      && (audio.status === Audio.Loading
                                          || audio.status === Audio.Stalled
                                          || !playing)
    readonly property string errorString: _errorString

    readonly property string artist: _meta.artist || ""
    readonly property string title: _meta.title || ""
    readonly property string album: _meta.album || ""
    readonly property string year: _meta.year || ""
    readonly property string cover: _meta.cover || ""
    readonly property string coverSmall: _meta.cover_med || _meta.cover || ""

    property bool _wantPlaying: false
    property string _errorString
    property var _meta: ({})
    property int _retries: 0
    property int _request: 0

    readonly property int _maxRetries: 5
    readonly property bool _metadataActive: _wantPlaying || Qt.application.state === Qt.ApplicationActive

    function play() {
        _errorString = ""
        _wantPlaying = true
        audio.source = Channels.streamUrl(channel, quality)
        audio.play()
    }

    function stop() {
        _wantPlaying = false
        retryTimer.stop()
        _retries = 0
        audio.stop()
    }

    function toggle() {
        if (_wantPlaying)
            stop()
        else
            play()
    }

    function setChannel(channelId) {
        if (channelId === channel.id)
            return
        settings.channelId = channelId
        _meta = {}
        refreshMetadata()
        if (_wantPlaying)
            play()
    }

    function setQuality(key) {
        if (key === quality)
            return
        settings.quality = key
        if (_wantPlaying)
            play()
    }

    function refreshMetadata() {
        var request = ++_request
        var channelId = channel.id
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || request !== _request)
                return

            // Seconds until the next metadata refresh
            var next = 30
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText)
                    _meta = data
                    // "time" is the number of seconds left in the current song.
                    // Add a small margin since the stream lags behind the API.
                    if (data.time > 0)
                        next = data.time + 5
                } catch (e) {
                    console.warn("Invalid now_playing response for channel", channelId, e)
                }
            } else {
                console.warn("now_playing request failed for channel", channelId, xhr.status)
            }

            metadataTimer.interval = Math.max(5, Math.min(next, 300)) * 1000
            if (_metadataActive)
                metadataTimer.restart()
        }
        xhr.open("GET", Channels.nowPlayingUrl(channelId))
        xhr.send()
    }

    function _retry() {
        if (!_wantPlaying)
            return
        if (_retries >= _maxRetries) {
            stop()
            return
        }
        _retries++
        retryTimer.restart()
    }

    on_MetadataActiveChanged: {
        if (_metadataActive)
            refreshMetadata()
        else
            metadataTimer.stop()
    }

    Component.onCompleted: refreshMetadata()

    ConfigurationGroup {
        id: settings
        path: "/apps/harbour-sailparadise"

        property int channelId: 0
        property string quality: Channels.defaultQuality
    }

    Audio {
        id: audio
        audioRole: Audio.MusicRole
        autoLoad: false

        onStatusChanged: {
            if (status === Audio.Buffered) {
                _retries = 0
                _errorString = ""
            } else if (status === Audio.EndOfMedia) {
                // A live stream should never end: the connection was dropped
                _retry()
            }
        }

        onError: {
            console.warn("Playback error:", error, errorString)
            _errorString = errorString
            _retry()
        }
    }

    Timer {
        id: retryTimer
        interval: 3000
        onTriggered: {
            if (_wantPlaying) {
                audio.stop()
                audio.play()
            }
        }
    }

    Timer {
        id: metadataTimer
        onTriggered: refreshMetadata()
    }
}
