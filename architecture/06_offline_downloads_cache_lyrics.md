# 06 — Offline: Downloader, Cache, Lyrics, Import/Export/Backup/Share/Links

Files: `lib/services/downloader.dart`, `lib/services/synced_lyrics_service.dart`, `lib/services/permission_service.dart`, `lib/utils/house_keeping.dart`, `lib/utils/helper.dart`, `lib/ui/widgets/{backup_dialog,restore_dialog,export_file_dialog,playlist_export_dialog,songinfo_bottom_sheet,sleep_timer_bottom_sheet,lyrics_dialog}`, `lib/ui/screens/Playlist/playlist_screen_controller.dart`, `lib/ui/screens/Library/library_controller.dart`, `lib/utils/app_link_controller.dart`, `lib/ui/screens/Search/search_screen_controller.dart`, `lib/ui/player/components/lyrics_widget.dart`.

## 6.1 Downloader (`downloader.dart:287`, `Downloader extends GetxService`)

State: `_dio, currentSong, playlistQueue:RxMap<String,List<MediaItem>>, currentPlaylistId.obs, songDownloadingProgress/playlistDownloadingProgress obs, isJobRunning=false.obs, songQueue:RxList`.

- `checkPermissionNDir()`: if `!isCurrentPathsupportDownDir(==support/Music)` require `PermissionService.getExtStoragePermission()` (desktop true; SDK<30 storage/accessMediaLocation/mediaLibrary else manageExternalStorage; openAppSettings if permanently denied; SDK via `native_bindings/andrid_utils SDKInt`); `mkdir downloadLocationPath`.
- `download(song,{songList})/downloadPlaylist(id,list)` (toggle-cancel if `playlistQueue.contains`): enqueue → `triggerDownloadingJob()` if idle.
- `triggerDownloadingJob()`: playlists first (`downloadSongList(isPlaylist:true)` + set `Playlist/AlbumScreenController(tag).isDownloaded` if `isRegistered`), else `downloadSongList(songQueue)`, recurse if `songQueue` remains.
- `downloadSongList(list)`: skip if `SongDownloads.contains`, else `writeFileStream`, remove queue, update playlist counter; abort if playlist cancelled.
- `writeFileStream(song)`: `StreamProvider.fetch(id)` (else snackbar `networkError/statusMSG`); `requiredAudio=downloadingFormat==opus?highestBitrateOpus:highestBitrateMp4a` (default m4a); sanitize `Title (Artist)` strip `Container./\"<>*?:![]¡|%`; `filePath=$dir/name.$ext(m4a/opus by codec)`; `dio.download(url,Range:bytes=0-total,onReceiveProgress→songDownloadingProgress)`; year (`extras.year` or `getSongYear`), thumb→`support/thumbnails/id.png`, `extras[url]=filePath`, `songJson=toJson+streamInfo=[true,{...requiredAudio,url:filePath}]`, `SongDownloads.put`, `LibrarySongs+=song`, `AudioTags.write(Tag{title,artist,album,year,trackNumber/Total,genre,picture:NetworkAssetBundle(artUri)})`.

## 6.2 Cache (`audio_handler` + `house_keeping` + settings)

- Enable: `Settings.cacheSongs.toggleCachingSongsValue` → `AppPrefs.cacheSongs`; `_createAudioSource`: LockCaching iff `url.contains(/cache)` or (`cacheSongs&&http`).
- Promote: `checkWithCacheDb` when buffered≥98% (PlayerController flag) + file exists + not in `SongsCache` → `put(id, toJson+duration+streamInfo=[true,dbStream[low/high by quality]])` + `LibrarySongs+=song`.
- Reuse: `checkNGetUrl` tier1 `SongsCache(file://)` > tier2 downloads > tier3 URL cache.
- GC: `removeExpiredSongsUrlFromDb` (`isExpired`), `removeDeletedOfflineSongsFromDb` (missing `File(url)` → delete box+library+thumb); called `LibrarySongsController.init`.
- Quality: `streamingQuality High/Low` → `setQualityIndex` + `checkWithCacheDb` pick; persisted index.
- Skip-silence `just_audio`, loudness `_normalizeVolume`, EQ `jni` (see 03).

## 6.3 Lyrics

- Fetch `SyncedLyricsService.getSyncedLyrics(song,dur)`: open `lyrics` box → hit?return; else `GET https://lrclib.net/api/get?artist_name+track_name+album_name+duration` → if `syncedLyrics!=null` cache `{synced,plainLyrics}`; `finally close`. Fallback `PlayerController.showLyrics`: `getWatchPlaylist(onlyRelated)→lyricsBrowseId→getLyrics→{synced:"",plainLyrics}` else `"NA"`.
- Render (`lyrics_widget.dart`, `flutter_lyric`): `mode1→SelectableText(plain)` else `LyricsReader(model:LyricsModelBuilder.bindLyricToMain(synced),position:progressBar.current,lyricUi:UINetease)`; `lyrics_switch.dart` ToggleSwitch persisted `AppPrefs.lyricsMode`; `lyrics_dialog/albumart_lyrics/standard/mini_player` hosts.

## 6.4 Playlist import/export + raw export

- Export dialog (`playlist_export_dialog.dart` + `playlist_screen_controller.exportPlaylistToJson/Csv`): JSON `{playlistInfo:Playlist.toJson,songs:[json],exportDate,appVersion}` / CSV `PlaylistBrowseId,PlaylistName,MediaId,Title,Artists,Duration,ThumbnailUrl,AlbumId,AlbumTitle,ArtistIds` → `~/Downloads/HarmonyMusic` (Android `/storage/emulated/0/Download`, iOS docs, fallback docs/temp); YTM direct: `watch_videos?video_ids=` (50-limit) → `Dio+html canonical→music.youtube.com` (`url_launcher external`, `Clipboard` copy).
- Import (`library_controller.importPlaylistFromJson`): `FilePicker.pickFiles(json)` → validate `{playlistInfo,songs}` → new `LIB<ms> "(imported)"` → `LibraryPlaylists.put` + `Box(newId).put(i,song)`.
- Raw (`export_file_dialog.dart`): copy `support/Music/*` → `AppPrefs.exportLocationPath` (`setExportedLocation/setDownloadLocation` via `FilePicker.getDirectoryPath`).

## 6.5 Backup/restore (`backup_dialog.dart` / `restore_dialog.dart`, `archive`, `file_picker`, `terminate_restart`)

- Backup: `FilePicker.getDirectoryPath` → `Isolate.run(list *.hive in dbDir)` + optional `SongDownloads[].url` + `thumbnails/*.png` → `compute(_compressFiles Archive/ZipEncoder)` → `*.hmb` (zip).
- Restore: `FilePicker.pickFiles(hmb/any)` → `closeAllDatabases(Hive.close)` → delete `*.hive` → `ZipDecoder` → route `.m4a/.opus→support/Music`, `.png→support/thumbnails`, else `dbDir`; desktop rewrite `SongDownloads[url,streamInfo.url]`; restart via `terminate_restart`/`exit(0)`; clear file_picker cache.

## 6.6 Share + deep/share-import links (`share_plus`, `url_launcher`, `app_links`)

- Share: `songinfo_bottom_sheet:304 Share.share(youtube.com/watch?v=id)`, `playlist_screen:507,522` (song + playlist), `album_screen:372`, `artist_screen:267`; `url_launcher` OpenIn YT/YTM.
- `AppLinksController+ProcessLink(app_link_controller.dart:126)` (mobile, in `MyApp.build`; `SearchScreenController with ProcessLink` for pasted URLs): `getInitialAppLink` cold + `uriLinkStream` warm → `filterLinks(Uri)` (close panel, pop SongInfo, route `youtube.com|music.youtube.com|youtu.be`: `playlist?list=→openPlaylistOrAlbum(OLAK5uy?album:playlist via ScreenNavigationSetup)`, `shorts→snack notaSongVideo`, `watch?v=→playSong`, `channel/id→openArtist`, bare `youtu.be/id→playSong`, else `notaValidLink`); `playSong`: loading dialog → `getSongWithId→playPlayListSong(SELECTION)` or snack.
- Manifest: `VIEW+BROWSABLE+DEFAULT` for 5 hosts + `SEND text/plain` (YouTube share-import); `helper.getCurrentRouteName()` via `Get.nestedKey(1)`.
