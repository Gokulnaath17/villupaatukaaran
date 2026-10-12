# Villupaatukaaran (வில்லுப்பாட்டுக்காரன்)

A high-performance, minimalist desktop & mobile music streaming client inspired by the Tamil traditional musical bow art (*Villupaatu*). Built with **Flutter**, **GetX**, **Hive**, **JustAudio**, and **MediaKit / libmpv**, featuring an AMOLED deep black design language with warm golden-amber accents.

---

## Highlights & Features

- **Minimalist Boxy Aesthetic**: Zero border-radii (`BorderRadius.zero`), crisp 1px borders, deep AMOLED black (`#000000`), and warm golden-yellow accents (`#FFB800`).
- **Responsive Dual-Pane Desktop Layout**:
  - **Left Pane**: Sticky top bar with instant search, tab navigation (Discover, Library, Settings), and scrollable feeds with zero layout overflow.
  - **Right Pane**: Sticky Player Card with real-time seek bar, transport controls, and a live scrollable Queue directly underneath.
- **Comprehensive Song Actions**:
  - ⏭️ **Play Next** (inserts immediately after currently playing track)
  - ➕ **Add to Queue** (appends to playback queue)
  - ❤️ **Like / Favorite** (instantly synced to `LIBFAV` Hive storage)
  - 📑 **Add to Playlist** (create and manage custom local playlists)
  - ⬇️ **Download for Offline** (saves to configured audio directory)
- **Unified Library Screen**:
  - **Playlists Tab**: Create, edit, and play custom playlists.
  - **Liked Songs Tab**: Instant access to favorite tracks with one-click play-all.
  - **Cached Tracks Tab**: Play tracks cached locally with zero network latency.
- **Flexible Settings & Performance**:
  - Custom base folder selection for **Audio**, **Videos**, and **Cache**.
  - Cache size limit slider (default: **350 songs**).
  - Background auto-caching for instant, zero-buffering replay.
- **Dual Streaming Resolvers**:
  - Primary: Unofficial YouTube Music Innertube API (`WEB_REMIX` client).
  - Secondary / Direct Stream: Robust `yt-dlp` stream extraction with bot verification bypass (`player_client=android,mweb,web`).
- **Self-Contained Linux Audio Backend**:
  - Bundled `libmpv.so` and 15 native dependencies in `linux/lib/`.
  - In-memory FFI preloader (`LinuxAudioInit.ensureInitialized()`) ensures playback works out-of-the-box on Linux without requiring `sudo apt install mpv` or system-wide dev packages.

---

## Architecture & Technology Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.x (Dart 3.x) |
| **State & DI** | GetX (`GetxController`, `Get.lazyPut`, `Obx`) |
| **Audio Core** | `just_audio` + `audio_service` + `just_audio_media_kit` |
| **Native Engine** | Bundled `libmpv` (Linux) with dynamic FFI preloading |
| **Persistence** | Hive (`hive_flutter`) with untyped JSON map storage |
| **Metadata API** | YouTube Music Innertube (`POST music.youtube.com/youtubei/v1/*`) |
| **Stream Extraction** | High-priority cache lookup → `yt-dlp` Android/MWeb client extractor |

---

## Project Structure

```
villupaatukaaran/
├── assets/
│   ├── icons/            # App icons, Tamil bell loader, tray icons
│   └── images/           # Wallpapers, posters, logo artwork
├── architecture/         # Reverse-engineered reference architecture specs
├── lib/
│   ├── main.dart         # App entrypoint, Hive init, service bindings
│   ├── models/           # Data models (SongItem, PlaylistItem, etc.)
│   ├── services/
│   │   ├── audio_handler.dart       # MyAudioHandler (audio_service + just_audio)
│   │   ├── cache_service.dart       # Local caching and download manager
│   │   ├── constant.dart            # Storage keys, endpoints, default settings
│   │   ├── discover_controller.dart # Discover feed and instant search state
│   │   ├── library_service.dart     # Playlist, Liked, and History manager
│   │   ├── music_service.dart       # Innertube WEB_REMIX HTTP client
│   │   ├── player_controller.dart   # UI player state bridge
│   │   ├── settings_controller.dart # Storage folders & performance config
│   │   └── stream_service.dart      # 3-tier stream resolution + yt-dlp
│   ├── ui/
│   │   ├── screens/                 # HomeScreen, DiscoverView, LibraryView, SettingsView
│   │   ├── theme/                   # AppTheme (colors, borders, swatches)
│   │   └── widgets/                 # PlayerCard, QueueList, SongTile, SearchBar, TamilBellLoader
│   └── utils/
│       ├── app_assets.dart          # Asset constants
│       └── linux_audio_init.dart    # Native shared library FFI preloader
├── linux/                           # Linux desktop shell, CMakeLists.txt, bundled lib/
├── test/                            # Unit and integration test suite
└── pubspec.yaml                     # Dependencies and asset declarations
```

---

## Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (>= 3.3.0)
- `yt-dlp` installed and available in PATH (for direct stream extraction)
- Linux build tools: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`

### Running the App
```bash
# Get dependencies
flutter pub get

# Run on Linux desktop
flutter run -d linux
```

### Running Tests & Static Analysis
```bash
# Static analysis (must have 0 issues)
flutter analyze

# Run unit and integration tests
flutter test
```

### Building for Release / Debug
```bash
# Debug bundle
flutter build linux --debug

# Release bundle
flutter build linux --release
```
The output binary will be located at `build/linux/x64/{debug|release}/bundle/villupaatukaaran`.

---

## License

This project is developed for personal and educational music streaming experimentation.
