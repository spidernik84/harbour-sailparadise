import QtQuick 2.0
import QtMultimedia 5.6
import Nemo.Configuration 1.0
import harbour.sailparadise 1.0
import "../js/Channels.js" as Channels

// Plays either a live Radio Paradise channel, keeping the "now playing"
// metadata up to date, or the tracks of an offline cache block.
Item {
    id: root

    readonly property int channelIndex: Channels.indexOfChannel(settings.channelId)
    readonly property var channel: Channels.channels[channelIndex]
    // Stream quality for the current connection. Losing the connection keeps the last
    // known type, so a short outage does not reconnect with a different quality.
    // Until a connection is known the Wi-Fi quality is used.
    readonly property bool onMobileData: _connectionType === NetworkMonitor.Mobile
    readonly property string wifiQuality: settings.quality
    readonly property string mobileQuality: settings.mobileQuality
    readonly property string quality: onMobileData ? mobileQuality : wifiQuality
    readonly property int connectionType: _connectionType
    readonly property bool showQualityInfo: settings.showQualityInfo
    // Human readable quality of what is playing
    readonly property string qualityLabel: offline ? Channels.blockQualityLabel(_offlineQuality)
                                                   : Channels.qualityLabel(Channels.streamQuality(channel, quality))

    // Offline playback of a cache block
    readonly property bool offline: _offlineCacheId !== ""
    readonly property string offlineCacheId: _offlineCacheId
    readonly property string offlineTitle: _offlineTitle
    readonly property int offlineIndex: _offlineIndex
    readonly property int offlineCount: _offlineTracks.length
    readonly property bool hasNext: offline && _findAvailable(_offlineIndex + 1, 1) >= 0
    readonly property bool hasPrevious: offline && _findAvailable(_offlineIndex - 1, -1) >= 0
    readonly property int position: audio.position
    readonly property int duration: audio.duration
    readonly property bool seekable: offline && audio.seekable

    // true while the user wants audio; the actual stream state may lag behind
    readonly property bool active: _wantPlaying
    readonly property bool playing: audio.playbackState === Audio.PlayingState
    readonly property bool buffering: _wantPlaying
                                      && (audio.status === Audio.Loading
                                          || audio.status === Audio.Stalled
                                          || !playing)
    readonly property string errorString: _errorString

    readonly property string artist: _current.artist || ""
    readonly property string title: _current.title || ""
    readonly property string album: _current.album || ""
    readonly property string year: _current.year || ""
    readonly property string cover: _current.cover || ""
    readonly property string coverSmall: _current.cover_med || _current.cover || ""

    property bool _wantPlaying: false
    property int _connectionType: NetworkMonitor.Unknown
    property string _errorString
    property var _meta: ({})
    property int _retries: 0
    property int _request: 0

    property string _offlineCacheId
    property string _offlineTitle
    property string _offlineQuality
    property var _offlineTracks: []
    property int _offlineIndex: -1
    property bool _offlineEnded: false

    readonly property var _current: offline ? (_offlineTracks[_offlineIndex] || {}) : _meta
    readonly property int _maxRetries: 5
    readonly property bool _metadataActive: !offline
                                            && (_wantPlaying || Qt.application.state === Qt.ApplicationActive)

    function play() {
        _errorString = ""
        if (offline) {
            if (_offlineIndex < 0 || _offlineEnded) {
                _playOffline(_findAvailable(0, 1))
            } else {
                _wantPlaying = true
                audio.play()
            }
            return
        }
        _wantPlaying = true
        _load(Channels.streamUrl(channel, quality))
    }

    function stop() {
        _wantPlaying = false
        retryTimer.stop()
        _retries = 0
        if (offline)
            audio.pause()
        else
            audio.stop()
    }

    function toggle() {
        if (_wantPlaying)
            stop()
        else
            play()
    }

    function setChannel(channelId) {
        var changed = offline || channelId !== channel.id
        if (offline)
            _clearOffline()
        if (!changed)
            return
        if (channelId !== channel.id) {
            settings.channelId = channelId
            _meta = {}
        }
        refreshMetadata()
        if (_wantPlaying)
            play()
    }

    function setWifiQuality(key) {
        settings.quality = key
    }

    function setMobileQuality(key) {
        settings.mobileQuality = key
    }

    function setShowQualityInfo(show) {
        settings.showQualityInfo = show
    }

    // Reconnect with the new stream, e.g. when switching between Wi-Fi and mobile data
    onQualityChanged: {
        if (_wantPlaying && !offline)
            play()
    }

    // Starts playing the downloaded tracks of a cache block from the given track
    function playCache(cacheId, title, index) {
        retryTimer.stop()
        _retries = 0
        _errorString = ""
        _offlineCacheId = cacheId
        _offlineTitle = title
        _offlineQuality = blockCache.quality(cacheId)
        _offlineTracks = blockCache.tracks(cacheId)
        _playOffline(_findAvailable(index || 0, 1))
    }

    // Leaves offline mode, e.g. when the played cache block is deleted
    function leaveOffline() {
        if (!offline)
            return
        stop()
        _clearOffline()
        refreshMetadata()
    }

    function next() {
        if (offline)
            _playOffline(_findAvailable(_offlineIndex + 1, 1))
    }

    function previous() {
        if (!offline)
            return
        if (audio.position > 3000 || !hasPrevious)
            audio.seek(0)
        else
            _playOffline(_findAvailable(_offlineIndex - 1, -1))
    }

    function seek(position) {
        if (seekable)
            audio.seek(position)
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

    // Index of the first downloaded track starting at "from" in the given direction, or -1
    function _findAvailable(from, direction) {
        for (var i = from; i >= 0 && i < _offlineTracks.length; i += direction) {
            if (_offlineTracks[i].downloaded)
                return i
        }
        return -1
    }

    function _playOffline(index) {
        if (index < 0) {
            // End of the cache block
            _wantPlaying = false
            _offlineEnded = true
            audio.stop()
            return
        }
        _offlineEnded = false
        _offlineIndex = index
        _wantPlaying = true
        _load(_offlineTracks[index].source)
    }

    function _load(source) {
        // Changing the source of a playing Audio element does not reload the
        // media, the old one keeps playing. Stop it first.
        audio.stop()
        audio.source = source
        audio.play()
    }

    function _clearOffline() {
        audio.stop()
        audio.source = ""
        _offlineCacheId = ""
        _offlineTitle = ""
        _offlineQuality = ""
        _offlineTracks = []
        _offlineIndex = -1
        _offlineEnded = false
    }

    on_MetadataActiveChanged: {
        if (_metadataActive)
            refreshMetadata()
        else
            metadataTimer.stop()
    }

    function _updateConnectionType() {
        if (networkMonitor.connectionType !== NetworkMonitor.Unknown)
            _connectionType = networkMonitor.connectionType
    }

    Component.onCompleted: {
        _updateConnectionType()
        refreshMetadata()
    }

    Connections {
        target: networkMonitor
        onConnectionTypeChanged: _updateConnectionType()
    }

    Connections {
        target: blockCache
        // Pick up tracks that finished downloading while playing the block
        onTracksChanged: {
            if (cacheId === _offlineCacheId)
                _offlineTracks = blockCache.tracks(cacheId)
        }
    }

    ConfigurationGroup {
        id: settings
        path: "/apps/harbour-sailparadise"

        property int channelId: 0
        // Wi-Fi quality, the key predates the mobile data setting
        property string quality: Channels.defaultQuality
        property string mobileQuality: Channels.defaultMobileQuality
        property bool showQualityInfo: true
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
                if (offline)
                    next()
                else
                    _retry()    // A live stream should never end: the connection was dropped
            }
        }

        onError: {
            console.warn("Playback error:", error, errorString)
            _errorString = errorString
            if (offline)
                next()
            else
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
