import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';

import 'constant.dart';
import 'stream_service.dart';
import '../models/song_item.dart';

/// Audio handler bridging just_audio and audio_service
class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  late final StreamService _streamService;

  // Stale-request guard for rapid song switching
  int _currentRequestId = 0;
  int _currentQueueIndex = 0;

  AudioPlayer get player => _player;
  int get currentQueueIndex => _currentQueueIndex;

  MyAudioHandler() {
    _initHandler();
  }

  Future<void> _initHandler() async {
    _streamService = Get.isRegistered<StreamService>()
        ? Get.find<StreamService>()
        : await StreamService().init();

    // Listen to player state and broadcast through audio_service
    _player.playbackEventStream.listen(_broadcastState);

    // Listen to player completion
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });
  }

  /// Broadcast current playback state to audio_service
  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    final queueIndex = _currentQueueIndex;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: queueIndex,
      ),
    );
  }

  /// Play a specific song by index in the queue
  Future<void> playByIndex(int index) async {
    if (index < 0 || index >= queue.value.length) return;

    final reqId = ++_currentRequestId;
    final targetItem = queue.value[index];
    _currentQueueIndex = index;

    // Update current mediaItem immediately for responsive UI
    mediaItem.add(targetItem);

    // Notify buffering state
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.buffering,
      playing: true,
      queueIndex: index,
    ));

    try {
      final videoId = targetItem.id;
      final streamData = await _streamService.getStreamingData(videoId);

      // Check if another request superseded this one
      if (reqId != _currentRequestId) return;

      if (!streamData.playable) {
        throw Exception(streamData.statusMsg.isNotEmpty
            ? streamData.statusMsg
            : 'Track is not playable');
      }

      final url = streamData.high?.url ?? streamData.low?.url;
      if (url == null || url.isEmpty) {
        throw Exception('Failed to resolve audio stream URL');
      }

      // Check if source is a local file
      AudioSource source;
      if (url.startsWith('/') || url.startsWith('file://')) {
        final filePath = url.replaceFirst('file://', '');
        source = AudioSource.file(filePath, tag: targetItem);
      } else {
        source = AudioSource.uri(Uri.parse(url), tag: targetItem);
      }

      await _player.setAudioSource(source);
      await _player.play();
    } catch (e) {
      debugPrint('[AudioHandler] Playback error: $e');
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ));
      Get.snackbar(
        'Playback Error',
        'Could not stream "${targetItem.title}": $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF221111),
        colorText: const Color(0xFFFF5555),
        duration: const Duration(seconds: 4),
      );
    }
  }

  /// Set the queue and play the specified index
  Future<void> setQueueAndPlay(List<MediaItem> items, {int initialIndex = 0}) async {
    if (items.isEmpty) return;

    await updateQueue(items);
    await playByIndex(initialIndex);
  }

  /// Insert an item to play immediately next in queue
  Future<void> insertNext(MediaItem item) async {
    final currentQueue = List<MediaItem>.from(queue.value);
    final currentIndex = _player.currentIndex ?? 0;

    final nextIndex = (currentIndex + 1).clamp(0, currentQueue.length);
    currentQueue.insert(nextIndex, item);
    await updateQueue(currentQueue);
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final currentQueue = List<MediaItem>.from(queue.value);
    currentQueue.add(mediaItem);
    await updateQueue(currentQueue);
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    final currentQueue = List<MediaItem>.from(queue.value);
    currentQueue.addAll(mediaItems);
    await updateQueue(currentQueue);
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    final currentQueue = List<MediaItem>.from(queue.value);
    if (index >= 0 && index < currentQueue.length) {
      currentQueue.removeAt(index);
      await updateQueue(currentQueue);
    }
  }

  /// Clear the entire upcoming queue (keeping current track)
  Future<void> clearUpcomingQueue() async {
    final currentIndex = _player.currentIndex ?? 0;
    if (queue.value.isEmpty) return;

    final currentTrack = queue.value[currentIndex.clamp(0, queue.value.length - 1)];
    await updateQueue([currentTrack]);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    final nextIndex = _currentQueueIndex + 1;
    if (nextIndex < queue.value.length) {
      await playByIndex(nextIndex);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    // If played more than 3 seconds, restart song; else go to previous
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    final prevIndex = _currentQueueIndex - 1;
    if (prevIndex >= 0 && prevIndex < queue.value.length) {
      await playByIndex(prevIndex);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    await playByIndex(index);
  }

  /// Toggle shuffle
  Future<void> toggleShuffle() async {
    final enable = !_player.shuffleModeEnabled;
    await _player.setShuffleModeEnabled(enable);
  }

  /// Cycle loop mode (off -> all -> one)
  Future<LoopMode> cycleLoopMode() async {
    final current = _player.loopMode;
    final next = switch (current) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await _player.setLoopMode(next);
    return next;
  }

  /// Save session state to Hive for persistence across app restarts
  Future<void> saveSession() async {
    try {
      final box = Hive.isBoxOpen(Constant.boxPrevSessionData)
          ? Hive.box(Constant.boxPrevSessionData)
          : await Hive.openBox(Constant.boxPrevSessionData);

      final songsJson = queue.value
          .map((m) => SongItem.fromMediaItem(m).toJson())
          .toList();

      await box.put('queue', songsJson);
      await box.put('index', _player.currentIndex ?? 0);
      await box.put('position', _player.position.inSeconds);
    } catch (e) {
      debugPrint('[AudioHandler] Failed to save session: $e');
    }
  }

  /// Restore saved session
  Future<bool> restoreSession() async {
    try {
      final box = Hive.isBoxOpen(Constant.boxPrevSessionData)
          ? Hive.box(Constant.boxPrevSessionData)
          : await Hive.openBox(Constant.boxPrevSessionData);

      final rawQueue = box.get('queue');
      if (rawQueue is List && rawQueue.isNotEmpty) {
        final songs = rawQueue
            .map((item) => SongItem.fromJson(item as Map<dynamic, dynamic>))
            .toList();
        final index = (box.get('index', defaultValue: 0) as int).clamp(0, songs.length - 1);
        final mediaItems = songs.map((s) => s.toMediaItem()).toList();

        await updateQueue(mediaItems);
        mediaItem.add(mediaItems[index]);
        return true;
      }
    } catch (e) {
      debugPrint('[AudioHandler] Failed to restore session: $e');
    }
    return false;
  }
}
