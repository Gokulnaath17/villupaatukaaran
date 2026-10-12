# 04 — Data Models, Hive Boxes, Library CRUD, Housekeeping

Files: `lib/models/*`, `lib/main.dart:initHive`, `lib/ui/screens/Library/library_controller.dart`, `lib/ui/screens/Playlist|Album|Artists/*_controller.dart`, `lib/base_class/playlist_album_screen_con_base.dart`, `lib/mixins/additional_opeartion_mixin.dart`, `lib/utils/house_keeping.dart`, `lib/ui/player/player_controller.dart` (fav/RP), `lib/services/audio_handler.dart`, `lib/services/downloader.dart`.

## 4.1 Models (no Hive adapters — all JSON maps)

- `Playlist{playlistId,title,thumbnailUrl,description?,songCount?,isPipedPlaylist=false,isCloudPlaylist=true}`: `fromJson(title,playlistId|browseId,thumbnails[0]→Thumbnail.extraHigh else placeholder,description,itemCount,flags)`; `toJson{title,playlistId,description,thumbnails:[{url}],itemCount,flags}`; `copyWith`; `toMediaItem(id=playlistId,playable:false)` for Auto. `PlaylistContent{title,playlistList}`.
- `Album{browseId,audioPlaylistId?,title,description?,artists:List<Map>?,year?,thumbnailUrl}`: `fromJson(title,browseId,artists,year,audioPlaylistId,description,thumbnails[0]→medium)`; `toMediaItem`. `AlbumContent{title,albumList}`.
- `Artist{name,browseId,radioId?,subscribers?,thumbnailUrl}`: `fromJson{subscribers String|{text}|""}`; `ArtistContent`.
- `MediaItemBuilder` (canonical): `fromJson(json,{url?})→MediaItem(id=videoId,title,duration=Duration|toDuration(length),album,artist=join,artUri=Thumbnail.high,extras{url:length,album,artists,date,trackDetails,year})` + downloader adds `streamInfo=[bool,AudioJson{url:filePath}]`, cache adds `duration+streamInfo`; `toJson(MediaItem)→{videoId,title,album,artists,length,duration:sec,date,thumbnails:[{url}],url,trackDetails,year}+streamInfo?`; `toDuration("M:SS"/"H:M:S")`.
- `Thumbnail(url)`: `sizewith(size)`: `-rj→w/h/size-l90-rj`, `=s→=s{size}`, `>=600→sddefault→maxresdefault`; `high400/medium250/low150/extraHigh desktop1000:600`.
- `HMStreamingData{playable,statusMSG,low/high,qualityIndex=1,audio}`; `QuickPicks(songList,title=Discover)`; `PlaylingFrom{ALBUM,PLAYLIST,SELECTION,ARTIST}+typeString/nameString`; `ProgressBarState{current,buffered,total}`; `Audio/Codec` in stream_service.

## 4.2 Box inventory

Eager (`main:initHive`): `SongsCache|SongDownloads|SongsUrlCache|AppPrefs` (never closed).
Lazy (open→op→close): `LibraryPlaylists, Box(playlistId)` (`LIB<ms>` local, `VL*/PL*/OLA*` remote mirror), `LibraryAlbums+Box(albumId)`, `LibraryArtists`, `LIBFAV`, `LIBRP`, `searchQuery`, `homeScreenData`, `prevSessionData`, `blacklistedPlaylist`, `lyrics` (per-request open/close).

| Box | Key→Value | Writer/Reader |
|---|---|---|
| `AppPrefs` | ~30 keys: themeModeType,themePrimaryColor,currentAppLanguageCode,contentLanguage,visitorId{id,exp},cacheSongs,skipSilenceEnabled,streamingQuality(0/1),discoverContentType(QP/TR/TMV/BOLI),noOfHomeScreenContent,isTransitionAnimationDisabled,isBottomNavBarEnabled,slidableActionEnabled,playerUi(0/1),autoOpenPlayer,restrorePlaybackSession[typo],cacheHomeScreenData,homeScreenDataTime,recentSongId,newVersionVisibility,loudnessNormalizationEnabled,isLoop/Shuffle/queueLoopModeEnabled,lyricsMode(0sync/1plain),volume,backgroundPlayEnabled,keepScreenAwake,downloadLocationPath,exportLocationPath,downloadingFormat(m4a/opus),piped{isLoggedIn,token,instApiUrl},stopPlyabackOnSwipeAway[typo],autoDownloadFavoriteSongEnabled | settings/player/home/music/piped/audio_handler |
| `SongsCache` | `videoId→songJson+{streamInfo,duration}` | write `checkWithCacheDb` (LockCaching+file exists); read `checkNGetUrl` tier1; GC library init + housekeeping |
| `SongDownloads` | `videoId→songJson+{streamInfo=[true,Audio{url:filePath}],url:filePath}` | write `downloader.writeFileStream`; read tier2 with `File.exists` verify |
| `SongsUrlCache` | `videoId→{playable,statusMSG,low,high}` | write `checkNGetUrl` isolate; read reuse if `!isExpired`; GC housekeeping |
| `LibraryPlaylists` | `playlistId→Playlist.toJson`; builtins `initPlst=[LIBRP,LIBFAV,SongsCache,SongDownloads]` virtual | `LibraryPlaylistsController` create/rename/sync/blacklist/reset/import |
| `Box(playlistId)` | `int idx→songJson` (`add`) | `playlist_screen_controller.updateSongsIntoDb(clear+put)`, `deleteMultipleSongs`, `add_to_playlist(add if absent)`; `LIBRP reversed` |
| `LibraryAlbums/Box(albumId)` | `browseId→Album.toJson / int→songJson` | `album_screen_controller` |
| `LibraryArtists` | `browseId→Artist.toJson` (no per-artist songs) | `artist_screen_controller` |
| `LIBFAV` | `videoId→songJson` | `player._checkFav/toggleFavourite`, `songinfo_sheet.toggleFav`, Auto `getLibSongs(LIBFAV)` |
| `LIBRP` | `int→songJson`, cap30 FIFO `deleteAt(0)`, dedup, display reversed | `player._addToRP` on every mediaItem |
| `searchQuery` | `int→String`, cap10 FIFO dedup | `search_screen_controller` |
| `homeScreenData` | `{quickPicksType,quickPicks:[json],middleContent:[Album|PlaylistContent],fixedContent:[...]}` + `AppPrefs.homeScreenDataTime` (8h) | `home_screen_controller` |
| `prevSessionData` | `{queue:[json],position:ms,index}` | `saveSessionData` ↔ `_restorePrevSession` |
| `blacklistedPlaylist` | `int→pipedId` | piped sync filter |
| `lyrics` | `videoId→{synced,plainLyrics}` | `synced_lyrics_service` |

## 4.3 CRUD flows

- Songs library: `LibrarySongsController.init→SongsCache+SongDownloads→librarySongsList`; `removeSong(item,isDownloaded)` delete `tmp/cachedSongs/id.mp3` or `extras.url` + `support/thumbnails/id.png`; `deleteMultipleSongs` route by membership.
- Playlist/album/artist bookmark: `openBox(Library*)→put/delete→refreshLib→close`; songs: `openBox(id)→clear/put/add/deleteAt→close` (except SongsCache/Downloads kept open).
- Base: `PlaylistAlbumScreenControllerBase(songList,isContentFetched/AddedToLibrary/Downloaded,scrollOffset,fetchAlbum/PlaylistDetails,fetchSongsfromDatabase(LIBRP reversed),checkDownloadStatus,addNremoveFromLibrary,sync,updateDb,deleteMultiple,selectedSongs,search,additional ops)`.
- Mixin `AdditionalOpeartionMixin`: `arrange→updateDb, delete→deleteMultipleSongs, addToPlaylist→dialog`, `additionalOperationTempList/Map+isSearchingOn`.
- Piped sync: `LibraryPlaylistsController.syncPipedPlaylist` (if `PipedServices.isLoggedIn`, minus `blacklistedPlaylist`) + `PipedSyncWidget/link_piped` dialogs.

## 4.4 Housekeeping (`house_keeping.dart`)

`startHouseKeeping→removeExpiredSongsUrlFromDb` (iterate `SongsUrlCache`, delete if null/String or `isExpired`) `→finally removeDeletedOfflineSongsFromDb` (each `SongDownloads`, if `File(url)` missing → delete entry + `LibrarySongsController.removeSong(true)` + thumb). Called from `LibrarySongsController.init`.

## 4.5 Clone schemas (copy verbatim)

Persist song JSON exactly as `MediaItemBuilder.toJson` + optional `streamInfo`; playlist/album/artist JSON as `toJson`; session/home/lyrics shapes above. Enforce caps (LIBRP30, search10), FIFO deletes, reversed display for RP. Replicate lowercase-`appPrefs` bug or fix + migrate.
