import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    allowedOrientations: Orientation.All

    readonly property bool isLandscape: page.width > page.height

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: qsTr("Channels")
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("ChannelsPage.qml"))
            }
        }

        Column {
            id: column
            width: page.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: radio.channel.title
                description: "Radio Paradise"
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

            Item {
                width: parent.width
                height: Theme.itemSizeLarge

                IconButton {
                    id: playButton
                    anchors.centerIn: parent
                    icon.source: radio.active ? "image://theme/icon-l-pause"
                                              : "image://theme/icon-l-play"
                    onClicked: radio.toggle()
                }

                BusyIndicator {
                    anchors.centerIn: parent
                    size: BusyIndicatorSize.Large
                    running: radio.buffering
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
