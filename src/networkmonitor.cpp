#include "networkmonitor.h"

#include <QDebug>
#include <QNetworkConfiguration>
#include <QNetworkConfigurationManager>

NetworkMonitor::NetworkMonitor(QObject *parent)
    : QObject(parent)
    , m_manager(new QNetworkConfigurationManager(this))
{
    connect(m_manager, &QNetworkConfigurationManager::configurationAdded, this, &NetworkMonitor::update);
    connect(m_manager, &QNetworkConfigurationManager::configurationRemoved, this, &NetworkMonitor::update);
    connect(m_manager, &QNetworkConfigurationManager::configurationChanged, this, &NetworkMonitor::update);
    connect(m_manager, &QNetworkConfigurationManager::onlineStateChanged, this, &NetworkMonitor::update);
    update();
}

NetworkMonitor::ConnectionType NetworkMonitor::connectionType() const
{
    return m_connectionType;
}

void NetworkMonitor::update()
{
    // Cellular data may stay connected while Wi-Fi is up, but Wi-Fi then carries
    // the traffic, so any active Wi-Fi or wired connection wins.
    bool wifi = false;
    bool mobile = false;
    const QList<QNetworkConfiguration> active = m_manager->allConfigurations(QNetworkConfiguration::Active);
    for (const QNetworkConfiguration &config : active) {
        switch (config.bearerTypeFamily()) {
        case QNetworkConfiguration::BearerWLAN:
        case QNetworkConfiguration::BearerEthernet:
            wifi = true;
            break;
        case QNetworkConfiguration::Bearer2G:
        case QNetworkConfiguration::Bearer3G:
        case QNetworkConfiguration::Bearer4G:
        case QNetworkConfiguration::BearerCDMA2000:
        case QNetworkConfiguration::BearerWCDMA:
        case QNetworkConfiguration::BearerHSPA:
        case QNetworkConfiguration::BearerLTE:
            mobile = true;
            break;
        default:
            break;
        }
    }

    const ConnectionType type = wifi ? WiFi : (mobile ? Mobile : Unknown);
    if (type != m_connectionType) {
        m_connectionType = type;
        qDebug() << "Connection type changed:" << type;
        emit connectionTypeChanged();
    }
}
