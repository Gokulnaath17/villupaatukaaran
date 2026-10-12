# 08 — Clone Build Spec (Buildable Contract)

This is the executable checklist to recreate Harmony Music. Implement in order; each item lists inputs → outputs → verification.

## 8.1 Module manifest (create these)

```
lib/main.dart (initHive, prefs seed, lazy regs, AudioService.init, LifecycleHandler, GetMaterialApp)
lib/services/{constant,music_service,nav_parser,continuations,utils,stream_service,background_task,audio_handler,downloader,piped_service,equalizer,permission_service,synced_lyrics_service,windows_audio_service}
lib/models/{playlist,album,artist,media_Item_builder,thumbnail,hm_streaming_data,quick_picks,playling_from,durationstate}
lib/utils/{app_link_controller,get_localization,helper,house_keeping,lang_mapping,system_tray,update_check_flag_file}
lib/native_bindings/andrid_utils (or platform channel equiv)
lib/ui/{home,navigator,utils/theme_controller,player/*,screens/*,widgets/*}
lib/base_class/playlist_album_screen_con_base + lib/mixins/additional_opeartion_mixin
platform shells: android(Manifest,MainActivity AudioService,Equalizer,SDKInt,gradle,res), ios(Info BG audio), linux(CMake+packaging), windows(CMake+titlebar channel+inno), macos(entitlements), web(stub)
```

## 8.2 API contracts (must match)

- Innertube: `POST {domain}youtubei/v1/{browse,next,search,player}/...?prettyPrint=false&alt=json&key=AIzaSyC9XL...` body `{context:{client:{clientName:WEB_REMIX,clientVersion:1.YYYYMMDD.01.00,hl:<lang>},user:{}},...}` headers `{user-agent,origin,cookie CONSENT=YES+1,X-Goog-Visitor-Id}`. Endpoints→return shapes: `getHome→{quickPicks,middle,fixed}`, `getWatchPlaylist→{tracks:MediaItem[],playlistId,lyrics,related,additionalParamsForNext}`, `search→{chips,results,continuation}`, `getLyrics→{synced,plain}`, `player→Music-check`.
- Streams: `getManifest(videoId)→audioOnly[{itag,codec,bitrate,duration,loudnessDb,url,size}]` → `hmStreamingData{playable,statusMSG,low:{249|139},high:{251|140}}`; expiry `.expire=` +30min grace.
- LRCLIB: `GET https://lrclib.net/api/get?artist_name&track_name&album_name&duration → {syncedLyrics,plainLyrics}`.
- Piped: `POST {inst}/login → {token}`; `GET/POST {inst}/user/playlists* (Auth)`, `GET {inst}/playlists/{id} → {relatedStreams[]}`; instances `GET https://piped-instances.kavin.rocks/`.

## 8.3 DB schemas (Hive JSON, no adapters)

- Eager: `AppPrefs{<30 keys §04>}, SongsCache{id:songJson+streamInfo+duration}, SongDownloads{id:songJson+streamInfo[file url]+url:filePath}, SongsUrlCache{id:hmStreamingData}`.
- Lazy: `LibraryPlaylists{id:PlaylistJson}, Box(playlistId){int:songJson}, LibraryAlbums{id:AlbumJson}+Box(albumId), LibraryArtists{id:ArtistJson}, LIBFAV{id:songJson}, LIBRP{int:songJson cap30}, searchQuery{int:str cap10}, homeScreenData{quickPicksType,quickPicks[],middle[],fixed[]}+homeScreenDataTime, prevSessionData{queue[],position,index}, blacklistedPlaylist{int:pipedId}, lyrics{id:{synced,plainLyrics}}`.
- Song JSON: `{videoId,title,album,artists,length,duration:sec,date,thumbnails:[{url}],url,trackDetails,year,streamInfo?:[bool,AudioJson]}`.

## 8.4 State machines

- `playByIndex`: loading→clear→mediaItem→await URL→stale-guard→error404|add source→normalize→play|restore-seek. `checkNGetUrl`: SongsCache→Downloads→UrlCache→isolate.
- Queue: `updateQueue→shuffleCmd?→playByIndex(0)|setSourceNPlay`; radio: `push(radio)→continuation→last-track→enqueue 24 deduped`; prev/next/shuffle/loop/queueLoop guards (§03).
- Session: save on `detached/onTaskRemoved/Quit/close` iff `restorePlaybackSession`; restore `addQueueItems+playByIndex(restore+position)`.
- Home: Db→render→stale>8h silent refresh→persist. Search: suggest→search→paginate@50%→sort. Library: refresh→sort/search/batch→updateDb.

## 8.5 Player stack (exact libs or equiv)

`just_audio(AudioPlayer,ConcatenatingAudioSource(useLazyPreparation:false),LockCachingAudioSource,AndroidLoadControl 50/120/0.05/2,skipSilence,sessionId)` + `audio_service(BaseAudioHandler,MediaItem/queue/mediaItem/playbackState/controls[prev,play,next]+compact+seek,customAction/customEvent,getChildren/subscribe/playFromMediaId)` + `just_audio_media_kit(title,whitelist http/https/file)` desktop + `smtc_windows/mpris/tray/wakelock` platform.

## 8.6 UI acceptance

Nested Navigator id=1 with 6 routes; Home SlidingUpPanel+MiniPlayer+Bottom(4)/Side(6) tabs; Home feed + Search + CombinedLibrary(4 tabs) + Settings(6 tiles) + Player(Standard/Gesture/Mini/Queue) + Album/Playlist/Artist detail (tagged controllers); `Obx` reactivity; dynamic theme (Palette 200px→darken 0.10→MaterialColor swatch→AnimatedTheme 700ms); `Translations` ~150 keys × ~51 langs; shimmer/empty/error states; slidable rows; marquee; sleep/lyrics/queue sheets.

## 8.7 Platform acceptance

Android notification controls + Auto browse tree (`songs/favorites/albums/playlists/recent`) + links (`VIEW/BROWSABLE+SEND`) + perms + EQ; desktop tray hide-vs-quit + SMTC/MPRIS + titlebar color + 1280×720; iOS BG audio + arbitrary loads; backup `*.hmb` round-trip; CSV/JSON export; GH Actions analyze+apk + Win signed EXE; F-Droid metadata.

## 8.8 Test plan (per stage)

1. Fixtures: sample `browse/next/search/player` JSON → assert `parse*` outputs MediaItem/Album/Artist/Playlist counts.
2. Continuation: mock 2-page `sectionList/musicShelf/playlistPanel` → assert merged length + token stop.
3. Stream: mock manifest → assert low/high pick + `isExpired` true/false + tier priority with fake boxes.
4. Handler: fake queue → assert next/prev/shuffle/loop/queueLoop indices + error-recovery calls `playByIndex(newUrl)`.
5. Persistence: write/read every box → assert JSON round-trip + caps (RP30/search10) + housekeeping deletes.
6. UI: pump Home/Search/Library/Player/Settings → assert tab switches, sort/search, theme change, locale change.
7. E2E: cold start (empty Hive) → home feed → search → play → pause/next → background → kill → restore session → download → backup/restore.

## 8.9 Risks / gotchas

- Innertube shapes drift → keep `nav(noneIfAbsent)` + log `funName`; pin `clientVersion` date logic.
- `youtube_explode` breaks on YouTube throttling → keep `generateNewUrl` retry + visitorId refresh.
- Lowercase `appPrefs` bug creates split prefs — migrate on clone.
- Typos are API: `PlaylingFrom, restrorePlaybackSession, stopPlyabackOnSwipeAway, upadateMediaItemInAudioService, andrid_utils` — keep or map.
- Desktop volume/wakelock defaults differ; skip-silence/EQ/loudness Android-only.
- `audio_service_mpris` has no Dart import — verify Linux plugin registration.
