import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    allowedOrientations: Orientation.All

    readonly property string donateUrl: "https://radioparadise.com/support"
    readonly property string repositoryUrl: "https://github.com/spidernik84/harbour-sailparadise"

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: page.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: qsTr("About")
            }

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.iconSizeExtraLarge
                height: width
                source: "/usr/share/icons/hicolor/172x172/apps/harbour-sailparadise.png"
                sourceSize.width: width
                sourceSize.height: height
            }

            Column {
                width: parent.width

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "SailParadise"
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeLarge
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Version %1").arg(Qt.application.version)
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("A Radio Paradise player for Sailfish OS.")
            }

            SectionHeader {
                text: qsTr("Radio Paradise")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Radio Paradise is an independent internet radio station. "
                           + "Its eclectic mixes of rock, pop, world, electronica, jazz and more "
                           + "are hand-picked by real humans, not by algorithms, and streamed "
                           + "in high quality all around the world.")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                text: qsTr("Radio Paradise is 100% listener-supported: no ads, no commercial "
                           + "sponsors. It only exists thanks to donations from people like you.")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("If you enjoy the music, please consider supporting them.")
            }

            ButtonLayout {
                Button {
                    text: qsTr("Donate to Radio Paradise")
                    preferredWidth: Theme.buttonWidthLarge
                    onClicked: Qt.openUrlExternally(page.donateUrl)
                }
            }

            SectionHeader {
                text: qsTr("This app")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("SailParadise is an unofficial app and is not affiliated with Radio Paradise.")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: "© 2026 spidernik84"
            }

            ButtonLayout {
                Button {
                    text: qsTr("Source code")
                    onClicked: Qt.openUrlExternally(page.repositoryUrl)
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
