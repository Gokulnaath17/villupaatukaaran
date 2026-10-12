# 02 — Content Fetch (Innertube) + Stream Resolution Pipeline

Files: `lib/services/constant.dart`, `music_service.dart`, `nav_parser.dart`, `continuations.dart`, `utils.dart`, `stream_service.dart`, `background_task.dart`, `piped_service.dart`, `models/hm_streaming_data.dart`.

## 2.1 Transport constants (`constant.dart`)

```
domain=https://music.youtube.com/
baseUrl=${domain}youtubei/v1/
fixedParms=?prettyPrint=false&alt=json&key=AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30
userAgent=Mozilla/5.0 (Windows NT 10.0...) Chrome/114...
```

## 2.2 `MusicServices extends GetxService` (`music_service.dart:951 lines`)

State: `_headers{user-agent,accept,accept-encoding,content-type,content-encoding,origin:domain,cookie}`, `_context{context:{client:{clientName:WEB_REMIX,clientVersion}},user:{}}`, `dio:Dio`.

- `onInit→init()`: `clientVersion=1.YYYYMMDD.01.00`, `playbackContext.signatureTimestamp=getDatestamp()-1`, `hlCode=AppPrefs.contentLanguage??en`, visitorId: reuse `AppPrefs.visitorId{id,exp}` if `!isExpired` else `genrateVisitorId()` else hardcoded fallback. `genrateVisitorId()`: `GET domain` + regex `ytcfg.set(({.+?}))` → `VISITOR_DATA`.
- `_sendRequest(action,data,{additionalParams})`: `dio.post($baseUrl$action$fixedParms$additionalParams)`; recurse on non-200; throw `NetworkError` on `DioException`.
- `getHome({limit=4})`: `browse{FEmusic_home}` → `nav(single_column_tab+section_list)` → `parseMixedContent` + `getContinuations(sectionListContinuation)`.
- `getWatchPlaylist({videoId,playlistId,limit=25,radio,shuffle,additionalParamsNext,onlyRelated})` [CORE]: strip `MPED`; `enablePersistentPlaylistPanel=true,isAudioOnly=true,tunerSettingValue=AUTOMIX_SETTING_NORMAL`; default `playlistId=RDAMVM<videoId>`; if `!(radio||shuffle)` add `watchEndpointMusicSupportedConfigs`; `validatePlaylistId` strip `VL`; `isPlaylist=PL|OLA`; `shuffle→params wAEB8gECKAE%3D, radio→wAEB`; `POST next`; `watchNextRenderer=singleColumnMusicWatchNextResultsRenderer.tabbedRenderer.watchNextTabbedResultsRenderer`; `lyricsBrowseId=getTabBrowseId(1)`, `related=getTabBrowseId(2)`; if `onlyRelated` return `{lyrics,related}`; `results=tab_content.musicQueueRenderer.content.playlistPanelRenderer`; `playlist=first navigation_playlist_id`; `tracks=parseWatchPlaylist(contents)` + `getContinuations(playlistPanelContinuation, limit-len, ctokenPath:isPlaylist?'':'Radio', isAdditionparamReturnReq:true)`; return `{tracks,playlistId,lyrics,related,additionalParamsForNext}`.
- `getPlaylistOrAlbumSongs({playlistId,albumId,limit=3000})`: `VL<id>` or `OLAK5uy→getAlbumBrowseId` (scrape `MPRE.+?` from `GET domain/playlist?list=`); `browse` → playlist branch (`musicDetailHeader/musicResponsiveHeader` + `musicPlaylistShelfRenderer` → `parsePlaylistItems` + `getContinuationsPlaylist`) vs album (`parseAlbumHeader` + `musicShelfRenderer` → `parsePlaylistItems(isAlbum:true)` + `other_versions`).
- `search(query,{filter,scope,limit=30,ignoreSpelling,filterParams})`: `getSearchParams(filter,scope)` → `POST search` → chips + `sectionList.contents` → `musicShelfRenderer` → `parseSearchResults([artist,playlist,song,video,station])` + continuations. `getSearchSuggestion`: `music/get_search_suggestions`.
- `getSongWithId(songId)`: `POST player{videoId}` → if `microformat.category==Music` or `musicVideoType` → `getWatchPlaylist` → `[true,tracks]` else `[false,null]`.
- `getArtist(channelId)` (strip `MPLA`), `getArtistRealtedContent(endpoint,category)` (Songs/Videos vs Albums/Singles), `getCharts/getChartItems` (cap24, `getPlaylistOrAlbumSongs`), `getContentRelatedToSong`, `getLyrics(browseId)`, `getSongYear` (`MPTC` browse → `secondTitle.runs[2]`), `getAlbumBrowseId`.
- `enum AudioQuality{Low,High}` mirrored in settings.

## 2.3 Parsers (`nav_parser.dart:1079 lines`, pure functions)

Consts: `single_column, tab_content, single_column_tab, section_list, run_text, mtrir=musicTwoRowItemRenderer, mrlir=musicResponsiveListItemRenderer, navigation_browse/video/playlist_id, thumbnail_renderer, menu_items, play_button, musicPlaylistShelfRenderer`, etc. `nav(root,items,{noneIfAbsent})` safe-traverse.
- `parseMixedContent`: carousel/shelf → pageType ALBUM/ARTIST/PLAYLIST → `parseAlbum/RelatedArtist/Playlist` else `parseSong/Flat`.
- `parseSong/Flat/Runs`: subtitle runs parity (even content/odd `•`), endpoint→artist/album (`MPRE/release_detail`=album), regex length/year else artist.
- `parseWatchPlaylist/Track`: `playlistPanelVideoWrapperRenderer.primaryRenderer.playlistPanelVideoRenderer(+counterpart)` → `videoId,title,length,thumbs,videoType,longByline` → `MediaItemBuilder.fromJson`.
- `parsePlaylistItems(...,{isAlbum})`: `mrlir` → videoId resolution (playlistItemData/album `MPTC`/removedVideoId/playNavigationEndpoint), flexColumns title/artists/album, fixedColumns duration, `trackDetails` if album, skip deleted/greyed.
- `parseAlbumHeader, parseArtistContents(Songs/Videos/Albums/Singles), parseSearchResult(s)/TopResult/getSearchResultType, parseVideo/Single/Album/Playlist/Charts*`, `getTabBrowseId, getFlexColumnItem, parseMenuPlaylists`.

## 2.4 Continuations (`continuations.dart:190 lines`)

- `getContinuationToken`, `getContinuations(results,type,limit,reqFn,parseFn,{ctokenPath,reloadable,additionalParams_,isAdditionparamReturnReq})`: loop `results.continuations[0].next[ctokenPath]ContinuationData.continuation` → `&ctoken&continuation` → `continuationContents[type].contents/items`.
- `getContinuationsPlaylist`: token `continuationItemRenderer.continuationEndpoint.continuationCommand.token` → `onResponseReceivedActions[0].appendContinuationItemsAction.continuationItems`.
- `getValidatedContinuations/resendRequestUntilParsedResponseIsValid/validateResponse/getContinuationParams/getReloadableContinuationParams/getContinuationString/getContinuationContents`.

## 2.5 Utils (`services/utils.dart:216 lines`)

`getDatestamp()` days-since-epoch; `parseDuration("H:M:S")`; `validatePlaylistId` strip `VL`; `sumTotalDuration`; `getItemText/getFixedColumnItem`; `isExpired({url,epoch})` via `.expire=([0-9]+)` → `now+1800<epoch?valid:expired` (drives `SongsUrlCache`+visitorId); `parseMenuPlaylists` (shuffle/radio ids); `findObjectByKey/findObjectsByKey`; `getSearchParams(filter,scope)` base64 (`EgWKAQI` etc.); `getDotSeparatorIndex`.

## 2.6 Stream resolution (`stream_service.dart:131 lines` + `background_task.dart:37` + `hm_streaming_data.dart`)

- `StreamProvider.fetch(videoId)`: `YoutubeExplode().videos.streamsClient.getManifest` → `audioOnly→Audio{itag,codec mp4a/opus,bitrate,duration,loudnessDb,url,size}`; catch `Socket→networkError, VideoUnplayable→reason, RequiresPurchase/Unavailable/Explode→message, else Unknown`.
- Getters: `highestQuality(251||140)`, `highestBitrateMp4a(140||139)`, `highestBitrateOpus(251||250)`, `lowQuality(249||139)`, `hmStreamingData{playable,statusMSG,low,high}`.
- `Audio{itag,Codec,bitrate,duration,size,loudnessDb,url,toJson/fromJson}`, `enum Codec{mp4a,opus}`; `HMStreamingData{playable,statusMSG,low/high,qualityIndex=1,audio=>idx0?low:high}`.
- `getStreamInfo(songId,token)`: strip `MPED`, `BackgroundIsolateBinaryMessenger.ensureInitialized(token)`, return `hmStreamingData`. Invoked via `Isolate.run(()=>getStreamInfo(id,RootIsolateToken.instance))` from `checkNGetUrl` (avoids UI jank). Piped audio fallback removed/commented.

## 2.7 `checkNGetUrl` 3-tier (in `audio_handler.dart`, called by play paths)

1. `SongsCache.contains(id)` → `file://...cachedSongs/id.mp3` pseudo-data.
2. `SongDownloads.contains(id)` + path valid (`support/Music` direct else permission+exists) → playable; else recurse `offlineReplacementUrl:true`.
3. `SongsUrlCache` reuse if `!generateNewUrl && !isExpired(low.url)` else isolate fetch + `put`; `setQualityIndex(AppPrefs.streamingQuality??1)`; return.

## 2.8 Piped (`piped_service.dart:183 lines`, playlists only, NOT audio)

`PipedServices extends GetxService`, `AppPrefs.piped{isLoggedIn,token,instApiUrl}`, `Authorization` header. `login(url,user,pass)→POST /login→Res(1)/Res(0,err)`, `logout`, `_sendRequest`, `getAllInstanceList(GET https://piped-instances.kavin.rocks/)`, `create/rename/delete/addTo/remove/getAllPlaylists(/user/playlists*)`, `getPlaylistSongs(id): GET /playlists/id → relatedStreams→MediaItem(id=url.split("?v=")[1],title,uploader,duration,thumb,extras:{artists})`. `Res{code,errorMessage,response}`, `PipedInstance{name,apiUrl}`.

## 2.9 Clone checklist

- Replicate `WEB_REMIX` context + visitorId caching + signatureTimestamp or YTM returns 403.
- Port `nav()` + all `parse*` with fixture tests (home/search/watch/album/artist responses change shape; guard `noneIfAbsent`).
- Implement continuation loops with `limit` guards to avoid infinite paging.
- Isolate stream fetch; never call `YoutubeExplode` on UI thread during scroll.
- Cache `SongsUrlCache` with `expire=` check; regenerate with `generateNewUrl:true` on playback error.
