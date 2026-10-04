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
            text: radio.offline ? qsTr("Offline") + " · " + radio.offlineTitle : radio.channel.title
            color: Theme.secondaryHighlightColor
            font.pixelSize: Theme.fontSizeExtraSmall
            truncationMode: TruncationMode.Fade
        }

        Label {
            width: parent.width
            text: radio.idle ? qsTr("Not playing") : radio.title
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
        enabled: !radio.offline

        CoverAction {
            iconSource: radio.active ? "image://theme/icon-cover-pause"
                                     : "image://theme/icon-cover-play"
            onTriggered: radio.toggle()
        }
    }

    CoverActionList {
        enabled: radio.offline

        CoverAction {
            iconSource: radio.active ? "image://theme/icon-cover-pause"
                                     : "image://theme/icon-cover-play"
            onTriggered: radio.toggle()
        }

        CoverAction {
            iconSource: "image://theme/icon-cover-next-song"
            onTriggered: radio.next()
        }
    }
}
