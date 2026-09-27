import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.sailparadise 1.0
import "../js/Channels.js" as Channels

Page {
    id: page

    allowedOrientations: Orientation.All

    // Formatter.DurationShort drops the hours, so format lengths explicitly
    function formatLength(minutes) {
        var h = Math.floor(minutes / 60)
        var m = minutes % 60
        if (h === 0)
            return qsTr("%1 min").arg(m)
        if (m === 0)
            return qsTr("%1 h").arg(h)
        return qsTr("%1 h %2 min").arg(h).arg(m)
    }

    function cacheTitle(channelTitle, created) {
        return channelTitle + " · " + Format.formatDate(created, Formatter.DateMediumWithoutYear)
                + " " + Format.formatDate(created, Formatter.TimeValue)
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: blockCache

        header: Column {
            id: form

            readonly property var selectedChannel: Channels.channels[channelBox.currentIndex]
            readonly property int selectedBitrate: Channels.cacheQualities[qualityBox.currentIndex].bitrate
            readonly property int minutes: Math.round(hoursSlider.value * 60)
            readonly property real estimatedSize: blockCache.estimateSize(selectedBitrate, minutes)
            property real freeSpace: blockCache.freeSpace()
            readonly property bool enoughSpace: freeSpace < 0 || estimatedSize < freeSpace

            width: listView.width

            PageHeader {
                title: qsTr("Offline cache")
            }

            SectionHeader {
                text: qsTr("New cache block")
            }

            ComboBox {
                id: channelBox
                label: qsTr("Channel")
                currentIndex: radio.channelIndex

                menu: ContextMenu {
                    Repeater {
                        model: Channels.channels
                        MenuItem { text: modelData.title }
                    }
                }
            }

            ComboBox {
                id: qualityBox
                label: qsTr("Quality")
                description: form.selectedChannel.id === 42
                             ? qsTr("Serenity is only available as AAC 64 kbps") : ""

                menu: ContextMenu {
                    Repeater {
                        model: Channels.cacheQualities
                        MenuItem { text: modelData.label }
                    }
                }
            }

            Slider {
                id: hoursSlider
                width: parent.width
                label: qsTr("Duration")
                minimumValue: 0.5
                maximumValue: 6
                stepSize: 0.5
                value: 1
                valueText: page.formatLength(form.minutes)
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: form.enoughSpace ? Theme.secondaryHighlightColor : Theme.errorColor
                text: {
                    var size = qsTr("Estimated size: %1").arg(Format.formatFileSize(form.estimatedSize))
                    if (form.freeSpace < 0)
                        return size
                    var free = qsTr("%1 free").arg(Format.formatFileSize(form.freeSpace))
                    return form.enoughSpace ? size + " · " + free
                                            : size + " · " + qsTr("not enough storage space (%1)").arg(free)
                }
            }

            Item {
                width: parent.width
                height: createButton.height + 2 * Theme.paddingLarge

                Button {
                    id: createButton
                    anchors.centerIn: parent
                    text: qsTr("Create")
                    enabled: form.enoughSpace
                    onClicked: {
                        blockCache.create(form.selectedChannel.id, form.selectedChannel.title,
                                          form.selectedBitrate, form.minutes)
                        form.freeSpace = blockCache.freeSpace()
                    }
                }
            }

            SectionHeader {
                text: qsTr("Cache blocks")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: listView.count === 0
                text: qsTr("No cache blocks yet")
                color: Theme.secondaryHighlightColor
                wrapMode: Text.Wrap
            }
        }

        delegate: ListItem {
            id: item

            readonly property bool downloading: cacheState === BlockCache.Queued
                                                || cacheState === BlockCache.Fetching
                                                || cacheState === BlockCache.Downloading
            readonly property string title: page.cacheTitle(channelTitle, created)

            contentHeight: content.height + 2 * Theme.paddingMedium
            highlighted: down || (radio.offline && radio.offlineCacheId === cacheId)

            onClicked: pageStack.animatorPush(Qt.resolvedUrl("CacheDetailPage.qml"),
                                              { cacheId: cacheId, cacheTitle: title })

            function deleteBlock() {
                var id = cacheId
                remorseAction(qsTr("Deleting"), function() {
                    if (radio.offlineCacheId === id)
                        radio.leaveOffline()
                    blockCache.remove(id)
                })
            }

            menu: ContextMenu {
                MenuItem {
                    text: qsTr("Play")
                    visible: downloadedCount > 0
                    onClicked: {
                        radio.playCache(cacheId, item.title, 0)
                        pageStack.navigateBack()
                    }
                }
                MenuItem {
                    text: qsTr("Pause download")
                    visible: item.downloading
                    onClicked: blockCache.pause(cacheId)
                }
                MenuItem {
                    text: cacheState === BlockCache.Failed ? qsTr("Retry download") : qsTr("Resume download")
                    visible: cacheState === BlockCache.Paused || cacheState === BlockCache.Failed
                    onClicked: blockCache.resume(cacheId)
                }
                MenuItem {
                    text: qsTr("Delete")
                    onClicked: item.deleteBlock()
                }
            }

            Column {
                id: content
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.paddingSmall

                Label {
                    width: parent.width
                    text: item.title
                    color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                    truncationMode: TruncationMode.Fade
                }

                Label {
                    width: parent.width
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: cacheState === BlockCache.Failed
                           ? Theme.errorColor
                           : (item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor)
                    truncationMode: TruncationMode.Fade
                    text: {
                        var details = quality !== "" ? [quality] : []
                        if (trackCount > 0)
                            details.push(page.formatLength(Math.round(duration / 60000)))
                        details.push(Format.formatFileSize(size))

                        switch (cacheState) {
                        case BlockCache.Queued:
                            return qsTr("Waiting to download")
                        case BlockCache.Fetching:
                            return qsTr("Fetching track list")
                        case BlockCache.Downloading:
                            return qsTr("Downloading track %1 of %2").arg(downloadedCount + 1).arg(trackCount)
                                    + " · " + details.join(" · ")
                        case BlockCache.Paused:
                            return qsTr("Paused, %1 of %2 tracks").arg(downloadedCount).arg(trackCount)
                                    + " · " + details.join(" · ")
                        case BlockCache.Failed:
                            return qsTr("Failed: %1").arg(cacheError)
                        default:
                            return qsTr("%n track(s)", "", trackCount) + " · " + details.join(" · ")
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Theme.paddingSmall / 2
                    visible: cacheState !== BlockCache.Complete
                    color: Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity)

                    Rectangle {
                        width: parent.width * progress
                        height: parent.height
                        color: Theme.highlightColor
                    }
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
