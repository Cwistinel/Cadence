# Cadence

Local music player for Linux (Qt 6, GStreamer, TagLib).

## Build

```sh
cmake -S . -B build
cmake --build build -j"$(nproc)"
./build/cadence
```

Dependencies: Qt 6.2+ (Core, Gui, Widgets, Qml, Quick, QuickControls2, Sql, DBus, Concurrent, Svg), GStreamer 1.0, TagLib. On Debian/Ubuntu:

```sh
sudo apt install build-essential cmake qt6-base-dev qt6-declarative-dev \
  qt6-tools-dev libqt6sql6-sqlite libgstreamer1.0-dev libtag1-dev
```

## Tests

```sh
ctest --test-dir build
```