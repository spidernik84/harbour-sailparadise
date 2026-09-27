.pragma library

// Radio Paradise channels and their Icecast stream URLs.
// See https://radioparadise.com/listen/stream-links

var streamBase = "https://stream.radioparadise.com/"
var apiBase = "https://api.radioparadise.com/api/"
var imageBase = "https://img.radioparadise.com/channels/0/"

var defaultQuality = "aac-320"
var defaultMobileQuality = "aac-128"

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

// The quality actually streamed for a channel, as not every channel has every quality
function streamQuality(channel, quality) {
    if (channel.streams[quality])
        return quality
    if (channel.streams[defaultQuality])
        return defaultQuality
    for (var key in channel.streams)
        return key
    return ""
}

function streamUrl(channel, quality) {
    var key = streamQuality(channel, quality)
    return key !== "" ? channel.streams[key] : ""
}

function qualityLabel(key) {
    for (var i = 0; i < qualities.length; i++) {
        if (qualities[i].key === key)
            return qualities[i].label
    }
    if (key === "aac-64")
        return "AAC 64 kbps"    // Serenity only
    return key
}

// Formats the quality reported by the block API, e.g. "320k aac" or "flac"
function blockQualityLabel(quality) {
    var match = /^(\d+)k\s+(\w+)$/.exec(quality || "")
    if (match)
        return match[2].toUpperCase() + " " + match[1] + " kbps"
    return (quality || "").toUpperCase()
}

function nowPlayingUrl(channelId) {
    return apiBase + "now_playing?chan=" + channelId
}

function imageUrl(channelId) {
    return imageBase + channelId + "/cover_512x512/0.jpg"
}
