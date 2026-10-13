# Villupaatukaaran (வில்லுப்பாட்டுக்காரன்) 🪕

A sleek, modern desktop & mobile music streaming client inspired by the traditional Tamil folk art *Villu Paatu*. Featuring an Apple Music-inspired dark graphite glassmorphic UI with signature red accents, gapless streaming, and an integrated native Linux audio engine.

---

## ✨ Highlights

- **Translucent Glassmorphism**: Translucent dark graphite surfaces (`#1C1C1E`) with signature Apple Music Red accents (`#FA243C`).
- **Minimal Hierarchical Sidebar**: Direct navigation starting with **Home**, **Library** (All Songs, Downloaded, Cached, Local Files, Liked Songs), and **Playlists**.
- **Hero Spotlight & Curated Albums**: Traditional bard spotlight, interactive 5-album carousel with 3D thumbnail artwork, and popular track splits.
- **Persistent Player Dock Bar**: Continuous scrubber with live timestamps, dynamic volume slider with mute toggle, shuffle, and 3-state repeat mode (Off / All / One).
- **Slide-Out Queue Drawer**: Smooth panel for Up Next tracks with automatic smart preloading for gapless playback.
- **Offline Caching & Downloads**: Automatic background caching (up to 350 songs) and offline audio downloads via Hive.
- **Self-Contained Linux Audio Engine**: Bundled `libmpv` with dynamic topological FFI loading — works out-of-the-box on Linux without manual package configuration.
- **Bot-Bypass Audio Streaming**: Intelligent streaming resolution bypassing YouTube verification challenges.

---

## 🚀 Download & Installation

### Linux Debian / Ubuntu Package (`.deb`)
Download the `.deb` package from the [Releases](https://github.com/gokulnaatheswaran/villupaatukaaran/releases) page:

```bash
# Install with apt or dpkg
sudo apt install ./villupaatukaaran_1.1.0_amd64.deb
# or
sudo dpkg -i villupaatukaaran_1.1.0_amd64.deb

# Launch from your app launcher or via CLI:
villupaatukaaran
```

### Standalone Portable Bundle (`.tar.gz`)
```bash
# Extract the release bundle
tar -xzf villupaatukaaran-linux-x64.tar.gz

# Run Villupaatukaaran directly
./villupaatukaaran/villupaatukaaran
```

---

## 🛠️ Build from Source

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x or higher)
- Clang, CMake, and GTK 3 development libraries (`libgtk-3-dev`)

### Run Locally
```bash
# 1. Clone repository
git clone https://github.com/gokulnaatheswaran/villupaatukaaran.git
cd villupaatukaaran

# 2. Get dependencies
flutter pub get

# 3. Run application
flutter run -d linux
```

### Build Release Bundle
```bash
flutter build linux --release
```

---

## 📦 Tech Stack

- **Framework**: Flutter (Dart)
- **Audio Core**: `just_audio` + `audio_service` + `just_audio_media_kit` (`libmpv`)
- **State Management & DI**: GetX
- **Local Persistence**: Hive (JSON Maps)
- **Stream Extraction**: Innertube API (`WEB_REMIX`) + `yt-dlp`

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
