# Villupaatukaaran (வில்லுப்பாட்டுக்காரன்)

[![Release](https://img.shields.io/github/v/release/gokulnaatheswaran/villupaatukaaran?style=flat-square&color=FA243C)](https://github.com/gokulnaatheswaran/villupaatukaaran/releases)
[![Platform](https://img.shields.io/badge/platform-Linux-lightgrey?style=flat-square)](https://github.com/gokulnaatheswaran/villupaatukaaran/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

A desktop music player for Linux focused on Tamil music and YouTube streaming. Plays audio without ads or login, caches tracks for offline listening, and manages local music folders.

## Downloads

Get the latest Linux release from [GitHub Releases](https://github.com/gokulnaatheswaran/villupaatukaaran/releases/latest).

| Format | Notes |
| :--- | :--- |
| [`.deb`](https://github.com/gokulnaatheswaran/villupaatukaaran/releases/latest) | Debian / Ubuntu installer (adds desktop launcher and app menu entry) |
| [`.tar.gz`](https://github.com/gokulnaatheswaran/villupaatukaaran/releases/latest) | Portable archive for any 64-bit Linux distro |

### Install

**Debian / Ubuntu / Mint (`.deb`)**:
```bash
sudo apt install ./villupaatukaaran_1.2.0_amd64.deb
# or
sudo dpkg -i villupaatukaaran_1.2.0_amd64.deb

villupaatukaaran
```

**Portable archive (`.tar.gz`)**:
```bash
tar -xzf villupaatukaaran_1.2.0_linux_x64.tar.gz
cd villupaatukaaran
./villupaatukaaran
```

## Features

- **Streaming without ads**: Search and stream Tamil songs and playlists from YouTube without needing an account.
- **Offline cache & downloads**: Automatically caches listened tracks and lets you save songs offline to `~/Music/Villupaatukaaran`.
- **Local music**: Add local folders from your disk, group tracks, and play them offline.
- **System tray**: Background playback with tray controls (play, pause, next, previous) and minimize-to-tray.
- **Queue management**: Slide-out queue with drag-and-drop reordering.
- **Shortcuts**: `Ctrl+K` to search, `Space` to play/pause, arrow keys to seek.

## Build from Source

### Requirements
- Flutter SDK (3.24.5 or later)
- Build tools and libraries:
  ```bash
  sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libayatana-appindicator3-dev libmpv-dev
  ```

### Build Commands
```bash
# Clone
git clone https://github.com/gokulnaatheswaran/villupaatukaaran.git
cd villupaatukaaran

# Dependencies
flutter pub get

# Run dev build
flutter run -d linux

# Build release bundle
flutter build linux --release

# Package .deb installer
bash scripts/build_deb.sh 1.2.0
```

Release files are placed under `build/linux/x64/release/`.

## License

[MIT](LICENSE)

