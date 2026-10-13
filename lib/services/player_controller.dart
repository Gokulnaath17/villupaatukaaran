import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_handler.dart';
import 'cache_service.dart';
import 'constant.dart';
import 'library_service.dart';
import 'music_service.dart';
import '../models/song_item.dart';

/// Central player controller for reactive UI bindings
class PlayerController extends GetxController {
  late final MyAudioHandler _audioHandler;
  late final MusicService _musicService;
  late final CacheService _cacheService;
  late final Box _favBox;
  late final Box _historyBox;

  final Rx<SongItem?> currentSong = Rx<SongItem?>(null);
  final RxBool isPlaying = false.obs;
  final RxBool isBuffering = false.obs;
  final Rx<Duration> position = Duration.zero.obs;
  final Rx<Duration> duration = Duration.zero.obs;
  final RxList<SongItem> queue = <SongItem>[].obs;
  final RxBool isShuffle = false.obs;
  final Rx<LoopMode> loopMode = LoopMode.off.obs;
  final RxDouble volume = 1.0.obs;
  final RxSet<String> likedSongIds = <String>{}.obs;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _mediaSub;
  StreamSubscription? _queueSub;

  @override
  void onInit() {
    super.onInit();
    _initController();
  }

  Future<void> _initController() async {
    _audioHandler = Get.find<MyAudioHandler>();
    _musicService = Get.isRegistered<MusicService>()
        ? Get.find<MusicService>()
        : await MusicService().init();
    _cacheService = Get.isRegistered<CacheService>()
        ? Get.find<CacheService>()
        : await CacheService().init();

    _favBox = Hive.isBoxOpen(Constant.boxLibFav)
        ? Hive.box(Constant.boxLibFav)
        : await Hive.openBox(Constant.boxLibFav);

    _historyBox = Hive.isBoxOpen(Constant.boxLibRP)
        ? Hive.box(Constant.boxLibRP)
        : await Hive.openBox(Constant.boxLibRP);

    // Load liked song IDs into set and watch for external mutations/resets
    likedSongIds.assignAll(_favBox.keys.map((k) => k.toString()));
    _favBox.watch().listen((_) {
      likedSongIds.assignAll(_favBox.keys.map((k) => k.toString()));
    });

    // Listen to mediaItem changes
    _mediaSub = _audioHandler.mediaItem.listen((item) {
      if (item != null) {
        final song = SongItem.fromMediaItem(item).copyWith(
          isLiked: likedSongIds.contains(item.id),
          isCached: _cacheService.isSongCached(item.id),
        );
        currentSong.value = song;
        duration.value = item.duration ?? Duration.zero;

        // Add to recently played history
        _addToHistory(song);

        // Auto-cache track if stream URL is available
        if (song.url != null && song.url!.isNotEmpty) {
          _cacheService.autoCacheSong(song, song.url!);
        }
      } else {
        currentSong.value = null;
      }
    });

    // Listen to playbackState changes
    _stateSub = _audioHandler.playbackState.listen((state) {
      isPlaying.value = state.playing;
      isBuffering.value = state.processingState == AudioProcessingState.buffering ||
          state.processingState == AudioProcessingState.loading;
      position.value = state.position;
    });

    // Listen to queue changes
    _queueSub = _audioHandler.queue.listen((items) {
      queue.value = items.map((m) {
        final s = SongItem.fromMediaItem(m);
        return s.copyWith(
          isLiked: likedSongIds.contains(s.videoId),
          isCached: _cacheService.isSongCached(s.videoId),
        );
      }).toList();
    });

    // Listen to player position directly for smooth 60fps slider
    _posSub = _audioHandler.player.positionStream.listen((pos) {
      position.value = pos;
    });

    // Listen to real stream duration from audio player
    _durSub = _audioHandler.player.durationStream.listen((dur) {
      if (dur != null && dur > Duration.zero) {
        duration.value = dur;
      }
    });

    // Listen to player volume
    _audioHandler.player.volumeStream.listen((v) {
      volume.value = v;
    });

    // Restore previous session if available
    _audioHandler.restoreSession();
  }

  /// Play a song immediately, with optional queue context
  Future<void> playSong(SongItem song, {List<SongItem>? queueContext, int index = 0}) async {
    final list = queueContext ?? [song];
    final mediaItems = list.map((s) => s.toMediaItem()).toList();
    await _audioHandler.setQueueAndPlay(mediaItems, initialIndex: index);

    // If queueContext has only 1 track and it's not a local file, fetch radio continuation in background
    if (list.length == 1 && !song.videoId.startsWith('local_')) {
      _fetchRadioContinuation(song.videoId);
    }
  }

  /// Play an entire list of songs with optional shuffle and initial index
  Future<void> playAllSongs(List<SongItem> songs, {bool shuffle = false, int initialIndex = 0}) async {
    if (songs.isEmpty) return;
    final list = List<SongItem>.from(songs);
    if (shuffle) {
      list.shuffle();
    }
    final mediaItems = list.map((s) => s.toMediaItem()).toList();
    final safeIndex = (initialIndex >= 0 && initialIndex < mediaItems.length) ? initialIndex : 0;
    await _audioHandler.setQueueAndPlay(mediaItems, initialIndex: safeIndex);
  }

  /// Fetch radio queue continuation (auto-play similar tracks)
  Future<void> _fetchRadioContinuation(String videoId) async {
    try {
      final watchData = await _musicService.getWatchPlaylist(videoId: videoId, radio: true);
      final rawTracks = watchData['tracks'] as List?;
      if (rawTracks != null && rawTracks.isNotEmpty) {
        final additionalSongs = rawTracks
            .map((t) => SongItem.fromInnertube(t as Map<String, dynamic>))
            .where((s) => s.videoId != videoId)
            .toList();

        final mediaItems = additionalSongs.map((s) => s.toMediaItem()).toList();
        await _audioHandler.addQueueItems(mediaItems);
      }
    } catch (e) {
      debugPrint('[PlayerController] Radio continuation error: $e');
    }
  }

  /// Action: Play Next
  Future<void> playNext(SongItem song) async {
    await _audioHandler.insertNext(song.toMediaItem());
    Get.snackbar(
      'Queued Next',
      song.title,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  /// Action: Add to Queue
  Future<void> addToQueue(SongItem song) async {
    await _audioHandler.addQueueItem(song.toMediaItem());
    Get.snackbar(
      'Added to Queue',
      song.title,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  /// Action: Toggle Play/Pause
  Future<void> togglePlayPause() async {
    if (isPlaying.value) {
      await _audioHandler.pause();
    } else {
      await _audioHandler.play();
    }
  }

  /// Action: Stop playback
  Future<void> stop() async {
    await _audioHandler.stop();
    currentSong.value = null;
    queue.clear();
  }

  /// Action: Seek
  Future<void> seek(Duration pos) async {
    await _audioHandler.seek(pos);
  }

  /// Action: Skip Next
  Future<void> skipToNext() async {
    await _audioHandler.skipToNext();
  }

  /// Action: Skip Previous
  Future<void> skipToPrevious() async {
    await _audioHandler.skipToPrevious();
  }

  /// Action: Jump to queue index
  Future<void> skipToQueueIndex(int index) async {
    await _audioHandler.skipToQueueItem(index);
  }

  /// Action: Remove from queue
  Future<void> removeFromQueue(int index) async {
    await _audioHandler.removeQueueItemAt(index);
  }

  /// Action: Clear Queue
  Future<void> clearQueue() async {
    await _audioHandler.clearUpcomingQueue();
  }

  /// Action: Toggle Shuffle
  Future<void> toggleShuffle() async {
    await _audioHandler.toggleShuffle();
    isShuffle.value = _audioHandler.player.shuffleModeEnabled;
  }

  /// Action: Cycle Loop Mode
  Future<void> cycleLoopMode() async {
    final mode = await _audioHandler.cycleLoopMode();
    loopMode.value = mode;
  }

  double _lastNonZeroVolume = 1.0;

  /// Action: Set Volume (0.0 to 1.0)
  Future<void> setVolume(double val) async {
    final clamped = val.clamp(0.0, 1.0);
    volume.value = clamped;
    if (clamped > 0.0) {
      _lastNonZeroVolume = clamped;
    }
    await _audioHandler.setVolume(clamped);
  }

  /// Action: Toggle Mute
  Future<void> toggleMute() async {
    if (volume.value > 0.001) {
      _lastNonZeroVolume = volume.value;
      await setVolume(0.0);
    } else {
      await setVolume(_lastNonZeroVolume > 0.0 ? _lastNonZeroVolume : 0.8);
    }
  }

  /// Action: Toggle Favorite / Like
  Future<void> toggleLike(SongItem song) async {
    final isFav = likedSongIds.contains(song.videoId);
    if (isFav) {
      likedSongIds.remove(song.videoId);
      await _favBox.delete(song.videoId);
    } else {
      likedSongIds.add(song.videoId);
      await _favBox.put(song.videoId, song.toJson());
    }

    // Refresh current song if matches
    if (currentSong.value?.videoId == song.videoId) {
      currentSong.value = currentSong.value?.copyWith(isLiked: !isFav);
    }

    // Refresh LibraryService liked list immediately
    if (Get.isRegistered<LibraryService>()) {
      Get.find<LibraryService>().loadLikedSongs();
    }
  }

  bool isLiked(String videoId) => likedSongIds.contains(videoId);

  /// Clear all in-memory liked song IDs and reset active track's liked flag
  void clearLikedState() {
    likedSongIds.clear();
    if (currentSong.value != null && currentSong.value!.isLiked) {
      currentSong.value = currentSong.value!.copyWith(isLiked: false);
    }
  }

  /// Add track to recently played history (cap 30)
  Future<void> _addToHistory(SongItem song) async {
    try {
      final keys = _historyBox.keys.toList();
      // Remove existing to place at top
      for (final k in keys) {
        final val = _historyBox.get(k);
        if (val is Map && (val['videoId'] == song.videoId || val['id'] == song.videoId)) {
          await _historyBox.delete(k);
        }
      }

      await _historyBox.put(DateTime.now().millisecondsSinceEpoch, song.toJson());

      // Enforce cap 30
      if (_historyBox.length > Constant.libRPCap) {
        final oldestKeys = _historyBox.keys.toList()..sort();
        final toRemove = _historyBox.length - Constant.libRPCap;
        for (int i = 0; i < toRemove; i++) {
          await _historyBox.delete(oldestKeys[i]);
        }
      }
    } catch (e) {
      debugPrint('[PlayerController] History record error: $e');
    }
  }

  void saveSession() => _audioHandler.saveSession();

  @override
  void onClose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _mediaSub?.cancel();
    _queueSub?.cancel();
    super.onClose();
  }
}

