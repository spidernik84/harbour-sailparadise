import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    Image {
        id: coverImage
        anchors.fill: parent
        source: radio.coverSmall
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: 0.35
        visible: status === Image.Ready
    }

    Column {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Theme.paddingLarge
        }
        spacing: Theme.paddingSmall

        Label {
            width: parent.width
            text: radio.channel.title
            color: Theme.secondaryHighlightColor
            font.pixelSize: Theme.fontSizeExtraSmall
            truncationMode: TruncationMode.Fade
        }

        Label {
            width: parent.width
            text: radio.title
            color: Theme.highlightColor
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }

        Label {
            width: parent.width
            text: radio.artist
            color: Theme.primaryColor
            font.pixelSize: Theme.fontSizeExtraSmall
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    CoverActionList {
        CoverAction {
            iconSource: radio.active ? "image://theme/icon-cover-pause"
                                     : "image://theme/icon-cover-play"
            onTriggered: radio.toggle()
        }
    }
}
