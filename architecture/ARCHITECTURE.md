# Harmony Music — Reverse-Engineered Architecture (Clone Blueprint)

> Source: `/home/gokul/Dev/Github/self/Harmony-Music` — Flutter `harmonymusic v1.12.2+27`
> Purpose: exact working-mechanism log to rebuild a functionally-identical clone.
> Split detail files in this folder; this file is the single master index + end-to-end flows.

## 0. What this app is

Cross-platform (Android, Windows, Linux; iOS/macOS/web stubs) music-streaming client for
YouTube / YouTube Music **without login, without ads**:
- Content metadata via **unofficial YouTube-Music Innertube API** (`POST https://music.youtube.com/youtubei/v1/*` with `WEB_REMIX` client).
- Audio bytes via **`youtube_explode_dart` (forked)** stream-manifest resolver.
- Playback via **`just_audio` + `audio_service` + `just_audio_media_kit` (MPV on desktop)**.
- Persistence via **Hive untyped boxes holding JSON maps** (no TypeAdapters).
- State/DI/Navigation via **GetX** (`lazyPut fenix:true`, `Obx`, nested `Navigator id=1`).
- Playlists sync optionally via **Piped API**. Lyrics via **LRCLIB + YTM `getLyrics` fallback**.

See `01_*`–`08_*` for exhaustive per-subsystem logs.

## 1. End-to-end startup (blocking order)

```
main() [lib/main.dart]
├─ WidgetsFlutterBinding.ensureInitialized()
├─ await initHive() — Hive.initFlutter(appDocs|[support]/db) + openBox(SongsCache,SongDownloads,SongsUrlCache,AppPrefs)
├─ _setAppInitPrefs() if AppPrefs empty: {themeModeType:0, cacheSongs:false, skipSilenceEnabled:false,
│   streamingQuality:1(High), themePrimaryColor:0xFF000000-ish, discoverContentType:QP,
│   newVersionVisibility:updateCheckFlag(false for F-Droid), cacheHomeScreenData:true}
├─ startApplicationServices() [sync, not awaited]: 11x Get.lazyPut(fenix:true):
│   PipedServices, MusicServices, ThemeController, PlayerController, HomeScreenController,
│   LibrarySongs/Playlists/Albums/ArtistsController, SettingsScreenController, Downloader
│   + desktop: SearchScreenController(lazy) + DesktopSystemTray(put)
├─ Get.put(await initAudioService(), permanent:true)
│   └─ AudioService.init(builder:()=>MyAudioHandler(), config: icon mipmap/ic_launcher_monochrome,
│      channelId com.mycompany.myapp.audio, channelName Harmony Music Notification,
│      ongoing:true, stopForegroundOnPause:true)
│      └─ MyAudioHandler() ctor: JustAudioMediaKit.title/protocolWhitelist (Win/Lin),
│         AudioPlayer(AndroidLoadControl min50s/max120s/playback50ms/rebuffer2s),
│         temp/cachedSongs/ dir, empty ConcatenatingAudioSource, listeners
│         (playbackEvent→notification, position→auto-next, duration→mediaItem patch,
│         androidAudioSessionId→Equalizer init), restore loop/shuffle/skipSilence prefs
├─ WidgetsBinding.addObserver(LifecycleHandler: detached→saveSession)
├─ SystemChrome edgeToEdge + TerminateRestart.initialize()
└─ runApp(GetMaterialApp(home:Home, translations:Languages, locale:AppPrefs.currentAppLanguageCode??en))
    ├─ ThemeController ctor (themePrimaryColor/mode + brightness listener)
    ├─ SettingsScreenController.onInit (defaults, support/Music dir, version check)
    ├─ MusicServices.onInit → init(): clientVersion=1.YYYYMMDD.01.00, signatureTimestamp=days-1,
    │   hlCode=contentLanguage??en, visitorId cache 30d or scrape or fallback
    ├─ PlayerController.onInit/onReady (listeners, prefs, WindowsAudioService on Win, restore prevSessionData)
    ├─ HomeScreenController.onInit (Db cache if cacheHomeScreenData else network; >8h stale→silent refresh)
    ├─ LibrarySongs/Playlists/Albums/Artists init + Piped sync + housekeeping (purge expired URLs/missing files)
    ├─ Mobile: AppLinksController (cold+warm links) | Desktop: DesktopSystemTray (2s delay)
    └─ Home.build: SlidingUpPanel(Player) + ScreenNavigation(nested Navigator) + MiniPlayer header + Bottom/SideNav
```

## 2. Core pipelines (must replicate exactly for clone)

### A. Content fetch (metadata, no audio)
`MusicServices (GetxService, Dio)` → `_sendRequest(action,data)` → `POST $baseUrl$action$fixedParms?key=AIzaSyC9XL...`
with `_headers{user-agent Chrome114, origin music.youtube.com, cookie CONSENT, X-Goog-Visitor-Id}`
and `_context{client:{WEB_REMIX, version, hl}, user:{}, playbackContext:{signatureTimestamp}}`.
- `getHome(limit)` → `browse{FEmusic_home}` → `parseMixedContent` + `getContinuations(sectionListContinuation)`.
- `getWatchPlaylist({videoId,playlistId,radio,shuffle})` → **queue/radio source**: strip `MPED`, default `RDAMVM<id>`,
  `params wAEB(radio)/wAEB8gECKAE%3D(shuffle)`, `POST next`, parse `playlistPanelRenderer` via `parseWatchPlaylist`,
  paginate `playlistPanelContinuation`, return `{tracks,playlistId,lyricsBrowseId,related,additionalParamsForNext}`.
- `getPlaylistOrAlbumSongs`, `search` (+`getSearchParams` base64 filters), `getSearchSuggestion`,
  `getArtist`/`getArtistRealtedContent`, `getCharts`, `getContentRelatedToSong`, `getLyrics(browseId)`,
  `getSongYear`, `getSongWithId` (player endpoint → Music check → watchPlaylist).
- All JSON parsing in `nav_parser.dart: nav()` safe-traverse + `parse*` → `MediaItem/Album/Artist/Playlist`.
- Pagination in `continuations.dart: getContinuations / getContinuationsPlaylist` via `ctoken`+`continuation`.
- Helpers `utils.dart: getDatestamp, parseDuration, validatePlaylistId(strip VL), isExpired(expire= regex),
  getSearchParams, parseMenuPlaylists, getDotSeparatorIndex`.

### B. Stream resolution (audio URL, no playback)
`audio_handler.checkNGetUrl(songId,{generateNewUrl})` 3-tier priority:
1. `SongsCache` hit → `file://tmp/cachedSongs/<id>.mp3` pseudo-`HMStreamingData(playable:true)`.
2. `SongDownloads` hit + file exists (`support/Music` direct else ext-permission check) → playable; else online fallback.
3. `SongsUrlCache` hit && !expired (`isExpired(url)` = `now+1800<expire` epoch) → reuse; else
   `Isolate.run(()=>getStreamInfo(songId,RootIsolateToken))` → `background_task.getStreamInfo`
   → `StreamProvider.fetch(id)` → `YoutubeExplode.streamsClient.getManifest` → `audioOnly[]→Audio{itag,codec mp4a/opus,bitrate,duration,loudnessDb,url,size}`
   → cache `hmStreamingData{playable,statusMSG,low(249/139),high(251/140)}`, pick by `AppPrefs.streamingQuality (0 Low/1 High)`.

### C. Playback
`MyAudioHandler extends BaseAudioHandler` owns `_player:AudioPlayer` + `_playList:ConcatenatingAudioSource([])`:
- `_createAudioSource(mediaItem)`: if `url.contains(/cache)` or (`cacheSongs && http`) → `LockCachingAudioSource(cacheFile tmp/cachedSongs/<id>.mp3)` else `AudioSource.uri`.
- `customAction playByIndex{index,newUrl,restoreSession,position}`: set loading, clear list, `mediaItem.add(song)`,
  `await checkNGetUrl`, stale-guard, error→`PlayerController.notifyPlayError`+404 state, else set `currentSongUrl=extras[url]=streamInfo.audio.url`, add source, loudness-normalize (Android), `play()` or `load+seek(x2)` if restore.
- `setSourceNPlay{mediaItem}` single-song fast path. `checkWithCacheDb`: promote ≥98%-buffered temp file to `SongsCache`.
- Transport: `play/pause/seek/skipToQueueItem→playByIndex`, `skipToNext/Previous` (prev: >5s→seek0), `_getNext/PrevSongIndex` (shuffle via `shuffledQueue`, linear+`queueLoop`), `setRepeatMode/setShuffleMode`, `reorderQueue/addPlayNextItem/shuffleQueue/clearQueue(keep 0)`, `toggleSkipSilence/toggleLoudnessNormalization/setVolume/openEqualizer/saveSession`.
- Auto-advance: `positionStream` vs `duration-offset(Win200/Lin700/else0)` → `_triggerNext` (single-loop→seek0 else next).
- Error recovery: `playbackEventStream.onError`: LockCaching `Connection closed`→seek+play else `playByIndex(newUrl:true)+seek(savedPos)`.
- State broadcast: `playbackState{controls [prev,play/pause,next], compact [0,1,2], systemActions{seek}, processingState, repeat/shuffle, playing, position, buffered, speed, queueIndex}` → drives notification + `PlayerController.buttonState`.
- Buffer config `AndroidLoadControl(50s/120s/50ms/2s)`, `setSkipSilenceEnabled`, `_normalizeVolume(db)=10^((-5-db)/20)`.
- Session: `saveSessionData` (if `restorePlaybackSession`) → `prevSessionData{queue:[json],position,index}` on `saveSession/detached/onTaskRemoved/window-close`.

### D. Queue/radio (PlayerController ↔ handler)
`PlayerController (GetxController)`: `currentQueue.obs, currentSong Rxn, progressBarStatus{current,buffered,total}, buttonState{paused,playing,loading}, isLoop/Shuffle/QueueLoop, isRadioModeOn+radioContinuationParam+radioInitiatorItem, sleepTimer, volume, lyrics`.
- Listens: `playbackState→button+wakelock`, `position→progressBar+endOfSong-sleep`, `buffered→≥98%→checkWithCacheDb once`, `mediaItem→total/currentSong/index/fav/RP/radio-continuation`, `queue→currentQueue`.
- `pushSongToQueue(item,{playlistId,radio})`: `getWatchPlaylist` → `updateQueue(tracks)` → shuffleCmd if needed; `playlistId==null` → `setSourceNPlay` fast-path else panel+`playByIndex(0)`; disables queueLoop if radio.
- `playPlayListSong(list,index)`, `startRadio(item)` + `_addRadioContinuation` (last-track trigger, `limit24+additionalParamsNext` → `enqueueSongList` deduped), `enqueue/playNext/remove/clear/shuffle/reorder`, `seek/play/pause/prev/next`, toggles (shuffle/loop/queueLoop guarded vs radio), `volume/mute`, `fav+autoDownload`, `_addToRP(LIBRP cap30)`, `showLyrics`, `sleepTimer{minutes/+5/endOfSong/cancel}`, `_restorePrevSession`.

## 3. Persistence (Hive JSON, no adapters)

Eager boxes: `SongsCache, SongDownloads, SongsUrlCache, AppPrefs`. Lazy (open/close per op):
`LibraryPlaylists, per-playlist Box(id), LibraryAlbums+per-album, LibraryArtists, LIBFAV, LIBRP, searchQuery, homeScreenData, prevSessionData, blacklistedPlaylist, lyrics`.
Canonical song JSON: `MediaItemBuilder.toJson/fromJson {videoId,title,album,artists,length,duration,date,thumbnails:[{url}],url,trackDetails,year} + streamInfo=[bool,AudioJson] + duration`.
`Playlist{playlistId,title,thumbnailUrl,description,songCount,isPipedPlaylist,isCloudPlaylist}`,
`Album{browseId,audioPlaylistId,title,description,artists,year,thumbnailUrl}`, `Artist{name,browseId,radioId,subscribers,thumbnailUrl}`,
`HMStreamingData{playable,statusMSG,low/high,qualityIndex}`, `Thumbnail.sizewith`, `QuickPicks`, `PlaylingFrom{ALBUM,PLAYLIST,SELECTION,ARTIST}`, `ProgressBarState`.
Default `AppPrefs` keys: theme, language, quality, cache/skipSilence/loudness, nav/player UI, discover type, paths, formats, piped token, restore/background/wakelock flags. **Bug to note:** `audio_handler:89` + `theme_controller` use lowercase `appPrefs` (separate empty box).

## 4. UI + state + theming + lyrics + downloads + platform

- Navigation: `ScreenNavigationSetup{id=1}` nested `Navigator` (`/homeScreen,/searchScreen,/searchResultScreen,/artistScreen,/albumScreen,/playlistScreen`); `Home` root (`PopScope`+`CallbackShortcuts(space)`+`Scaffold[SlidingUpPanel(Player)+ScreenNavigation+MiniPlayer header+Bottom/SideNav+endDrawer queue]`); tab maps differ bottom(4) vs side/desktop(6); `HomeScreenController.tabIndex`, `whenHomeScreenOnTop`, per-id `Key` + `Get.put(tag:Key(id).hashCode)`.
- Screens: Home(feed QuickPicks+middle+fixed, 8h cache), Search(history/suggestions/url-detect→Results+tabs+50%-scroll pagination), Library(4 controllers + PipedSync + sort/search/batch), Player(Standard/Gesture+Mini+UpNext queue panel), Settings(6 expansion tiles, ~25 Rx prefs), Album/Playlist/Artist detail (parallax, bookmark/play/enqueue/download/share/export, tagged controllers).
- GetX: `lazyPut fenix:true` singletons + per-route tagged puts + `Get.delete` on close; `.obs/Rx/Rxn/RxList/RxMap` + `Obx/GetX` + `AnimatedScreenTransition`; `Get.arguments`, `Get.nestedKey(1)`, `Get.dialog/locale/context/Platform`.
- Theme: `ThemeController{ThemeType dynamic/system/dark/light}`, `PaletteGenerator(200px)→dominant→darken lightness 0.10`, `_createMaterialColor` swatch, `GoogleFonts.inter`, `useMaterial3:false`, `AnimatedTheme 700ms`, Win title-bar `MethodChannel win_titlebar_color`.
- Lyrics: `SyncedLyricsService.getSyncedLyrics` (`lyrics` box else `GET lrclib.net/api/get?artist+track+album+duration` → cache `{synced,plainLyrics}`) else `getWatchPlaylist(onlyRelated)→lyricsBrowseId→getLyrics`; render `flutter_lyric LyricsReader(UINetease)` vs `SelectableText`, `lyricsMode` toggle persisted.
- Downloads: `Downloader{playlistQueue,songQueue,progress obs,isJobRunning}` → `checkPermissionNDir` (SDK<30 storage vs ≥30 manageExternalStorage, desktop bypass) → `download/downloadPlaylist→triggerDownloadingJob→downloadSongList→writeFileStream(StreamProvider.fetch→format opus/m4a highest→sanitize→dio.download Range→year/thumb→SongDownloads.put→AudioTags.write)`.
- Cache: `cacheSongs→LockCachingAudioSource`; `checkWithCacheDb` promotion; `house_keeping.removeExpiredSongsUrlFromDb/removeDeletedOfflineSongsFromDb`; quality `streamingQuality`; skip-silence `just_audio`; EQ `jni Equalizer(open/init/end)` on `androidAudioSessionId`; loudness `_normalizeVolume`; sleep timer `Timer.periodic` + position `total-pos==1s`.
- Share/import/export/backup: `share_plus Share.share(youtube.com/watch)`, `url_launcher` externals, `app_links` (`youtube.com/music/youtu.be` → playlist/album/artist/song + `SEND text/plain`), `FilePicker+archive` backup `*.hmb`(zip of `*.hive`+Music+thumbs)/restore (wipe hive, unzip, rewrite desktop paths, restart via `terminate_restart`), playlist JSON/CSV export to `~/Downloads/HarmonyMusic`, JSON import to `LIB<ms>`.
- Desktop: `window_manager` (hide/show/preventClose) + `tray_manager` (icon ico/png, menu Show/Hide/Prev/Play/Next/Quit→saveSession+exit) in `DesktopSystemTray`; `smtc_windows` `WindowsAudioService` (buttonPress→controller, metadata, position); `audio_service_mpris` Linux auto (no Dart import); `wakelock_plus` on `playing&&keepScreenAwake`; `permission_handler` storage/battery; `terminate_restart` after restore.
- Android: `AudioServiceActivity`, manifest perms (storage, wake, foreground+mediaPlayback, internet, battery-opt) + `AudioService`+`MediaButtonReceiver` + `automotive_app_desc` (Auto) + `MediaLibrary` browsable tree (`songs/favorites/albums/playlists/recent`) + `SEND/VIEW/BROWSABLE` link filters; native `Equalizer.kt/SDKInt.kt` via `jnigen→andrid_utils.dart`; notification `AudioServiceConfig`.
- Build: `flutter_distributor` (`distribute_options.yaml` + `linux/packaging deb/rpm/appimage` mpv deps + `windows/packaging exe inno_setup.iss` GUID `B9F6E402…`), `fastlane/metadata` F-Droid listings, GH Actions `code_quality.yml` (analyze+apk) + `win_exe.yml` (localization gen, flag `updateCheckFlag=true`, package, osslsigncode with `win_cert/`).

## 5. Clone build order (see 08_clone_spec.md)

1. Scaffold Flutter + GetX + Hive boxes + GoRouter-equivalent nested nav.
2. Implement Innertube client (`constant+music_service+nav_parser+continuations+utils`) + verify `getHome/search/watchPlaylist` against fixtures.
3. Implement stream resolver (`stream_service+background isolate`) + quality switch + expiry.
4. Implement audio handler (`just_audio+audio_service`, Concatenating+LockCaching, playByIndex state machine, error recovery, session save/restore).
5. Implement PlayerController bridge (queue, radio continuation, RP/fav, sleep, lyrics, volume).
6. Implement persistence schemas + library CRUD + housekeeping.
7. Implement UI screens + widgets + theming + localization.
8. Implement downloads + cache + EQ + loudness + skip-silence.
9. Implement share/links/backup/restore + tray/SMTC/MPRIS/Auto/notification + platform shells + CI/packaging.

## 6. File map (this folder)

- `01_bootstrapping_and_di.md` — main, Hive, GetX DI, lifecycle.
- `02_content_and_streaming_pipeline.md` — Innertube, parsers, continuations, stream resolve.
- `03_playback_engine_and_queue.md` — audio_handler, PlayerController, radio, sleep, EQ, session.
- `04_data_persistence_and_models.md` — models, boxes, CRUD, housekeeping.
- `05_ui_navigation_state_theming.md` — navigator, screens, widgets, GetX patterns, theme, i18n.
- `06_offline_downloads_cache_lyrics.md` — downloader, cache, lyrics, import/export/backup/share/links.
- `07_platform_integrations_and_build.md` — Android/iOS/Linux/Win/macOS/web, jni, deps, tray/SMTC, CI/packaging.
- `08_clone_spec.md` — buildable clone spec: modules, API contracts, DB schemas, state machines, checklists.
