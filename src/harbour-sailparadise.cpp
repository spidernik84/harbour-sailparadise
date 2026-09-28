#include <QGuiApplication>
#include <QQmlContext>
#include <QQuickView>
#include <QScopedPointer>
#include <QtQml>

#include <sailfishapp.h>

#include "appversion.h"
#include "blockcache.h"
#include "channelimages.h"
#include "networkmonitor.h"

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    app->setApplicationVersion(QStringLiteral(APP_VERSION));

    qmlRegisterUncreatableType<BlockCache>("harbour.sailparadise", 1, 0, "BlockCache",
                                           QStringLiteral("Use the blockCache context property"));
    qmlRegisterUncreatableType<NetworkMonitor>("harbour.sailparadise", 1, 0, "NetworkMonitor",
                                               QStringLiteral("Use the networkMonitor context property"));

    BlockCache blockCache;
    NetworkMonitor networkMonitor;
    ChannelImages channelImages(&networkMonitor);

    QScopedPointer<QQuickView> view(SailfishApp::createView());
    view->rootContext()->setContextProperty(QStringLiteral("blockCache"), &blockCache);
    view->rootContext()->setContextProperty(QStringLiteral("networkMonitor"), &networkMonitor);
    view->rootContext()->setContextProperty(QStringLiteral("channelImages"), &channelImages);
    view->setSource(SailfishApp::pathToMainQml());
    view->show();

    return app->exec();
}
