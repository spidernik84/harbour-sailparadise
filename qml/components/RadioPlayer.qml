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
    // One of Channels.connectionChangeBehaviors
    readonly property string connectionChangeBehavior: settings.connectionChangeBehavior
    // Human readable quality of what is playing
    readonly property string qualityLabel: offline ? Channels.blockQualityLabel(_offlineQuality)
                                                   : Channels.qualityLabel(_playingQuality)
    // The live stream plays with another quality than the one for the current
    // connection, e.g. after connecting to Wi-Fi. switchQuality() reconnects.
    readonly property bool qualitySwitchAvailable: _wantPlaying && !offline && _streamQuality !== ""
                                                   && _streamQuality !== _targetQuality
    readonly property string targetQualityLabel: Channels.qualityLabel(_targetQuality)

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
    // Nothing was played or picked yet since the app was installed
    readonly property bool firstLaunch: settings.firstLaunch
    // Follow the live metadata without playing the stream
    readonly property bool tracking: _tracking
    // Live radio that is neither playing nor tracking: no song metadata is fetched,
    // the channel image is shown
    readonly property bool idle: !offline && !_wantPlaying && !_tracking
    // Cached copy, depends on the revision to pick up downloaded images
    readonly property string channelImage: channelImages.revision,
                                           channelImages.source(channel.id, Channels.imageUrl(channel.id))

    readonly property string artist: _current.artist || ""
    readonly property string title: _current.title || ""
    readonly property string album: _current.album || ""
    readonly property string year: _current.year || ""
    readonly property string cover: idle ? channelImage : (_current.cover || "")
    readonly property string coverSmall: idle ? channelImage : (_current.cover_med || _current.cover || "")
    // Id of the song on the website, empty until looked up with findSongId()
    readonly property string songId: _current.song_id
                                     || (_songIdKey !== "" && _songIdKey === _songKey(_current) ? _songId : "")
    readonly property bool songIdLookupRunning: _songIdLookup !== ""

    property bool _wantPlaying: false
    property bool _tracking: false
    property int _connectionType: NetworkMonitor.Unknown
    // Set while the connection type changes, the reconnect is then decided by _updateConnectionType()
    property bool _connectionChanging: false
    // Quality of the live stream that was loaded, empty when none was
    property string _streamQuality
    property string _errorString
    // Latest now_playing response and the last few distinct songs it reported. The API
    // runs ahead of what is heard, as the audio is delayed by the server burst on connect
    // and the player buffer, so the song actually playing is picked from the stream tags.
    property var _latest: ({})
    property var _history: []
    // Title from the stream tags ("Artist - Title" for ICY, the track title for Ogg FLAC),
    // empty when the backend does not report tags. Then the latest API response is used.
    property string _streamTitle
    property int _retries: 0
    property int _request: 0
    // Result of the last song id lookup and the song it was made for, see _songKey()
    property string _songId
    property string _songIdKey
    // Song currently being looked up, empty when no lookup is running
    property string _songIdLookup

    property string _offlineCacheId
    property string _offlineTitle
    property string _offlineQuality
    property var _offlineTracks: []
    property int _offlineIndex: -1
    property bool _offlineEnded: false

    readonly property string _targetQuality: Channels.streamQuality(channel, quality)
    readonly property string _playingQuality: _wantPlaying && _streamQuality !== "" ? _streamQuality : _targetQuality
    readonly property var _meta: _streamTitle !== "" ? _metaForStreamTitle(_streamTitle, _history) : _latest
    readonly property var _current: offline ? (_offlineTracks[_offlineIndex] || {}) : idle ? ({}) : _meta
    readonly property int _maxHistory: 5
    readonly property int _maxRetries: 5
    readonly property bool _metadataActive: !offline && (_wantPlaying || _tracking)

    function play() {
        settings.firstLaunch = false
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
        // Playing and tracking exclude each other
        _tracking = false
        _wantPlaying = true
        _streamQuality = _targetQuality
        _load(Channels.streamUrl(channel, quality))
    }

    function stop() {
        _wantPlaying = false
        _streamTitle = ""
        retryTimer.stop()
        _retries = 0
        if (offline) {
            audio.pause()
        } else {
            audio.stop()
            if (!_tracking)
                _clearMetadata()
        }
    }

    function setTracking(enabled) {
        if (enabled)
            settings.firstLaunch = false
        _tracking = enabled
        // Tracking replaces live playback, the metadata stays as it is
        if (enabled && _wantPlaying && !offline)
            stop()
        if (idle)
            _clearMetadata()
    }

    function toggle() {
        if (_wantPlaying)
            stop()
        else
            play()
    }

    function setChannel(channelId) {
        settings.firstLaunch = false
        var changed = offline || channelId !== channel.id
        if (offline)
            _clearOffline()
        if (!changed)
            return
        if (channelId !== channel.id) {
            settings.channelId = channelId
            _latest = {}
            _history = []
            _streamTitle = ""
        }
        if (_metadataActive)
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

    function setConnectionChangeBehavior(key) {
        settings.connectionChangeBehavior = key
    }

    // Reconnects the live stream with the quality for the current connection
    function switchQuality() {
        if (qualitySwitchAvailable)
            play()
    }

    // Reconnect with the new quality after a settings change. Connection changes
    // are handled by _updateConnectionType().
    onQualityChanged: {
        if (_wantPlaying && !offline && !_connectionChanging && _streamQuality !== _targetQuality)
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
                    _addToHistory(data)
                    _latest = data
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

    // Looks up the id of the current song, the now_playing response does not include it
    function findSongId() {
        var key = _songKey(_current)
        if (offline || songId !== "" || key === "" || key === _songIdLookup)
            return
        _songIdLookup = key
        var channelId = channel.id
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || key !== _songIdLookup)
                return
            _songIdLookup = ""
            var id = ""
            if (xhr.status === 200) {
                try {
                    var songs = JSON.parse(xhr.responseText).song || []
                    for (var i = 0; i < songs.length; i++) {
                        if (_songKey(songs[i]) === key) {
                            id = songs[i].song_id || ""
                            break
                        }
                    }
                } catch (e) {
                    console.warn("Invalid song list response for channel", channelId, e)
                }
            } else {
                console.warn("Song list request failed for channel", channelId, xhr.status)
            }
            _songId = id
            _songIdKey = key
        }
        xhr.open("GET", Channels.recentSongsUrl(channelId))
        xhr.send()
    }

    function _songKey(song) {
        return song.title ? _normalize(song.artist) + "|" + _normalize(song.title) : ""
    }

    function _addToHistory(data) {
        var history = _history.filter(function(entry) {
            return entry.artist !== data.artist || entry.title !== data.title
        })
        history.push(data)
        _history = history.slice(-_maxHistory)
    }

    // Only letters and digits, so that differences in punctuation or a mangled
    // encoding in the stream tags do not prevent a match
    function _normalize(text) {
        return (text || "").toLowerCase().replace(/[^a-z0-9]/g, "")
    }

    function _findInHistory(streamTitle, history) {
        var tag = _normalize(streamTitle)
        if (tag === "")
            return null
        for (var i = history.length - 1; i >= 0; i--) {
            var entry = history[i]
            if (tag === _normalize((entry.artist || "") + (entry.title || ""))
                    || tag === _normalize(entry.title))
                return entry
        }
        return null
    }

    // Metadata for the song the stream is playing. Without a matching API response
    // only artist and title are known, split from the stream title.
    function _metaForStreamTitle(streamTitle, history) {
        var entry = _findInHistory(streamTitle, history)
        if (entry)
            return entry
        var separator = streamTitle.indexOf(" - ")
        if (separator < 0)
            return { title: streamTitle }
        return { artist: streamTitle.substring(0, separator),
                 title: streamTitle.substring(separator + 3) }
    }

    function _updateStreamTitle() {
        var title = offline || !_wantPlaying ? "" : (audio.metaData.title || "").toString().trim()
        if (title === "" || title === _streamTitle)
            return
        _streamTitle = title
        // The API usually already reported the song, if not ask for it now
        if (!_findInHistory(title, _history))
            refreshMetadata()
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
        advanceTimer.stop()
        _offlineEnded = false
        _offlineIndex = index
        _wantPlaying = true
        _load(_offlineTracks[index].source)
    }

    function _load(source) {
        // Changing the source of a playing Audio element does not reload the
        // media, the old one keeps playing. Stop it first.
        audio.stop()
        _streamTitle = ""
        audio.source = source
        audio.play()
    }

    // Forgets the songs and drops a pending response, they are stale once fetching again
    function _clearMetadata() {
        _request++
        _latest = {}
        _history = []
    }

    function _clearOffline() {
        advanceTimer.stop()
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
        var type = networkMonitor.connectionType
        if (type === NetworkMonitor.Unknown || type === _connectionType)
            return
        // The "quality" binding and its change handler run synchronously within the assignment
        _connectionChanging = true
        _connectionType = type
        _connectionChanging = false
        if (_wantPlaying && !offline && _streamQuality !== _targetQuality && _switchOnConnectionChange(type))
            play()
    }

    // Mobile data always gets its own quality. On Wi-Fi the stream keeps playing
    // as it is, unless set otherwise, and the player offers the switch.
    function _switchOnConnectionChange(type) {
        if (type !== NetworkMonitor.WiFi)
            return true
        switch (settings.connectionChangeBehavior) {
        case "switch":
            return true
        case "upgrade":
            return Channels.qualityRank(_targetQuality) > Channels.qualityRank(_streamQuality)
        default:
            return false
        }
    }

    Component.onCompleted: {
        _updateConnectionType()
    }

    Connections {
        target: networkMonitor
        onConnectionTypeChanged: _updateConnectionType()
    }

    Connections {
        target: audio.metaData
        onMetaDataChanged: _updateStreamTitle()
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
        property bool firstLaunch: true
        // Wi-Fi quality, the key predates the mobile data setting
        property string quality: Channels.defaultQuality
        property string mobileQuality: Channels.defaultMobileQuality
        property bool showQualityInfo: true
        property string connectionChangeBehavior: Channels.defaultConnectionChangeBehavior
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
                    advanceTimer.restart()
                else
                    _retry()    // A live stream should never end: the connection was dropped
            }
        }

        onError: {
            console.warn("Playback error:", error, errorString)
            _errorString = errorString
            if (offline)
                advanceTimer.restart()
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

    // Moves to the next offline track once the current one ended. Loading a new
    // source from within the Audio status/error handlers leaves the player stuck,
    // so it is done from the event loop instead.
    Timer {
        id: advanceTimer
        interval: 0
        onTriggered: {
            if (offline && _wantPlaying)
                next()
        }
    }

    Timer {
        id: metadataTimer
        onTriggered: refreshMetadata()
    }
}
