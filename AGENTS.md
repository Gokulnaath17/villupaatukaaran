# AGENTS.md — Villupaatukaaran (Flutter/Dart)

## Project Status
**Active & Implemented**: Flutter application scaffolded, fully implemented, verified, and running on Linux.

## Source of Truth
- `architecture/ARCHITECTURE.md` — master index + end-to-end flows
- `architecture/08_clone_spec.md` — buildable contract (module manifest, API contracts, DB schemas, state machines, test plan)
- `architecture/01_*.md`–`07_*.md` — exhaustive per-subsystem logs

## Core Subsystems & Components

### 1. Audio Playback & Linux Native Engine
- `LinuxAudioInit` (`lib/utils/linux_audio_init.dart`): Pre-loads bundled shared libraries (`libmpv.so`, `libmujs`, `liblua5.2`, `libjack`, `libopenal`, etc.) via Dart FFI `DynamicLibrary.open` in topological dependency order into memory before `JustAudioMediaKit.ensureInitialized` runs. Enables out-of-the-box Linux playback without requiring system package installation or manual `LD_LIBRARY_PATH`.
- `MyAudioHandler` (`lib/services/audio_handler.dart`): Inherits from `BaseAudioHandler` with `QueueHandler` and `SeekHandler`. Connects `AudioService` with `just_audio.AudioPlayer`. Tracks explicit `_currentQueueIndex` to avoid single-audio-source index reset bugs.

### 2. Stream Resolution & Bot Bypass
- `StreamService` (`lib/services/stream_service.dart`): 3-tier resolution:
  1. `SongsCache` (locally cached audio file)
  2. `SongDownloads` (saved offline audio file)
  3. `SongsUrlCache` (unexpired stream URL, 30 min grace)
  4. Fallback: `yt-dlp` CLI extraction with `--extractor-args "youtube:player_client=android,mweb,web"` and format `-f "ba/b/18"`, bypassing YouTube bot verification challenges.

### 3. Metadata & Discovery
- `MusicService` (`lib/services/music_service.dart`): Direct YouTube Music Innertube API (`POST https://music.youtube.com/youtubei/v1/*`) with `WEB_REMIX` client context and spoofed browser headers.
- `DiscoverController` (`lib/services/discover_controller.dart`): Manages quick picks, charts, top songs, and live search suggestions.

### 4. Persistence (Hive JSON)
- Untyped Hive boxes storing standard `Map<String, dynamic>` (no custom TypeAdapters):
  - Eager: `SongsCache`, `SongDownloads`, `SongsUrlCache`, `AppPrefs`
  - Lazy: `LibraryPlaylists`, `LIBFAV` (Liked songs), `LIBRP` (Recently played, cap 30), `searchQuery` (cap 10)

### 5. UI Architecture & Design Language
- **Boxy Geometry**: `BorderRadius.zero` throughout. AMOLED pure black (`#000000`), dark card surfaces (`#0D0D0D`), 1px borders (`#222222`), and golden yellow accents (`#FFB800`).
- **Responsive Dual-Pane Desktop Layout**: Left pane (scrollable feed, tabs for Discover, Library, Settings), Right pane (sticky Player Card with live reorderable Queue underneath).
- **Song Actions**: Play Next, Add to Queue, Like/Favorite, Add to Playlist, Download for Offline.
- **Unified Library Screen**: Playlists, Liked Songs, and Cached Tracks in a single multi-tab view.
- **Settings Screen**: Base folder selection (Audio, Video, Cache), auto-cache toggle, and cache limit slider (default 350 songs).

---

## Build & Test Commands

```bash
# Fetch dependencies
flutter pub get

# Static analysis (must be 0 issues)
flutter analyze

# Unit and integration tests
flutter test

# Run application on Linux
flutter run -d linux

# Build Linux debug bundle
flutter build linux --debug

# Build Linux release bundle
flutter build linux --release
```

---

## Known Gotchas & Solved Bugs

1. **Linux Dynamic Library Loading**:
   - `libmpv.so` dynamically requires `libmujs.so.3`, `liblua5.2.so.0`, `libopenal.so.1`, etc.
   - Solved using `LinuxAudioInit.ensureInitialized()` which opens each `.so` in topological order using `DynamicLibrary.open` prior to `JustAudioMediaKit` setup. CMakeLists also specifies `INSTALL_RPATH "$ORIGIN/lib"` and `BUILD_RPATH "${CMAKE_CURRENT_SOURCE_DIR}/lib"`.

2. **YouTube Bot Verification ("Sign in to confirm you're not a bot" / HTTP 429)**:
   - Solved in `StreamService` by passing `--extractor-args "youtube:player_client=android,mweb,web"` and format selection `-f "ba/b/18"`.

3. **AudioHandler Single-Source Index Reset**:
   - When playing an individual `AudioSource.uri`, `just_audio`'s `currentIndexStream` emits 0.
   - Solved with explicit `_currentQueueIndex` tracking in `MyAudioHandler`, ensuring the queue pointer stays on the actual item being played.

4. **Hive Map Type Casts**:
   - Hive returns `Map<dynamic, dynamic>`. Always convert to `Map<String, dynamic>.from(data)` before reading/parsing JSON maps.