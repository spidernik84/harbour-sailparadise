import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/Channels.js" as Channels

Page {
    id: page

    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: page.width

            PageHeader {
                title: qsTr("Settings")
            }

            ComboBox {
                label: qsTr("Stream quality")
                description: qsTr("Channels without the selected quality fall back to their default stream")

                currentIndex: {
                    for (var i = 0; i < Channels.qualities.length; i++) {
                        if (Channels.qualities[i].key === radio.quality)
                            return i
                    }
                    return 0
                }

                menu: ContextMenu {
                    Repeater {
                        model: Channels.qualities
                        MenuItem {
                            text: modelData.label
                            onClicked: radio.setQuality(modelData.key)
                        }
                    }
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
