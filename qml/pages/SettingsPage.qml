import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.sailparadise 1.0
import "../js/Channels.js" as Channels

Page {
    id: page

    allowedOrientations: Orientation.All

    function qualityIndex(key) {
        for (var i = 0; i < Channels.qualities.length; i++) {
            if (Channels.qualities[i].key === key)
                return i
        }
        return 0
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: page.width

            PageHeader {
                title: qsTr("Settings")
            }

            SectionHeader {
                text: qsTr("Stream quality")
            }

            ComboBox {
                label: qsTr("On Wi-Fi")
                currentIndex: page.qualityIndex(radio.wifiQuality)

                menu: ContextMenu {
                    Repeater {
                        model: Channels.qualities
                        MenuItem {
                            text: modelData.label
                            onClicked: radio.setWifiQuality(modelData.key)
                        }
                    }
                }
            }

            ComboBox {
                label: qsTr("On mobile data")
                currentIndex: page.qualityIndex(radio.mobileQuality)

                menu: ContextMenu {
                    Repeater {
                        model: Channels.qualities
                        MenuItem {
                            text: modelData.label
                            onClicked: radio.setMobileQuality(modelData.key)
                        }
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                text: {
                    var connection
                    switch (networkMonitor.connectionType) {
                    case NetworkMonitor.WiFi:
                        connection = qsTr("Currently connected via Wi-Fi.")
                        break
                    case NetworkMonitor.Mobile:
                        connection = qsTr("Currently connected via mobile data.")
                        break
                    default:
                        connection = qsTr("Connection type unknown, using the Wi-Fi quality.")
                    }
                    return connection + " "
                            + qsTr("Channels without the selected quality fall back to their default stream.")
                }
            }

            SectionHeader {
                text: qsTr("Player")
            }

            TextSwitch {
                text: qsTr("Show stream quality")
                description: qsTr("Shows the quality and connection type below the playback controls")
                checked: radio.showQualityInfo
                // Silica toggles "checked" itself, which would break the binding
                automaticCheck: false
                onClicked: radio.setShowQualityInfo(!radio.showQualityInfo)
            }
        }

        VerticalScrollDecorator {}
    }
}
