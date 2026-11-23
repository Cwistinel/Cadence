#pragma once
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QString>
#include <QVariantList>

class Database {
public:
    static QString path();                                                  // ~/.local/share/cadence/library.db
    static bool open(const QString &connection = {}, QString *error = nullptr);
    static QSqlDatabase get(const QString &connection = {});
    static void close(const QString &connection);
    static QSqlQuery run(const QString &sql, const QVariantList &args = {}, const QString &connection = {});
    static QString integrityCheck(const QString &connection = {});          // "ok" when healthy
};