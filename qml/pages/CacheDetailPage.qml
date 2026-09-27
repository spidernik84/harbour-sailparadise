import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    property string cacheId
    property string cacheTitle
    property var tracks: blockCache.tracks(cacheId)

    readonly property bool playingThis: radio.offline && radio.offlineCacheId === cacheId

    allowedOrientations: Orientation.All

    function play(index) {
        radio.playCache(cacheId, cacheTitle, index)
        pageStack.pop(pageStack.find(function(p) { return p.isPlayerPage === true }))
    }

    Connections {
        target: blockCache
        onTracksChanged: {
            if (cacheId === page.cacheId)
                page.tracks = blockCache.tracks(cacheId)
        }
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: page.tracks

        PullDownMenu {
            MenuItem {
                text: qsTr("Play all")
                enabled: listView.count > 0
                onClicked: page.play(0)
            }
        }

        header: PageHeader {
            title: page.cacheTitle
        }

        ViewPlaceholder {
            enabled: listView.count === 0
            text: qsTr("No tracks yet")
            hintText: qsTr("The track list is being fetched")
        }

        delegate: ListItem {
            id: item

            readonly property bool current: page.playingThis && radio.offlineIndex === index

            contentHeight: Theme.itemSizeMedium
            enabled: modelData.downloaded
            opacity: enabled ? 1.0 : Theme.opacityLow
            highlighted: down || current

            onClicked: page.play(index)

            Image {
                id: coverImage
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.itemSizeSmall
                height: width
                source: modelData.cover
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            Icon {
                anchors.centerIn: coverImage
                visible: !coverImage.visible
                source: "image://theme/icon-m-music"
            }

            Column {
                anchors {
                    left: coverImage.right
                    leftMargin: Theme.paddingLarge
                    right: durationLabel.left
                    rightMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }

                Label {
                    width: parent.width
                    text: modelData.title
                    color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                    truncationMode: TruncationMode.Fade
                }

                Label {
                    width: parent.width
                    text: modelData.artist
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    truncationMode: TruncationMode.Fade
                }
            }

            Label {
                id: durationLabel
                anchors {
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                text: Format.formatDuration(modelData.duration / 1000, Formatter.DurationShort)
                font.pixelSize: Theme.fontSizeExtraSmall
                color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
            }
        }

        VerticalScrollDecorator {}
    }
}
