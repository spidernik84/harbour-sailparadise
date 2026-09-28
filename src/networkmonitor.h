#ifndef NETWORKMONITOR_H
#define NETWORKMONITOR_H

#include <QObject>

class QNetworkConfigurationManager;

// Tells whether the device is currently online through Wi-Fi or mobile data.
// Uses Qt bearer management, which is backed by Connman on Sailfish OS.
class NetworkMonitor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(ConnectionType connectionType READ connectionType NOTIFY connectionTypeChanged)
    Q_PROPERTY(bool online READ online NOTIFY onlineChanged)

public:
    enum ConnectionType {
        Unknown,    // offline, or a bearer we cannot classify
        WiFi,       // WLAN or wired
        Mobile      // cellular data
    };
    Q_ENUM(ConnectionType)

    explicit NetworkMonitor(QObject *parent = nullptr);

    ConnectionType connectionType() const;
    bool online() const;

signals:
    void connectionTypeChanged();
    void onlineChanged();

private:
    void update();

    QNetworkConfigurationManager *m_manager;
    ConnectionType m_connectionType = Unknown;
    bool m_online = false;
};

#endif // NETWORKMONITOR_H
