#pragma once
#include "Track.h"
#include <QAbstractListModel>

// Plain list model for the queue. The controller owns all queue logic; this class only keeps rows and the "current" marker consistent.
class QueueModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
public:
    enum Role { IdRole = Qt::UserRole + 1, TitleRole, ArtistRole, AlbumRole, DurationRole, FavoriteRole, CurrentRole };
    using QAbstractListModel::QAbstractListModel;

    int rowCount(const QModelIndex &p = {}) const override { return p.isValid() ? 0 : int(m_t.size()); }
    QVariant data(const QModelIndex &ix, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return int(m_t.size()); }
    const Track &at(int i) const { return m_t.at(i); }
    const QList<Track> &tracks() const { return m_t; }
    int indexOfId(qint64 id) const;

    void insert(int at, const QList<Track> &ts);
    Track take(int i);
    void move(int from, int to);        // `to` is the final row of the moved item
    void clear();
    void replace(int i, const Track &t);
    void setCurrent(int i);

signals:
    void countChanged();
private:
    QList<Track> m_t;
    int m_cur = -1;
};