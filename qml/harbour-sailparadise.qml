import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"
import "pages"

ApplicationWindow {
    id: app

    // Shared player instance, referenced as "radio" by pages and the cover
    RadioPlayer {
        id: radio
    }

    initialPage: Component { PlayerPage { } }
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations
}
