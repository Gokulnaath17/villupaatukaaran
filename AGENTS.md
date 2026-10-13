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
- **Modern Translucent Glassmorphism (Apple Music Dark Gray to Red Palette)**: Translucent graphite-slate surfaces (`Color(0xE61C1C1E)`, `Color(0x8028282B)`), 14–22px rounded geometry, subtle 1px translucent borders (`Color(0x1AFFFFFF)`), and signature **Apple Music Red** accents (`#FA243C`).
- **Desktop Architecture (inspired by `mod.png`)**:
  - **Left Sidebar**: Pure minimal hierarchical navigation with nothing at the top:
    - **Home** (Spotlight, Albums, Popular tracks)
    - **Library** (Hierarchical dropdown: All Songs, Downloaded, Cached, Local Files, Liked Songs with live reactive badges)
    - **Playlists** (Hierarchical dropdown: All Playlists, user playlists, and `+` playlist creator)
    - **Settings** & **Offline Cache** card (`ready` status, quota usage, quick vault access)
  - **Main Viewport Area**:
    - Sleek Top Navigation Bar: Breadcrumb trail (`LIBRARY / DOWNLOADED`), instant search input, and queue toggle.
    - Hero Artist Spotlight: Cutout silhouette of Tamil Villu Paatu Bard with curved musical bow & bells, verified badge, shuffle, and circular Apple Music Red play button. Quick spotlight pills (Subbu Arumugam, Ilaiyaraaja, AR Rahman, Anirudh).
    - 5-Album Carousel Row: Vibrant minimalist album cards (Yellow, Cyan, Lavender, Pastel Pink, Mint Teal).
    - Two-Column Lower Split: Left "Popular" tracks list with active container & EQ; Right 2x2 photographic grid for curated playlists.
  - **Attached Bottom Player Dock Bar**: Persistent edge-to-edge dock with track info, `Cached ✓` status, transport controls (Shuffle, Previous, Play/Pause, Next, **Repeat Cycle: Off/All/One**), continuous 3px sleek scrubber with white dot thumb indicator, live timestamps, volume slider, and `QUEUE` trigger.
  - **Slide-Out Queue Drawer**: Slide-out panel displaying Up Next queue with smart preloading indicator for seamless gapless playback.
- **Song Actions**: Play Next, Add to Queue, Like/Favorite, Add to Playlist, Download for Offline.
- **Unified Library Screen**: Direct category view driven directly by the sidebar navigation hierarchy (All Songs, Downloaded, Cached Tracks, Local Files, Liked Songs, Playlists) without redundant top sub-navigation buttons.
- **Settings Screen**: Base folder selection (Audio, Video, Cache), auto-cache toggle, cache limit slider (default 350 songs), and Window Close Action selector (Ask every time, Play in background, Exit application).

### 6. Desktop System Tray & Window Manager Integration
- `TrayAndWindowService` (`lib/services/tray_and_window_service.dart`):
  - **Apple Music-Style System Tray**: Dynamic context menu displaying active track info, media controls (Play/Pause, Next, Previous, Favorite/Like), Open/Hide window toggle, and Quit. Left-clicking the tray icon brings the window to the foreground.
  - **Window Close Interception**: Uses `window_manager` to prevent abrupt window destruction. If close action is set to `ask`, displays a dark glassmorphic dialog with a "Do not ask again" checkbox.
  - **Background Playback vs Exit**: Allows seamless background playback while minimized to tray or complete clean exit with session persistence. Preference is managed in `SettingsController` and persisted in `AppPrefs`.

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

5. **Safe Int Parsing & Duration Deserialization (`String is not a subtype of type int?`)**:
   - Upstream services or cache entries may store duration as string (e.g. `"245"` or `"4:05"`).
   - Solved with `_safeInt(val)` helper across `StreamService`, `SongItem`, `PlaylistItem`, and `CacheService` to safely parse numbers, numeric strings, and `"mm:ss"` formats without casting exceptions.

6. **Direct Local & Download Offline Playback (No YouTube Lookup)**:
   - For local tracks (`videoId.startsWith('local_')`) and downloaded tracks, playback failed when passed to `StreamService.getStreamingData()`. Solved with first-class local file resolution in `MyAudioHandler.playByIndex()` checking `extras['url']`, `SongDownloads`, and `SongsCache` for valid files on disk and playing directly via `AudioSource.file(path)`.

7. **Human-Readable Offline Filenames**:
   - Downloads previously saved as obscure IDs (`${song.videoId}.$ext`). Solved with `generateSongFileName(song, ext)` which writes `${artist} - ${title}.${ext}` with path-safe character sanitization.

8. **In-Memory Liked State Sync & Factory Reset**:
   - `PlayerController` in-memory `likedSongIds` set wasn't cleared when `SettingsController.resetEntireApp()` wiped the `LIBFAV` box, leaving heart icons active. Solved with reactive `_favBox.watch()` synchronization and explicit `playerController.clearLikedState()` invocation during reset.

9. **Multi-Folder Local Library, Grouping, Reorder & Local Shuffle**:
   - `LibraryService` recursively scans the unified base directory and all user-granted additional directories, groups songs by folder (`localSongsByFolder`), supports drag-and-drop reordering with persistent custom order, and provides `PLAY ALL` / `SHUFFLE ALL` that queues only local tracks without radio continuation.