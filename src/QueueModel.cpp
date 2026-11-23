#include "QueueModel.h"
#include <QFileInfo>

QVariant QueueModel::data(const QModelIndex &ix, int role) const {
    if (!ix.isValid() || ix.row() >= m_t.size()) return {};
    const Track &t = m_t.at(ix.row());
    switch (role) {
    case IdRole: return t.id;
    case TitleRole: return t.title.isEmpty() ? QFileInfo(t.path).completeBaseName() : t.title;
    case ArtistRole: return t.artist;
    case AlbumRole: return t.album;
    case DurationRole: return t.durationMs;
    case FavoriteRole: return t.favorite;
    case CurrentRole: return ix.row() == m_cur;
    }
    return {};
}

QHash<int, QByteArray> QueueModel::roleNames() const {
    return {{IdRole, "trackId"}, {TitleRole, "title"}, {ArtistRole, "artist"}, {AlbumRole, "album"},
            {DurationRole, "durationMs"}, {FavoriteRole, "favorite"}, {CurrentRole, "isCurrent"}};
}

int QueueModel::indexOfId(qint64 id) const {
    for (int i = 0; i < m_t.size(); ++i) if (m_t.at(i).id == id) return i;
    return -1;
}

void QueueModel::insert(int at, const QList<Track> &ts) {
    if (ts.isEmpty()) return;
    at = qBound(0, at, int(m_t.size()));
    beginInsertRows({}, at, at + int(ts.size()) - 1);
    m_t = m_t.mid(0, at) + ts + m_t.mid(at);
    if (at <= m_cur) m_cur += int(ts.size());
    endInsertRows();
    emit countChanged();
}

Track QueueModel::take(int i) {
    beginRemoveRows({}, i, i);
    const Track t = m_t.takeAt(i);
    if (i < m_cur) --m_cur; else if (i == m_cur) m_cur = -1;
    endRemoveRows();
    emit countChanged();
    return t;
}

void QueueModel::move(int from, int to) {
    if (from == to || from < 0 || to < 0 || from >= m_t.size() || to >= m_t.size()) return;
    beginMoveRows({}, from, from, {}, to > from ? to + 1 : to);
    m_t.move(from, to);
    if (from == m_cur) m_cur = to; else if (from < m_cur && to >= m_cur) --m_cur; else if (from > m_cur && to <= m_cur) ++m_cur;
    endMoveRows();
}

void QueueModel::clear() { beginResetModel(); m_t.clear(); m_cur = -1; endResetModel(); emit countChanged(); }

void QueueModel::replace(int i, const Track &t) { m_t[i] = t; emit dataChanged(index(i), index(i)); }

void QueueModel::setCurrent(int i) {
    if (i == m_cur) return;
    const int o = m_cur; m_cur = i;
    for (int r : {o, i}) if (r >= 0 && r < m_t.size()) emit dataChanged(index(r), index(r), {CurrentRole});
}