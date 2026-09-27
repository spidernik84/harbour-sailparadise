import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/Channels.js" as Channels

Page {
    id: page

    allowedOrientations: Orientation.All

    SilicaListView {
        anchors.fill: parent
        model: Channels.channels

        header: PageHeader {
            title: qsTr("Channels")
        }

        delegate: ListItem {
            id: item

            readonly property var channel: modelData
            readonly property bool current: channel.id === radio.channel.id

            contentHeight: Theme.itemSizeLarge
            highlighted: down || current

            onClicked: {
                radio.setChannel(channel.id)
                if (!radio.active)
                    radio.play()
                pageStack.navigateBack()
            }

            Image {
                id: channelImage
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.itemSizeMedium
                height: width
                source: Channels.imageUrl(channel.id)
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Column {
                anchors {
                    left: channelImage.right
                    leftMargin: Theme.paddingLarge
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }

                Label {
                    width: parent.width
                    text: channel.title
                    color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                    truncationMode: TruncationMode.Fade
                }

                Label {
                    width: parent.width
                    text: channel.description
                    color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    truncationMode: TruncationMode.Fade
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
