#include <QGuiApplication>
#include <QQmlContext>
#include <QQuickView>
#include <QScopedPointer>
#include <QtQml>

#include <sailfishapp.h>

#include "blockcache.h"
#include "networkmonitor.h"

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));

    qmlRegisterUncreatableType<BlockCache>("harbour.sailparadise", 1, 0, "BlockCache",
                                           QStringLiteral("Use the blockCache context property"));
    qmlRegisterUncreatableType<NetworkMonitor>("harbour.sailparadise", 1, 0, "NetworkMonitor",
                                               QStringLiteral("Use the networkMonitor context property"));

    BlockCache blockCache;
    NetworkMonitor networkMonitor;

    QScopedPointer<QQuickView> view(SailfishApp::createView());
    view->rootContext()->setContextProperty(QStringLiteral("blockCache"), &blockCache);
    view->rootContext()->setContextProperty(QStringLiteral("networkMonitor"), &networkMonitor);
    view->setSource(SailfishApp::pathToMainQml());
    view->show();

    return app->exec();
}
