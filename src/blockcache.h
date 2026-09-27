#ifndef BLOCKCACHE_H
#define BLOCKCACHE_H

#include <QAbstractListModel>
#include <QDateTime>
#include <QJsonObject>
#include <QVector>

#include <functional>

class QNetworkAccessManager;
class QNetworkReply;

// Downloads Radio Paradise blocks (audio of every song plus its metadata and
// cover) to local storage for offline listening, and exposes them as a model.
class BlockCache : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    enum State {
        Queued,
        Fetching,
        Downloading,
        Paused,
        Complete,
        Failed
    };
    Q_ENUM(State)

    enum Roles {
        CacheIdRole = Qt::UserRole + 1,
        ChannelIdRole,
        ChannelTitleRole,
        QualityRole,
        CreatedRole,
        RequestedDurationRole,
        DurationRole,
        TrackCountRole,
        DownloadedCountRole,
        SizeRole,
        ProgressRole,
        StateRole,
        ErrorRole
    };

    explicit BlockCache(QObject *parent = nullptr);
    ~BlockCache() override;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool busy() const;

    // bitrate: Radio Paradise block bitrate (1 = AAC 64k, 2 = AAC 128k, 3 = AAC 320k, 4 = FLAC)
    Q_INVOKABLE QString create(int channelId, const QString &channelTitle, int bitrate, int minutes);
    Q_INVOKABLE void pause(const QString &cacheId);
    Q_INVOKABLE void resume(const QString &cacheId);
    Q_INVOKABLE void remove(const QString &cacheId);
    Q_INVOKABLE QVariantList tracks(const QString &cacheId) const;
    Q_INVOKABLE qint64 estimateSize(int bitrate, int minutes) const;
    Q_INVOKABLE qint64 freeSpace() const;

signals:
    void busyChanged();
    void tracksChanged(const QString &cacheId);

private:
    struct Track {
        QJsonObject info;       // song metadata as returned by the API
        QString audioUrl;
        QString coverUrl;
        QString audioFile;      // relative to the cache directory
        QString coverFile;      // relative to the cache directory, may be empty
        bool downloaded = false;
        qint64 size = 0;
    };

    struct Entry {
        QString id;
        int channelId = 0;
        QString channelTitle;
        int bitrate = 3;
        QString quality;
        QDateTime created;
        qint64 requestedDuration = 0;   // ms
        QString nextEvent;
        bool metadataComplete = false;
        int blocksFetched = 0;
        QVector<Track> tracks;
        State state = Queued;
        QString error;

        qint64 duration() const;
        int downloadedCount() const;
        qint64 size() const;
    };

    typedef std::function<void(QNetworkReply *reply)> ReplyHandler;

    void load();
    void save(const Entry &entry) const;
    QString directory(const QString &cacheId) const;
    int indexOf(const QString &cacheId) const;
    Entry *activeEntry();
    void setState(Entry &entry, State state, const QString &error = QString());
    void notifyChanged(const QString &cacheId, const QVector<int> &roles = QVector<int>());

    void processQueue();
    void step();
    void fetchBlock(Entry &entry);
    void handleBlock(const QString &cacheId, const QByteArray &data);
    void downloadTrack(Entry &entry, int index);
    void downloadFile(const QString &url, const QString &path, bool reportProgress,
                      const std::function<void(bool ok, const QString &error)> &done);
    void retryOrFail(const QString &error);
    void abortActive();
    void finishActive();

    QNetworkAccessManager *m_network;
    QString m_root;
    QVector<Entry> m_entries;
    QString m_activeId;
    QNetworkReply *m_reply = nullptr;
    qreal m_trackProgress = 0;
    int m_retries = 0;
};

#endif // BLOCKCACHE_H
