#include "channelimages.h"

#include "networkmonitor.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QImage>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>

namespace {

const char *const UserAgent = "SailParadise (SailfishOS)";
const int MaxAgeDays = 30;

} // namespace

ChannelImages::ChannelImages(NetworkMonitor *networkMonitor, QObject *parent)
    : QObject(parent)
    , m_networkMonitor(networkMonitor)
    , m_network(new QNetworkAccessManager(this))
    , m_root(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/channels"))
{
    QDir().mkpath(m_root);

    connect(m_networkMonitor, &NetworkMonitor::onlineChanged, this, [this]() {
        if (m_networkMonitor->online()) {
            // Give images that failed while offline or on a bad connection another chance
            m_attempted.clear();
            scheduleUpdate();
        }
    });
}

int ChannelImages::revision() const
{
    return m_revision;
}

QString ChannelImages::source(int channelId, const QString &url)
{
    if (m_urls.value(channelId) != url) {
        m_urls.insert(channelId, url);
        scheduleUpdate();
    }

    const QFileInfo info(path(channelId));
    if (!info.exists())
        return QString();

    // The modification time makes the URL change when the image is replaced,
    // so Image reloads it instead of showing its cached copy
    QUrl local = QUrl::fromLocalFile(info.absoluteFilePath());
    local.setQuery(QStringLiteral("t=%1").arg(info.lastModified().toMSecsSinceEpoch()));
    return local.toString();
}

QString ChannelImages::path(int channelId) const
{
    return m_root + QStringLiteral("/%1.jpg").arg(channelId);
}

bool ChannelImages::needsUpdate(int channelId) const
{
    const QFileInfo info(path(channelId));
    return !info.exists()
            || info.lastModified().daysTo(QDateTime::currentDateTime()) >= MaxAgeDays;
}

void ChannelImages::scheduleUpdate()
{
    // source() is called from bindings, start downloads from the event loop instead
    if (m_updateScheduled)
        return;
    m_updateScheduled = true;
    QTimer::singleShot(0, this, &ChannelImages::update);
}

void ChannelImages::update()
{
    m_updateScheduled = false;
    if (!m_networkMonitor->online())
        return;

    for (auto it = m_urls.cbegin(); it != m_urls.cend(); ++it) {
        if (!m_attempted.contains(it.key()) && needsUpdate(it.key())) {
            m_attempted.insert(it.key());
            download(it.key(), it.value());
        }
    }
}

void ChannelImages::download(int channelId, const QString &url)
{
    QNetworkRequest request((QUrl(url)));
    request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);
    request.setRawHeader("User-Agent", UserAgent);

    QNetworkReply *reply = m_network->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply, channelId, url]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "Cannot download channel image" << url << reply->errorString();
            return;
        }

        // Do not replace a good image with an error page
        const QByteArray data = reply->readAll();
        if (QImage::fromData(data).isNull()) {
            qWarning() << "Invalid channel image" << url;
            return;
        }

        QSaveFile file(path(channelId));
        if (!file.open(QIODevice::WriteOnly) || file.write(data) != data.size() || !file.commit()) {
            qWarning() << "Cannot write channel image" << file.fileName() << file.errorString();
            return;
        }

        m_revision++;
        emit revisionChanged();
    });
}
