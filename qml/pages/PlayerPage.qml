import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.sailparadise 1.0
import "../js/Channels.js" as Channels

Page {
    id: page

    allowedOrientations: Orientation.All

    readonly property bool isLandscape: page.width > page.height
    // Used by other pages to navigate back to the player
    readonly property bool isPlayerPage: true

    // On first launch, suggest picking a channel from the pull-down menu
    function _showFirstLaunchHint() {
        if (radio.firstLaunch && status === PageStatus.Active && !pullDownMenu.active)
            firstLaunchHint.start()
    }

    onStatusChanged: _showFirstLaunchHint()

    Connections {
        target: radio
        onFirstLaunchChanged: firstLaunchHint.stop()
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            id: pullDownMenu

            onActiveChanged: {
                if (active)
                    firstLaunchHint.stop()
            }

            MenuItem {
                text: qsTr("About")
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("AboutPage.qml"))
            }
            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: qsTr("Offline cache")
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("CachePage.qml"))
            }
            MenuItem {
                text: qsTr("Channels")
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("ChannelsPage.qml"))
            }
            MenuItem {
                text: radio.tracking ? qsTr("Stop tracking") : qsTr("Track without playing")
                visible: !radio.offline
                onClicked: radio.setTracking(!radio.tracking)
            }
            MenuItem {
                text: qsTr("Back to live radio")
                visible: radio.offline
                onClicked: radio.setChannel(radio.channel.id)
            }
        }

        Column {
            id: column
            width: page.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: radio.offline ? radio.offlineTitle : radio.channel.title
                description: radio.offline
                             ? qsTr("Offline, track %1 of %2").arg(radio.offlineIndex + 1).arg(radio.offlineCount)
                             : "Radio Paradise"
            }

            Item {
                id: coverContainer
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(page.width, page.height) - 2 * Theme.horizontalPageMargin
                       - (page.isLandscape ? 4 * Theme.itemSizeLarge : 0)
                height: width

                Image {
                    id: coverImage
                    anchors.fill: parent
                    source: radio.firstLaunch ? "" : radio.cover
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    visible: status === Image.Ready
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !coverImage.visible
                    color: Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity)

                    Icon {
                        anchors.centerIn: parent
                        visible: !radio.firstLaunch
                        source: "image://theme/icon-l-music"
                    }

                    Image {
                        anchors.centerIn: parent
                        visible: radio.firstLaunch
                        width: Theme.iconSizeExtraLarge
                        height: width
                        source: "/usr/share/icons/hicolor/172x172/apps/harbour-sailparadise.png"
                        sourceSize.width: width
                        sourceSize.height: height
                    }
                }
            }

            // Tapping the song offers its page on the website
            ListItem {
                width: parent.width
                contentHeight: songColumn.height + 2 * Theme.paddingSmall
                enabled: radio.title !== ""
                onClicked: {
                    radio.findSongId()
                    openMenu()
                }

                menu: ContextMenu {
                    MenuItem {
                        text: radio.songId !== "" ? qsTr("Song info and comments")
                                                  : radio.songIdLookupRunning ? qsTr("Looking up song…")
                                                                              : qsTr("Song not found on Radio Paradise")
                        enabled: radio.songId !== ""
                        onClicked: Qt.openUrlExternally(Channels.songPageUrl(radio.songId))
                    }
                }

                Column {
                    id: songColumn
                    y: Theme.paddingSmall
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: radio.idle ? qsTr("Not playing") : radio.title
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeLarge
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: radio.artist
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeMedium
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        visible: radio.album !== ""
                        text: radio.year !== "" ? radio.album + " (" + radio.year + ")" : radio.album
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }
                }
            }

            Slider {
                id: positionSlider
                width: parent.width
                visible: radio.offline
                enabled: radio.seekable
                minimumValue: 0
                maximumValue: Math.max(1, radio.duration)
                valueText: Format.formatDuration(value / 1000, Formatter.DurationShort)
                label: Format.formatDuration(radio.duration / 1000, Formatter.DurationShort)
                onDownChanged: {
                    if (!down)
                        radio.seek(value)
                }

                // Not a binding: dragging the slider would break it
                Connections {
                    target: radio
                    onPositionChanged: {
                        if (!positionSlider.down)
                            positionSlider.value = radio.position
                    }
                }
            }

            Item {
                width: parent.width
                height: Theme.itemSizeLarge

                IconButton {
                    anchors {
                        right: playButton.left
                        rightMargin: Theme.paddingLarge
                        verticalCenter: parent.verticalCenter
                    }
                    visible: radio.offline
                    enabled: radio.hasPrevious || radio.position > 0
                    icon.source: "image://theme/icon-m-previous"
                    onClicked: radio.previous()
                }

                IconButton {
                    id: playButton
                    anchors.centerIn: parent
                    icon.source: radio.active ? "image://theme/icon-l-pause"
                                              : "image://theme/icon-l-play"
                    onClicked: radio.toggle()
                }

                IconButton {
                    anchors {
                        left: playButton.right
                        leftMargin: Theme.paddingLarge
                        verticalCenter: parent.verticalCenter
                    }
                    visible: radio.offline
                    enabled: radio.hasNext
                    icon.source: "image://theme/icon-m-next"
                    onClicked: radio.next()
                }

                BusyIndicator {
                    anchors.centerIn: parent
                    size: BusyIndicatorSize.Large
                    running: radio.buffering
                }
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.secondaryColor
                opacity: Theme.opacityHigh
                visible: radio.showQualityInfo && radio.qualityLabel !== ""
                text: {
                    var parts = [radio.qualityLabel]
                    // Offline playback is already shown in the header
                    if (!radio.offline) {
                        if (radio.connectionType === NetworkMonitor.Mobile)
                            parts.push(qsTr("Mobile data"))
                        else if (radio.connectionType === NetworkMonitor.WiFi)
                            parts.push(qsTr("Wi-Fi"))
                    }
                    return parts.join(" · ")
                }
            }

            // Offered when the stream kept its quality after connecting to Wi-Fi
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: radio.qualitySwitchAvailable
                text: qsTr("Switch to %1").arg(radio.targetQualityLabel)
                onClicked: radio.switchQuality()
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: radio.errorString !== ""
                text: radio.errorString
                color: Theme.errorColor
                font.pixelSize: Theme.fontSizeExtraSmall
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
        }

        VerticalScrollDecorator {}
    }

    InteractionHintLabel {
        anchors.bottom: parent.bottom
        text: qsTr("Pull down and open Channels to pick a channel")
        opacity: firstLaunchHint.running ? 1.0 : 0.0
        Behavior on opacity { FadeAnimation {} }
    }

    TouchInteractionHint {
        id: firstLaunchHint
        direction: TouchInteraction.Down
        anchors.horizontalCenter: parent.horizontalCenter
        loops: 3
    }
}
