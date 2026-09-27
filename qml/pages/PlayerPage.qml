import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.sailparadise 1.0

Page {
    id: page

    allowedOrientations: Orientation.All

    readonly property bool isLandscape: page.width > page.height
    // Used by other pages to navigate back to the player
    readonly property bool isPlayerPage: true

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
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
                    source: radio.cover
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
                        source: "image://theme/icon-l-music"
                    }
                }
            }

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall

                Label {
                    width: parent.width
                    text: radio.title
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
}
