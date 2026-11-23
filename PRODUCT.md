# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Someone on a Linux desktop who already owns a music folder and wants to browse and play it without an account, a stream, or a cloud. They expect the player to behave like a desktop app: launch fast, keep a tray icon, respond to media keys, remember where it was.

## Product Purpose

Cadence plays a local music library. It scans folders, keeps a searchable library of songs, albums, artists and playlists in SQLite, and plays through GStreamer. Success means the user finds a track in seconds and hears it, and never worries that a rescan, a metadata edit, or a crash cost them data.

## Positioning

Three things a neighboring Linux player does not combine:

- **The current album art sets the theme.** The whole palette, including a contrast-adjusted accent, is derived from the playing track's artwork (cached, computed off the UI thread).
- **Lyrics are first-class.** Synced lyrics with a live current-line highlight, an editor, embedded/file/edited sources, and per-track typography controls.
- **The user's data is theirs and stays local.** No network, no accounts; metadata editing, playlists, lyrics edits and preferences are covered by undo, automatic daily backups and restore with a safety copy.

## Operating Context

- Linux desktop (GNOME/KDE and similar), audio through PipeWire or PulseAudio via GStreamer.
- A music folder on disk, possibly with FLAC/MP3/M4A, embedded artwork, and CUE sheets.
- MPRIS consumers: media keys, desktop media widgets, `playerctl`.
- Long-running background use: tray icon, track-change notifications, close-to-tray, a compact mini player.
- Restoring window size and position across sessions and screens.

## Capabilities and Constraints

Confirmed in code: library scan and folder monitoring; songs/albums/artists/folders/favorites/recently-played/recently-added views; queue and playlists (M3U import); metadata editing with undo; lyrics parsing, editing and timing; CUE sheet virtual tracks; daily auto-backup, integrity check and repair; MPRIS and single-instance; tray and notifications; mini player; light/dark/auto theming; window geometry persistence. Qt 6.2+, C++17, CMake, SQLite, TagLib, GStreamer.

Undecided or incomplete, not to be invented: the settings surface (`Main.qml` routes to `SettingsView.qml`, which does not exist yet); app icon and wordmark (`assets/cadence.svg` is referenced by CMake and `main.cpp` but absent); no test suite and no README.

## Brand Commitments

The product name is **Cadence**. No logo, wordmark, voice guide or other brand assets exist yet; nothing beyond the name is binding.

## Evidence on Hand

Source code only. No README, screenshots, marketing copy, testimonials, benchmarks or user research. Future work must not fabricate claims about library sizes, performance, or user numbers.

## Product Principles

1. **The local library is the source of truth.** No feature may depend on a network call or an account.
2. **Never lose the user's work.** Edits are undoable and recoverable; destructive operations make a safety copy first.
3. **The playing track sets the mood.** The interface follows the artwork, not a fixed skin, and stays legible when the art is not.
4. **Browsing a big library must feel instant.** Scanning and artwork work stay off the UI thread; unchanged files cost a stat.
5. **Act like a desktop citizen.** Tray, MPRIS, notifications, geometry restore and single-instance are part of the product, not extras.
