#include "blockcache.h"

#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSaveFile>
#include <QSet>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>

#include <algorithm>

namespace {

const char *const BlockApiUrl = "https://api.radioparadise.com/api/get_block";
const char *const DefaultImageBase = "https://img.radioparadise.com/";
const char *const UserAgent = "SailParadise (SailfishOS)";
const char *const ManifestFile = "manifest.json";

const int MaxMinutes = 6 * 60;
const int MaxBlocks = 60;           // safety net, 6 h are ~25 blocks incl. promos
const int MaxRetries = 3;
const int RetryDelay = 5000;        // ms
const qint64 MinFreeSpace = 64 * 1024 * 1024;

qint64 toInt64(const QJsonValue &value)
{
    // The API mixes numbers and numeric strings
    return value.toVariant().toLongLong();
}

QString buildAudioFileName(int index, const QString &event, const QString &url)
{
    QString suffix = QFileInfo(QUrl(url).path()).suffix();
    if (suffix.isEmpty())
        suffix = QStringLiteral("m4a");
    return QStringLiteral("%1-%2.%3").arg(index, 4, 10, QLatin1Char('0')).arg(event, suffix);
}

} // namespace

qint64 BlockCache::Entry::duration() const
{
    qint64 total = 0;
    for (const Track &track : tracks)
        total += toInt64(track.info.value(QStringLiteral("duration")));
    return total;
}

int BlockCache::Entry::downloadedCount() const
{
    return std::count_if(tracks.cbegin(), tracks.cend(), [](const Track &t) { return t.downloaded; });
}

qint64 BlockCache::Entry::size() const
{
    qint64 total = 0;
    for (const Track &track : tracks)
        total += track.size;
    return total;
}

BlockCache::BlockCache(QObject *parent)
    : QAbstractListModel(parent)
    , m_network(new QNetworkAccessManager(this))
    , m_root(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/blocks"))
{
    QDir().mkpath(m_root);
    load();
}

BlockCache::~BlockCache()
{
    if (m_reply) {
        m_reply->disconnect(this);
        m_reply->abort();
    }
}

int BlockCache::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_entries.size();
}

QVariant BlockCache::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_entries.size())
        return QVariant();

    const Entry &entry = m_entries.at(index.row());
    switch (role) {
    case CacheIdRole:
        return entry.id;
    case ChannelIdRole:
        return entry.channelId;
    case ChannelTitleRole:
        return entry.channelTitle;
    case QualityRole:
        return entry.quality;
    case CreatedRole:
        return entry.created;
    case RequestedDurationRole:
        return entry.requestedDuration;
    case DurationRole:
        return entry.duration();
    case TrackCountRole:
        return entry.tracks.size();
    case DownloadedCountRole:
        return entry.downloadedCount();
    case SizeRole:
        return entry.size();
    case ProgressRole: {
        if (entry.state == Complete)
            return 1.0;
        if (entry.tracks.isEmpty())
            return 0.0;
        qreal done = entry.downloadedCount();
        if (entry.id == m_activeId && entry.state == Downloading)
            done += m_trackProgress;
        return done / entry.tracks.size();
    }
    case StateRole:
        return entry.state;
    case ErrorRole:
        return entry.error;
    }
    return QVariant();
}

QHash<int, QByteArray> BlockCache::roleNames() const
{
    // "state" would clash with Item.state in QML delegates, hence the prefixes
    QHash<int, QByteArray> roles;
    roles[CacheIdRole] = "cacheId";
    roles[ChannelIdRole] = "channelId";
    roles[ChannelTitleRole] = "channelTitle";
    roles[QualityRole] = "quality";
    roles[CreatedRole] = "created";
    roles[RequestedDurationRole] = "requestedDuration";
    roles[DurationRole] = "duration";
    roles[TrackCountRole] = "trackCount";
    roles[DownloadedCountRole] = "downloadedCount";
    roles[SizeRole] = "size";
    roles[ProgressRole] = "progress";
    roles[StateRole] = "cacheState";
    roles[ErrorRole] = "cacheError";
    return roles;
}

bool BlockCache::busy() const
{
    return !m_activeId.isEmpty();
}

QString BlockCache::create(int channelId, const QString &channelTitle, int bitrate, int minutes)
{
    Entry entry;
    entry.id = QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyyMMdd-HHmmss-zzz"));
    entry.channelId = channelId;
    entry.channelTitle = channelTitle;
    entry.bitrate = bitrate;
    entry.created = QDateTime::currentDateTime();
    entry.requestedDuration = qint64(qBound(1, minutes, MaxMinutes)) * 60 * 1000;

    if (!QDir().mkpath(directory(entry.id) + QStringLiteral("/covers"))) {
        qWarning() << "Cannot create cache directory" << directory(entry.id);
        return QString();
    }
    save(entry);

    beginInsertRows(QModelIndex(), 0, 0);
    m_entries.prepend(entry);
    endInsertRows();

    processQueue();
    return entry.id;
}

void BlockCache::pause(const QString &cacheId)
{
    const int i = indexOf(cacheId);
    if (i < 0 || m_entries.at(i).state == Complete || m_entries.at(i).state == Paused)
        return;

    if (cacheId == m_activeId)
        abortActive();

    Entry &entry = m_entries[i];
    setState(entry, Paused);
    save(entry);
    processQueue();
}

void BlockCache::resume(const QString &cacheId)
{
    const int i = indexOf(cacheId);
    if (i < 0)
        return;

    Entry &entry = m_entries[i];
    if (entry.state != Paused && entry.state != Failed)
        return;

    setState(entry, Queued);
    save(entry);
    processQueue();
}

void BlockCache::remove(const QString &cacheId)
{
    const int i = indexOf(cacheId);
    if (i < 0)
        return;

    if (cacheId == m_activeId)
        abortActive();

    beginRemoveRows(QModelIndex(), i, i);
    m_entries.remove(i);
    endRemoveRows();

    QDir(directory(cacheId)).removeRecursively();
    processQueue();
}

QVariantList BlockCache::tracks(const QString &cacheId) const
{
    QVariantList result;
    const int i = indexOf(cacheId);
    if (i < 0)
        return result;

    const Entry &entry = m_entries.at(i);
    const QString dir = directory(entry.id) + QLatin1Char('/');
    for (const Track &track : entry.tracks) {
        QVariantMap map;
        map.insert(QStringLiteral("event"), track.info.value(QStringLiteral("event")).toString());
        map.insert(QStringLiteral("type"), track.info.value(QStringLiteral("type")).toString());
        map.insert(QStringLiteral("artist"), track.info.value(QStringLiteral("artist")).toString());
        map.insert(QStringLiteral("title"), track.info.value(QStringLiteral("title")).toString());
        map.insert(QStringLiteral("album"), track.info.value(QStringLiteral("album")).toString());
        map.insert(QStringLiteral("year"), track.info.value(QStringLiteral("year")).toString());
        map.insert(QStringLiteral("duration"), toInt64(track.info.value(QStringLiteral("duration"))));
        map.insert(QStringLiteral("downloaded"), track.downloaded);
        map.insert(QStringLiteral("source"), track.downloaded
                   ? QUrl::fromLocalFile(dir + track.audioFile).toString() : QString());
        const bool hasCover = !track.coverFile.isEmpty() && QFile::exists(dir + track.coverFile);
        map.insert(QStringLiteral("cover"), hasCover
                   ? QUrl::fromLocalFile(dir + track.coverFile).toString() : QString());
        result.append(map);
    }
    return result;
}

qint64 BlockCache::estimateSize(int bitrate, int minutes) const
{
    // Measured average bitrates of the block files, in kbit/s
    int kbps;
    switch (bitrate) {
    case 1: kbps = 64; break;
    case 2: kbps = 128; break;
    case 4: kbps = 910; break;
    default: kbps = 320; break;
    }
    return qint64(kbps) * 1000 / 8 * minutes * 60;
}

qint64 BlockCache::freeSpace() const
{
    const QStorageInfo storage(m_root);
    return storage.isValid() ? storage.bytesAvailable() : -1;
}

void BlockCache::load()
{
    QDir root(m_root);
    const QStringList dirs = root.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name | QDir::Reversed);
    for (const QString &name : dirs) {
        QFile file(root.filePath(name) + QLatin1Char('/') + QLatin1String(ManifestFile));
        if (!file.open(QIODevice::ReadOnly)) {
            qWarning() << "Skipping cache without manifest:" << name;
            continue;
        }
        const QJsonObject obj = QJsonDocument::fromJson(file.readAll()).object();

        Entry entry;
        entry.id = name;
        entry.channelId = obj.value(QStringLiteral("channelId")).toInt();
        entry.channelTitle = obj.value(QStringLiteral("channelTitle")).toString();
        entry.bitrate = obj.value(QStringLiteral("bitrate")).toInt(3);
        entry.quality = obj.value(QStringLiteral("quality")).toString();
        entry.created = QDateTime::fromString(obj.value(QStringLiteral("created")).toString(), Qt::ISODate);
        entry.requestedDuration = toInt64(obj.value(QStringLiteral("requestedDuration")));
        entry.nextEvent = obj.value(QStringLiteral("nextEvent")).toString();
        entry.metadataComplete = obj.value(QStringLiteral("metadataComplete")).toBool();
        entry.blocksFetched = obj.value(QStringLiteral("blocksFetched")).toInt();
        entry.state = static_cast<State>(obj.value(QStringLiteral("state")).toInt(Paused));
        entry.error = obj.value(QStringLiteral("error")).toString();

        const QString dir = root.filePath(name) + QLatin1Char('/');
        const QJsonArray tracks = obj.value(QStringLiteral("tracks")).toArray();
        for (const QJsonValue &value : tracks) {
            const QJsonObject t = value.toObject();
            Track track;
            track.info = t.value(QStringLiteral("info")).toObject();
            track.audioUrl = t.value(QStringLiteral("audioUrl")).toString();
            track.coverUrl = t.value(QStringLiteral("coverUrl")).toString();
            track.audioFile = t.value(QStringLiteral("audioFile")).toString();
            track.coverFile = t.value(QStringLiteral("coverFile")).toString();
            track.size = toInt64(t.value(QStringLiteral("size")));
            track.downloaded = t.value(QStringLiteral("downloaded")).toBool()
                    && QFile::exists(dir + track.audioFile);
            entry.tracks.append(track);
        }

        // Downloads interrupted by quitting the app are not resumed automatically,
        // the user may be on a metered connection now.
        const bool incomplete = !entry.metadataComplete || entry.downloadedCount() < entry.tracks.size();
        if (entry.state != Failed && (entry.state != Complete || incomplete))
            entry.state = incomplete ? Paused : Complete;

        m_entries.append(entry);
    }
}

void BlockCache::save(const Entry &entry) const
{
    QJsonArray tracks;
    for (const Track &track : entry.tracks) {
        QJsonObject t;
        t.insert(QStringLiteral("info"), track.info);
        t.insert(QStringLiteral("audioUrl"), track.audioUrl);
        t.insert(QStringLiteral("coverUrl"), track.coverUrl);
        t.insert(QStringLiteral("audioFile"), track.audioFile);
        t.insert(QStringLiteral("coverFile"), track.coverFile);
        t.insert(QStringLiteral("downloaded"), track.downloaded);
        t.insert(QStringLiteral("size"), double(track.size));
        tracks.append(t);
    }

    QJsonObject obj;
    obj.insert(QStringLiteral("channelId"), entry.channelId);
    obj.insert(QStringLiteral("channelTitle"), entry.channelTitle);
    obj.insert(QStringLiteral("bitrate"), entry.bitrate);
    obj.insert(QStringLiteral("quality"), entry.quality);
    obj.insert(QStringLiteral("created"), entry.created.toString(Qt::ISODate));
    obj.insert(QStringLiteral("requestedDuration"), double(entry.requestedDuration));
    obj.insert(QStringLiteral("nextEvent"), entry.nextEvent);
    obj.insert(QStringLiteral("metadataComplete"), entry.metadataComplete);
    obj.insert(QStringLiteral("blocksFetched"), entry.blocksFetched);
    obj.insert(QStringLiteral("state"), int(entry.state));
    obj.insert(QStringLiteral("error"), entry.error);
    obj.insert(QStringLiteral("tracks"), tracks);

    QSaveFile file(directory(entry.id) + QLatin1Char('/') + QLatin1String(ManifestFile));
    if (!file.open(QIODevice::WriteOnly)
            || file.write(QJsonDocument(obj).toJson(QJsonDocument::Compact)) < 0
            || !file.commit()) {
        qWarning() << "Cannot write manifest for" << entry.id << file.errorString();
    }
}

QString BlockCache::directory(const QString &cacheId) const
{
    return m_root + QLatin1Char('/') + cacheId;
}

int BlockCache::indexOf(const QString &cacheId) const
{
    for (int i = 0; i < m_entries.size(); ++i) {
        if (m_entries.at(i).id == cacheId)
            return i;
    }
    return -1;
}

BlockCache::Entry *BlockCache::activeEntry()
{
    const int i = indexOf(m_activeId);
    return i < 0 ? nullptr : &m_entries[i];
}

void BlockCache::setState(Entry &entry, State state, const QString &error)
{
    entry.state = state;
    entry.error = error;
    notifyChanged(entry.id);
}

void BlockCache::notifyChanged(const QString &cacheId, const QVector<int> &roles)
{
    const int i = indexOf(cacheId);
    if (i >= 0)
        emit dataChanged(index(i), index(i), roles);
}

void BlockCache::processQueue()
{
    if (!m_activeId.isEmpty())
        return;

    // Oldest queued entry first; entries are sorted newest first
    for (int i = m_entries.size() - 1; i >= 0; --i) {
        if (m_entries.at(i).state == Queued) {
            m_activeId = m_entries.at(i).id;
            m_retries = 0;
            emit busyChanged();
            step();
            return;
        }
    }
}

void BlockCache::step()
{
    Entry *entry = activeEntry();
    if (!entry) {
        finishActive();
        return;
    }

    if (!entry->metadataComplete) {
        setState(*entry, Fetching);
        fetchBlock(*entry);
        return;
    }

    if (entry->tracks.isEmpty()) {
        setState(*entry, Failed, tr("No tracks available"));
        save(*entry);
        finishActive();
        return;
    }

    for (int i = 0; i < entry->tracks.size(); ++i) {
        if (entry->tracks.at(i).downloaded)
            continue;

        const qint64 free = freeSpace();
        if (free >= 0 && free < MinFreeSpace) {
            setState(*entry, Failed, tr("Not enough free storage space"));
            save(*entry);
            finishActive();
            return;
        }

        setState(*entry, Downloading);
        downloadTrack(*entry, i);
        return;
    }

    setState(*entry, Complete);
    save(*entry);
    finishActive();
}

void BlockCache::fetchBlock(Entry &entry)
{
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("bitrate"), QString::number(entry.bitrate));
    query.addQueryItem(QStringLiteral("info"), QStringLiteral("true"));
    query.addQueryItem(QStringLiteral("chan"), QString::number(entry.channelId));
    if (!entry.nextEvent.isEmpty())
        query.addQueryItem(QStringLiteral("event"), entry.nextEvent);

    QUrl url(QString::fromLatin1(BlockApiUrl));
    url.setQuery(query);

    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);
    request.setRawHeader("User-Agent", UserAgent);

    QNetworkReply *reply = m_network->get(request);
    m_reply = reply;

    const QString cacheId = entry.id;
    connect(reply, &QNetworkReply::finished, this, [this, reply, cacheId]() {
        reply->deleteLater();
        if (m_reply == reply)
            m_reply = nullptr;
        if (reply->error() == QNetworkReply::OperationCanceledError || cacheId != m_activeId)
            return;
        if (reply->error() != QNetworkReply::NoError) {
            retryOrFail(reply->errorString());
            return;
        }
        handleBlock(cacheId, reply->readAll());
    });
}

void BlockCache::handleBlock(const QString &cacheId, const QByteArray &data)
{
    Entry *entry = activeEntry();
    if (!entry || entry->id != cacheId)
        return;

    const QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) {
        retryOrFail(tr("Invalid response from Radio Paradise"));
        return;
    }

    const QJsonObject block = doc.object();
    const QJsonObject songs = block.value(QStringLiteral("song")).toObject();
    const QString blockUrl = block.value(QStringLiteral("url")).toString();

    QString imageBase = block.value(QStringLiteral("image_base")).toString();
    if (imageBase.isEmpty())
        imageBase = QLatin1String(DefaultImageBase);
    else if (imageBase.startsWith(QLatin1String("//")))
        imageBase.prepend(QStringLiteral("https:"));

    if (entry->quality.isEmpty())
        entry->quality = block.value(QStringLiteral("bitrate")).toString();

    QStringList keys = songs.keys();
    std::sort(keys.begin(), keys.end(), [](const QString &a, const QString &b) { return a.toInt() < b.toInt(); });

    QSet<QString> known;
    for (const Track &track : entry->tracks)
        known.insert(track.info.value(QStringLiteral("event")).toString());

    for (const QString &key : keys) {
        const QJsonObject song = songs.value(key).toObject();
        const QString event = song.value(QStringLiteral("event")).toString();
        if (event.isEmpty() || known.contains(event))
            continue;

        QString audioUrl = song.value(QStringLiteral("gapless_url")).toString();
        if (audioUrl.isEmpty() && keys.size() == 1)
            audioUrl = blockUrl;    // single-song blocks, e.g. station IDs
        if (audioUrl.isEmpty()) {
            qWarning() << "No audio file for event" << event;
            continue;
        }

        Track track;
        track.info = song;
        track.audioUrl = audioUrl;
        track.audioFile = buildAudioFileName(entry->tracks.size(), event, audioUrl);
        const QString cover = song.value(QStringLiteral("cover")).toString();
        if (!cover.isEmpty()) {
            track.coverUrl = imageBase + cover;
            track.coverFile = QStringLiteral("covers/") + QFileInfo(cover).fileName();
        }
        entry->tracks.append(track);
        known.insert(event);
    }

    const QString endEvent = block.value(QStringLiteral("end_event")).toString();
    const bool stalled = endEvent.isEmpty() || endEvent == entry->nextEvent;
    entry->nextEvent = endEvent;
    ++entry->blocksFetched;
    m_retries = 0;

    if (stalled || entry->duration() >= entry->requestedDuration || entry->blocksFetched >= MaxBlocks)
        entry->metadataComplete = true;

    save(*entry);
    notifyChanged(cacheId);
    emit tracksChanged(cacheId);
    step();
}

void BlockCache::downloadTrack(Entry &entry, int index)
{
    const QString cacheId = entry.id;
    const QString dir = directory(cacheId) + QLatin1Char('/');
    m_trackProgress = 0;

    auto downloadAudio = [this, cacheId, dir, index]() {
        Entry *entry = activeEntry();
        if (!entry || entry->id != cacheId)
            return;

        const Track &track = entry->tracks.at(index);
        downloadFile(track.audioUrl, dir + track.audioFile, true,
                     [this, cacheId, dir, index](bool ok, const QString &error) {
            Entry *entry = activeEntry();
            if (!entry || entry->id != cacheId)
                return;
            if (!ok) {
                retryOrFail(error);
                return;
            }

            Track &track = entry->tracks[index];
            track.downloaded = true;
            track.size = QFileInfo(dir + track.audioFile).size();
            m_retries = 0;
            m_trackProgress = 0;

            save(*entry);
            notifyChanged(cacheId);
            emit tracksChanged(cacheId);
            step();
        });
    };

    const Track &track = entry.tracks.at(index);
    if (!track.coverFile.isEmpty() && !QFile::exists(dir + track.coverFile)) {
        downloadFile(track.coverUrl, dir + track.coverFile, false,
                     [downloadAudio](bool ok, const QString &error) {
            if (!ok)
                qWarning() << "Cover download failed:" << error;
            downloadAudio();
        });
    } else {
        downloadAudio();
    }
}

void BlockCache::downloadFile(const QString &url, const QString &path, bool reportProgress,
                              const std::function<void(bool, const QString &)> &done)
{
    // Write to a temporary file so an interrupted download never looks complete
    const QString partPath = path + QStringLiteral(".part");

    QNetworkRequest request((QUrl(url)));
    request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);
    request.setRawHeader("User-Agent", UserAgent);

    QNetworkReply *reply = m_network->get(request);
    m_reply = reply;

    QFile *file = new QFile(partPath, reply);
    if (!file->open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        const QString error = tr("Cannot write file: %1").arg(file->errorString());
        m_reply = nullptr;
        reply->disconnect(this);
        reply->abort();
        reply->deleteLater();
        done(false, error);
        return;
    }

    connect(reply, &QNetworkReply::readyRead, file, [file, reply]() {
        file->write(reply->readAll());
    });

    if (reportProgress) {
        connect(reply, &QNetworkReply::downloadProgress, this, [this, reply](qint64 received, qint64 total) {
            if (reply != m_reply || total <= 0)
                return;
            const qreal progress = qreal(received) / total;
            // Throttle model updates to whole percents
            if (progress - m_trackProgress >= 0.01 || progress >= 1.0) {
                m_trackProgress = progress;
                notifyChanged(m_activeId, QVector<int>() << ProgressRole);
            }
        });
    }

    connect(reply, &QNetworkReply::finished, this, [this, reply, file, path, partPath, done]() {
        reply->deleteLater();
        if (m_reply == reply)
            m_reply = nullptr;

        const bool canceled = reply->error() == QNetworkReply::OperationCanceledError;
        bool ok = reply->error() == QNetworkReply::NoError;
        QString error = reply->errorString();

        if (ok) {
            file->write(reply->readAll());
            ok = file->flush() && file->error() == QFileDevice::NoError;
            if (!ok)
                error = tr("Cannot write file: %1").arg(file->errorString());
        }
        file->close();

        if (ok) {
            QFile::remove(path);
            ok = QFile::rename(partPath, path);
            if (!ok)
                error = tr("Cannot write file: %1").arg(path);
        }
        if (!ok)
            QFile::remove(partPath);

        if (!canceled)
            done(ok, error);
    });
}

void BlockCache::retryOrFail(const QString &error)
{
    Entry *entry = activeEntry();
    if (!entry)
        return;

    if (m_retries < MaxRetries) {
        ++m_retries;
        qWarning() << "Cache download error, retrying:" << error;
        const QString cacheId = entry->id;
        QTimer::singleShot(RetryDelay, this, [this, cacheId]() {
            if (m_activeId == cacheId && !m_reply)
                step();
        });
        return;
    }

    setState(*entry, Failed, error);
    save(*entry);
    finishActive();
}

void BlockCache::abortActive()
{
    m_activeId.clear();
    m_trackProgress = 0;
    if (m_reply) {
        QNetworkReply *reply = m_reply;
        m_reply = nullptr;
        reply->abort();
    }
    emit busyChanged();
}

void BlockCache::finishActive()
{
    m_activeId.clear();
    m_trackProgress = 0;
    m_retries = 0;
    emit busyChanged();
    // Start the next queued download outside of the current call chain
    QTimer::singleShot(0, this, [this]() { processQueue(); });
}
