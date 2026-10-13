# Villupaatukaaran (வில்லுப்பாட்டுக்காரன்) 🪕

[![Release](https://img.shields.io/github/v/release/gokulnaatheswaran/villupaatukaaran?style=flat-square&color=FA243C)](https://github.com/gokulnaatheswaran/villupaatukaaran/releases)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows-lightgrey?style=flat-square)](https://github.com/gokulnaatheswaran/villupaatukaaran/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

A sleek, lightweight desktop and mobile music client inspired by the traditional Tamil folk art *Villu Paatu*. Crafted with an Apple Music-inspired dark graphite glassmorphic aesthetic (`#1C1C1E` / `#FA243C`), gapless streaming, background playback, offline caching, and out-of-the-box native audio support.

---

## 🚀 Downloads

Grab the latest release from the [GitHub Releases](https://github.com/gokulnaatheswaran/villupaatukaaran/releases/latest) page:

| Platform | Format | Description |
| :--- | :--- | :--- |
| **Linux (Debian / Ubuntu / Mint)** | [`.deb`](https://github.com/gokulnaatheswaran/villupaatukaaran/releases/latest) | Complete native installer with desktop launcher, CLI binary, and icons |
| **Linux (All Distros / Portable)** | [`.tar.gz`](https://github.com/gokulnaatheswaran/villupaatukaaran/releases/latest) | Standalone portable bundle with all dynamic libraries bundled |
| **Windows (10 / 11 64-bit)** | [`.zip`](https://github.com/gokulnaatheswaran/villupaatukaaran/releases/latest) | Portable Windows package — extract and run `villupaatukaaran.exe` |

### Installation

#### Linux (`.deb`)
```bash
sudo apt install ./villupaatukaaran_1.1.0_amd64.deb
# or
sudo dpkg -i villupaatukaaran_1.1.0_amd64.deb

# Launch via application menu or terminal:
villupaatukaaran
```

#### Linux Portable (`.tar.gz`)
```bash
tar -xzf villupaatukaaran_1.1.0_linux_x64.tar.gz
cd villupaatukaaran
./villupaatukaaran
```

#### Windows (`.zip`)
1. Download `villupaatukaaran_windows_x64.zip`.
2. Extract the archive to any folder.
3. Double-click `villupaatukaaran.exe`.

---

## ✨ Features

- **Dark Graphite Glassmorphism**: Translucent surfaces, subtle borders, and signature Apple Music Red accents (`#FA243C`).
- **Apple Music-Style System Tray**: Dynamic track status, media transport controls (Play/Pause, Skip, Like), window visibility toggle, and background playback interception.
- **Offline Download Manager**: Observable download queue with real-time progress indicators and instant zero-network cache-to-download promotion.
- **Folder-Aware Local Library**: Recursive multi-folder local music indexing, folder grouping, drag-and-drop reordering, and local-only shuffle playback.
- **Self-Contained Linux Audio Engine**: Bundled `libmpv` with dynamic topological FFI loading — works immediately without manual system library configuration.
- **YouTube Bot Verification Bypass**: Intelligent multi-tiered streaming resolver bypassing verification roadblocks.
- **Responsive Viewport**: Fluid, overflow-free layout adapting smoothly across window sizes and screen resolutions.

---

## 🛠️ Build from Source

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.24.5 or higher
- **Linux**: Clang, CMake, and GTK 3 development headers (`sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev`)
- **Windows**: Visual Studio 2022 with "Desktop development with C++"

### Build Steps

```bash
# 1. Clone repository
git clone https://github.com/gokulnaatheswaran/villupaatukaaran.git
cd villupaatukaaran

# 2. Install dependencies
flutter pub get

# 3. Run in development
flutter run -d linux      # on Linux
flutter run -d windows    # on Windows

# 4. Build release bundle
flutter build linux --release    # Linux bundle
flutter build windows --release  # Windows bundle
```

To create a Debian package on Linux:
```bash
bash scripts/build_deb.sh
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
