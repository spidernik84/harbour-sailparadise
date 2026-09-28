#ifndef CHANNELIMAGES_H
#define CHANNELIMAGES_H

#include <QHash>
#include <QObject>
#include <QSet>

class QNetworkAccessManager;
class NetworkMonitor;

// Keeps a local copy of the channel images, so they are shown without a
// connection. An image is only downloaded while online, when it is missing or
// older than a month.
class ChannelImages : public QObject
{
    Q_OBJECT
    // Changes whenever an image was downloaded, for bindings to re-evaluate source()
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged)

public:
    explicit ChannelImages(NetworkMonitor *networkMonitor, QObject *parent = nullptr);

    int revision() const;

    // Local URL of the image of a channel, or an empty string if it was never
    // downloaded. url is where the image is downloaded from.
    Q_INVOKABLE QString source(int channelId, const QString &url);

signals:
    void revisionChanged();

private:
    QString path(int channelId) const;
    bool needsUpdate(int channelId) const;
    void scheduleUpdate();
    void update();
    void download(int channelId, const QString &url);

    NetworkMonitor *m_networkMonitor;
    QNetworkAccessManager *m_network;
    QString m_root;
    QHash<int, QString> m_urls;     // channel id -> remote URL
    QSet<int> m_attempted;          // tried since the connection came up, successfully or not
    bool m_updateScheduled = false;
    int m_revision = 0;
};

#endif // CHANNELIMAGES_H
