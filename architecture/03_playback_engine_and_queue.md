# 03 — Playback Engine, Queue, Radio, Sleep, EQ, Session

Files: `lib/services/audio_handler.dart` (973), `lib/ui/player/player_controller.dart` (837), `lib/services/equalizer.dart`, `lib/services/windows_audio_service.dart`, `lib/ui/widgets/sleep_timer_bottom_sheet.dart`, `lib/models/durationstate.dart`, `lib/models/playling_from.dart`.

## 3.1 `MyAudioHandler extends BaseAudioHandler with GetxServiceMixin`

Fields: `_cacheDir, _player:AudioPlayer, _mediaLibrary:MediaLibrary, currentIndex, currentShuffleIndex=0, currentSongUrl?, isPlayingUsingLockCachingSource, loopModeEnabled, queueLoopModeEnabled, shuffleModeEnabled, loudnessNormalizationEnabled, isSongLoading=true, shuffledQueue:List<String>, _playList=ConcatenatingAudioSource([],useLazyPreparation:false)`.

Ctor:
- Win/Lin: `JustAudioMediaKit.title='Harmony music', protocolWhitelist=[http,https,file]`.
- `_player=AudioPlayer(audioLoadConfiguration: AudioLoadConfiguration(androidLoadControl(min50s,max120s,forPlayback50ms,afterRebuffer2s)))`.
- `_createCacheDir()` → `getTemporaryDirectory/cachedSongs/`; `_addEmptyList()` → `setAudioSource(_playList)`.
- Listeners: `_notifyAudioHandlerAboutPlaybackEvents`, `_listenToPlaybackForNextSong`, `_listenForSequenceStateChanges` (guard), `_listenForDurationChanges`, Android `_listenSessionIdStream→EqualizerService.initAudioEffect(id)`.
- Restore prefs (note lowercase `appPrefs` box bug): `skipSilence, isLoop/Shuffle/queueLoop/loudness`.

Key internals:
- `_notify...`: `playbackEventStream→playbackState(copyWith(controls:[prev,play/pause,next], systemActions:{seek}, processingState:isSongLoading?loading:map(idle/loading/buffering/ready/completed), repeatMode, shuffleMode, playing, position, buffered, speed, queueIndex:currentIndex))`. `onError`: save pos, stop; if LockCaching+`Connection closed`→seek+play else `playByIndex(newUrl:true)+seek(pos)`.
- `_listenToPlaybackForNextSong`: `positionStream` vs `duration-offset(Win200/Lin700/else0)` → `_triggerNext` (loopSingle→seek0+play else `skipToNext`).
- `_listenForDurationChanges`: patch `mediaItem.duration` if null or index0.
- Queue mutators `addQueueItems/updateQueue/addQueueItem/removeQueueItem` maintain `shuffledQueue` when shuffle on.
- `_createAudioSource(m)`: `url=extras[url]`; if `url.contains(/cache)` or (`Settings.cacheSongs && http`) → `LockCachingAudioSource(Uri, cacheFile:cachedSongs/<id>.mp3)` else `AudioSource.uri`.
- `play()`: if `currentSongUrl==null` or desktop null-duration → `playByIndex(currentIndex)` else `_player.play()`. `pause/seek/skipToQueueItem→playByIndex`.
- `_getNextSongIndex`: shuffle→`shuffledQueue[currentShuffleIndex+1]` (reshuffle at end) → `queue.indexWhere`; linear→`+1` or `0` if queueLoop else same. `_getPrevSongIndex` mirrored. `skipToNext`: if different→seek0+playByIndex else seek0+pause. `skipToPrevious`: `position>5s→seek0` else seek0+playByIndex(prev).
- `setRepeatMode(none/one)→loopModeEnabled`, `setShuffleMode(none/all)→shuffleMode+_shuffleCmd/clear`.

`customAction(name,extras)` switch:
- `dispose→_player.dispose+stop`; `playByIndex{index,newUrl,restoreSession,position}` (see 3.2); `checkWithCacheDb{mediaItem}` promote temp→`SongsCache`; `setSourceNPlay{mediaItem}` single-song; `toggleSkipSilence/toggleLoudnessNormalization/shuffleQueue/reorderQueue/addPlayNextItem/openEqualizer/saveSession/setVolume(0-100→0-1)/shuffleCmd/upadateMediaItemInAudioService[typo]/toggleQueueLoopMode/clearQueue(keep0)`.
- `checkNGetUrl` 3-tier (see 02). `_normalizeVolume(db)=10^((-5-db)/20).clamp(0,1)`. `_shuffleCmd(index)`: `queueIds-current+shuffle+insert0`. `saveSessionData`: if `restorePlaybackSession` persist `prevSessionData{queue:[json],position,index}`.
- Auto: `getChildren/subscribeToChildren/playFromMediaId→customEvent{songId,libraryId}`. `onTaskRemoved`: if `stopPlyabackOnSwipeAway` → `cachedHomeScreenData+saveSession+stop`. `stop→_player.stop+super.stop`.

## 3.2 `playByIndex` state machine (must clone exactly)

```
currentIndex=index; future=checkNGetUrl(id,generateNewUrl); isSongLoading=true→loading state;
_playList.clear(); mediaItem.add(currentSong); streamInfo=await future;
if (index!=currentIndex) return; // stale guard
if (!playable) { currentSongUrl=null; isSongLoading=false; notifyPlayError(statusMSG); playbackState error404; return; }
currentSongUrl=extras[url]=streamInfo.audio.url; playbackState queueIndex;
_playList.add(_createAudioSource); isSongLoading=false;
if (loudness&&Android) _normalizeVolume(loudnessDb);
if (restoreSession) { load(); seek(position)×2 } else play();
```

`setSourceNPlay`: same but `currentIndex=0, queue=[curr]` then resolve+play.

## 3.3 `PlayerController` bridge (`ui/player/player_controller.dart`)

State: `_audioHandler,_musicServices, currentQueue.obs, progressBarStatus:ProgressBarState(current,buffered,total).obs, currentSong Rxn, currentSongIndex, buttonState{paused,playing,loading}.obs, isLoop/Shuffle/QueueLoop, isRadioModeOn+radioContinuationParam+radioInitiatorItem, sleepTimer/timerDuration/Left/isSleepTimerActive/isSleepEndOfSongActive, volume, lyrics/synced/plain, playinfrom:PlaylingFrom, wakelock, _newSongFlag`.

- `_init`: prefs (loop/shuffle/queueLoop, desktop volume, playerUi anim, Android customEvent), listeners below.
- playbackState→`buttonState` (loading/buffering→loading, !playing/error→paused else playing, completed→seek0+pause) + wakelock (`keepScreenAwake&&playing`).
- position→`progressBar.current`; `total-pos==1s && sleepEndOfSong→pause+cancel`.
- buffered→`buffered`; `≥98% && _newSongFlag→customAction(checkWithCacheDb)` once.
- mediaItem→`total/currentSong/index/_checkFav/_addToRP(radio? continuation)`; reset lyrics/gesture.
- queue→`currentQueue`.
- `pushSongToQueue(item,{playlistId,radio})`: `playinfrom=SELECTION`, `isRadio=radio`, `getWatchPlaylist(radio,playlistId)→radioContinuationParam, updateQueue, shuffleCmd?`; `playlistId==null→setSourceNPlay` fast-path else panel+`playByIndex(0)`; BOLI discover update; disable queueLoop if radio.
- `playPlayListSong(list,idx)`, `startRadio(item)` + `_addRadioContinuation` (`limit24+additionalParamsNext→enqueueSongList` deduped, triggered when `mediaItem==queue.last`).
- Thin wrappers: `enqueue/enqueueList/playNext(remove-dup+insert current+1 or reorder)/remove/clear/shuffle/onReorder/seek/seekByIndex/play/pause/playPause/prev/next`.
- Toggles: `toggleShuffle/Loop/QueueLoop(blocked if shuffle+queueLoop or radio+queueLoop→snackbar)/SkipSilence/Loudness/setVolume/mute/openEqualizer`.
- `_restorePrevSession`: if `restrorePlaybackSession[typo]` → `prevSessionData→addQueueItems+playByIndex(restoreSession+position)`.
- `_playViaAndroidAuto`, `_addToRP(LIBRP cap30 dedup reversed)`, `_checkFav/toggleFavourite(+autoDownloadFavorite)`, `showLyrics` (see 06), `sleepEndOfSong/startSleepTimer(+5/cancel)`, `notifyPlayError`, `dispose→customAction(dispose)`.

## 3.4 Extras

- `ProgressBarState{current,buffered,total}`, `PlaylingFrom{ALBUM,PLAYLIST,SELECTION,ARTIST}`.
- Sleep sheet (`sleep_timer_bottom_sheet.dart`): `5/10/15/30/45/60→startSleepTimer`, `+5min`, `endOfThisSong`, cancel; `Timer.periodic(1s)` tick→pause+cancel.
- EQ (`equalizer.dart` via `jni`): `open/init/endAudioEffect(sessionId)` → `native_bindings/andrid_utils.dart Equalizer/SDKInt`; `openEqualizer→_player.androidAudioSessionId`.
- Loudness (Android): re-read `SongsUrlCache.high.loudnessDb` or `SongDownloads.streamInfo[1].loudnessDb` on toggle.
- Skip-silence: `just_audio.setSkipSilenceEnabled` (desktop forced false).
- Volume desktop `0-100→0-1` persisted `AppPrefs.volume`; `WindowsAudioService` (SMTC) created in `onReady` if Windows, deleted on dispose.
