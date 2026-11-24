#include "AudioEngine.h"
#include "ArtworkManager.h"
#include "BackupManager.h"
#include "Database.h"
#include "DesktopIntegration.h"
#include "FolderMonitor.h"
#include "LibraryModel.h"
#include "LibraryScanner.h"
#include "LyricsManager.h"
#include "MetadataEditor.h"
#include "Mpris.h"
#include "PlaybackController.h"
#include "PlaylistManager.h"
#include "Settings.h"
#include "ThemeManager.h"
#include "UndoStack.h"
#include "WavySeekbar.h"
#include <QApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QSurfaceFormat>
#include <QTimer>
#include <QtQml>
#include <QFontDatabase>
#include "IconProvider.h"

int main(int argc, char *argv[]) {
    QSurfaceFormat fmt;
    fmt.setSamples(4);                                   // smooth edges for the thin seekbar waves
    QSurfaceFormat::setDefaultFormat(fmt);

    QApplication app(argc, argv);
    app.setApplicationName("cadence-player");            // no organization: ~/.local/share/cadence-player, ~/.config/cadence-player, ~/.cache/cadence-player
    app.setApplicationDisplayName("Cadence");
    app.setDesktopFileName("cadence");
    app.setWindowIcon(QIcon(":/assets/cadence.svg"));
    for (const QString &f : {"Inter", "Noto Sans", "Ubuntu", "Cantarell", "Open Sans", "DejaVu Sans"})
    if (QFontDatabase::families().contains(f)) { QFont font(f); font.setHintingPreference(QFont::PreferNoHinting); app.setFont(font); break; }
    app.setQuitOnLastWindowClosed(false);                // the tray keeps the app alive; QML decides when to quit
    if (Mpris::raiseExisting()) return 0;                // single instance
    QQuickStyle::setStyle("Basic");

    QString err;
    if (!Database::open({}, &err)) { qCritical("Cannot open the library database: %s", qPrintable(err)); return 1; }

    Settings settings;
    UndoStack undo;
    AudioEngine engine;
    PlaybackController pc(&engine, &settings, &undo);
    LibraryScanner scanner;
    LibraryModel::setSources(&scanner, &pc);
    FolderMonitor monitor(&scanner, &settings);
    MetadataEditor meta(&pc, &scanner, &undo);
    ThemeManager theme(&pc, &settings);
    LyricsManager lyrics(&pc, &undo);
    PlaylistManager playlists(&pc, &undo);
    BackupManager backup(&pc, &scanner, &settings, &undo);
    Mpris mpris(&pc);
    DesktopIntegration desktop(&pc, &settings);

    QObject::connect(&backup, &BackupManager::restored, &playlists, &PlaylistManager::reload);
    QObject::connect(&backup, &BackupManager::restored, &lyrics, &LyricsManager::reload);
    QObject::connect(&mpris, &Mpris::raiseRequested, &desktop, &DesktopIntegration::showRequested);
    QObject::connect(&mpris, &Mpris::quitRequested, &app, &QCoreApplication::quit);
    QObject::connect(&app, &QCoreApplication::aboutToQuit, &pc, &PlaybackController::shutdown);

    QString notice;                                      // shown by QML if the database needed repair
    if (backup.checkIntegrity() == "ok") QTimer::singleShot(4000, &backup, &BackupManager::autoBackup);
    else {
        const QString r = backup.recover();
        notice = r == "ok" ? QObject::tr("The library database had problems and was repaired. A copy of the damaged file was kept.") : r;
    }
    QTimer::singleShot(1500, &scanner, [&] { if (settings.flag("library/scanOnStart", true)) scanner.rescanAll(); });   // unchanged files only cost a stat

    qmlRegisterType<WavySeekbar>("Cadence", 1, 0, "WavySeekbar");
    qmlRegisterType<LibraryModel>("Cadence", 1, 0, "LibraryModel");

    QQmlApplicationEngine qml;                           // declared last: destroyed first
    qml.addImageProvider("art", new ArtProvider);
    qml.addImageProvider("icons", new IconProvider);
    QQmlContext *c = qml.rootContext();
    c->setContextProperty("pc", &pc);
    c->setContextProperty("settings", &settings);
    c->setContextProperty("theme", &theme);
    c->setContextProperty("scanner", &scanner);
    c->setContextProperty("lyrics", &lyrics);
    c->setContextProperty("playlists", &playlists);
    c->setContextProperty("meta", &meta);
    c->setContextProperty("backup", &backup);
    c->setContextProperty("undo", &undo);
    c->setContextProperty("desktop", &desktop);
    c->setContextProperty("startupNotice", notice);
    QObject::connect(&qml, &QQmlApplicationEngine::objectCreated, &app, [](QObject *o, const QUrl &) { if (!o) QCoreApplication::exit(1); }, Qt::QueuedConnection);
    qml.load(QUrl(QStringLiteral("qrc:/qml/Main.qml")));
    return app.exec();
}