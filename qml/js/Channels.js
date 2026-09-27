.pragma library

// Radio Paradise channels and their Icecast stream URLs.
// See https://radioparadise.com/listen/stream-links

var streamBase = "https://stream.radioparadise.com/"
var apiBase = "https://api.radioparadise.com/api/"
var imageBase = "https://img.radioparadise.com/channels/0/"

var defaultQuality = "aac-320"

var qualities = [
    { key: "aac-320", label: "AAC 320 kbps" },
    { key: "aac-128", label: "AAC 128 kbps" },
    { key: "mp3-192", label: "MP3 192 kbps" },
    { key: "flac",    label: "FLAC" }
]

// Qualities available for offline cache blocks, "bitrate" as used by the block API
var cacheQualities = [
    { bitrate: 3, label: "AAC 320 kbps" },
    { bitrate: 2, label: "AAC 128 kbps" },
    { bitrate: 1, label: "AAC 64 kbps" },
    { bitrate: 4, label: "FLAC" }
]

function standardStreams(prefix) {
    return {
        "aac-320": streamBase + prefix + "320",
        "aac-128": streamBase + prefix + "128",
        "mp3-192": streamBase + prefix + "192",
        "flac":    streamBase + prefix + "flacm"
    }
}

var channels = [
    {
        id: 0,
        title: "Main Mix",
        description: "Eclectic mix of rock, world, electronica and more",
        streams: {
            "aac-320": streamBase + "aac-320",
            "aac-128": streamBase + "aac-128",
            "mp3-192": streamBase + "mp3-192",
            "flac":    streamBase + "flacm"
        }
    },
    {
        id: 1,
        title: "Mellow Mix",
        description: "Mellower, less aggressive music",
        streams: standardStreams("mellow-")
    },
    {
        id: 2,
        title: "Rock Mix",
        description: "Heavier, more guitar-driven music",
        streams: standardStreams("rock-")
    },
    {
        id: 3,
        title: "Global Mix",
        description: "Global music and non-western genres",
        streams: standardStreams("global-")
    },
    {
        id: 5,
        title: "Beyond...",
        description: "Exploratory and adventurous music",
        streams: standardStreams("beyond-")
    },
    {
        id: 42,
        title: "Serenity",
        description: "Ambient, relaxation and chill",
        // Serenity is only available as a single 64 kbps AAC stream
        streams: {
            "aac-64": streamBase + "serenity"
        }
    },
    {
        id: 945,
        title: "KFAT",
        description: "Americana, folk and roots",
        streams: standardStreams("kfat-")
    }
]

function indexOfChannel(channelId) {
    for (var i = 0; i < channels.length; i++) {
        if (channels[i].id === channelId)
            return i
    }
    return 0
}

function streamUrl(channel, quality) {
    if (channel.streams[quality])
        return channel.streams[quality]
    if (channel.streams[defaultQuality])
        return channel.streams[defaultQuality]
    for (var key in channel.streams)
        return channel.streams[key]
    return ""
}

function nowPlayingUrl(channelId) {
    return apiBase + "now_playing?chan=" + channelId
}

function imageUrl(channelId) {
    return imageBase + channelId + "/cover_512x512/0.jpg"
}
