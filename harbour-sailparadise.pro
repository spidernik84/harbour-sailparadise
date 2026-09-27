# NOTICE:
#
# Application name defined in TARGET has a corresponding QML filename.
# If name defined in TARGET is changed, the following needs to be done
# to match new name:
#   - corresponding QML filename must be changed
#   - desktop icon filename must be changed
#   - desktop filename must be changed
#   - icon definition filename in desktop file must be changed
#   - translation filenames have to be changed

# The name of your application
TARGET = harbour-sailparadise

CONFIG += sailfishapp

QT += network

SOURCES += src/harbour-sailparadise.cpp \
    src/blockcache.cpp \
    src/networkmonitor.cpp

HEADERS += src/blockcache.h \
    src/networkmonitor.h

DISTFILES += qml/harbour-sailparadise.qml \
    qml/components/MediaControls.qml \
    qml/components/RadioPlayer.qml \
    qml/cover/CoverPage.qml \
    qml/js/Channels.js \
    qml/pages/CacheDetailPage.qml \
    qml/pages/CachePage.qml \
    qml/pages/ChannelsPage.qml \
    qml/pages/PlayerPage.qml \
    qml/pages/SettingsPage.qml \
    rpm/harbour-sailparadise.changes.in \
    rpm/harbour-sailparadise.changes.run.in \
    rpm/harbour-sailparadise.spec \
    translations/*.ts \
    harbour-sailparadise.desktop

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172

# to disable building translations every time, comment out the
# following CONFIG line
CONFIG += sailfishapp_i18n

# German translation is enabled as an example. If you aren't
# planning to localize your app, remember to comment out the
# following TRANSLATIONS line. And also do not forget to
# modify the localized app name in the the .desktop file.
TRANSLATIONS += translations/harbour-sailparadise-de.ts
