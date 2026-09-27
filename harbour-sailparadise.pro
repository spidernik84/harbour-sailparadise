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

# The version shown on the About page is defined in the RPM spec. Qt Creator runs
# qmake itself and never executes the spec's %build section, so read it from there.
SPEC_FILE = $$PWD/rpm/harbour-sailparadise.spec
isEmpty(VERSION) {
    SPEC_LINES = $$cat($$SPEC_FILE, lines)
    SPEC_VERSION = $$find(SPEC_LINES, ^Version:)
    VERSION = $$replace(SPEC_VERSION, ^Version:\\s*, )
}
isEmpty(VERSION): error("Cannot read the version from $$SPEC_FILE")
# Re-run qmake when the spec changes
QMAKE_INTERNAL_INCLUDED_FILES += $$SPEC_FILE

# A generated header rather than DEFINES: make does not rebuild objects when only
# DEFINES change. The header is only rewritten when the version changes.
VERSION_HEADER = $$OUT_PWD/appversion.h
VERSION_HEADER_CONTENT = "$${LITERAL_HASH}define APP_VERSION \"$$VERSION\""
!equals(VERSION_HEADER_CONTENT, $$cat($$VERSION_HEADER, blob)) {
    write_file($$VERSION_HEADER, VERSION_HEADER_CONTENT)|error("Cannot write $$VERSION_HEADER")
}
INCLUDEPATH += $$OUT_PWD

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
    qml/pages/AboutPage.qml \
    qml/pages/CacheDetailPage.qml \
    qml/pages/CachePage.qml \
    qml/pages/ChannelsPage.qml \
    qml/pages/PlayerPage.qml \
    qml/pages/SettingsPage.qml \
    rpm/harbour-sailparadise.changes.in \
    rpm/harbour-sailparadise.changes.run.in \
    rpm/harbour-sailparadise.spec \
    translations/*.ts \
    harbour-sailparadise.desktop \
    icons/harbour-sailparadise.svg

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172

# to disable building translations every time, comment out the
# following CONFIG line
CONFIG += sailfishapp_i18n

# German translation is enabled as an example. If you aren't
# planning to localize your app, remember to comment out the
# following TRANSLATIONS line. And also do not forget to
# modify the localized app name in the the .desktop file.
TRANSLATIONS += translations/harbour-sailparadise-de.ts
