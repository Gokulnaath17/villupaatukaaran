import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'constant.dart';
import '../models/song_item.dart';

/// Cache & offline storage service
/// Ensures fast playback with auto-caching and configurable limits
class CacheService extends GetxService {
  late Box _prefsBox;
  late Box _cacheBox;
  late Box _downloadsBox;
  final Dio _dio = Dio();

  final RxString audioDir = ''.obs;
  final RxString videoDir = ''.obs;
  final RxString cacheDir = ''.obs;
  final RxInt cacheSizeLimit = 350.obs; // Default 350 songs limit
  final RxBool autoCacheEnabled = true.obs;
  final RxInt cachedSongsCount = 0.obs;
  final RxString cachedTotalSize = '0 MB'.obs;

  Future<CacheService> init() async {
    _prefsBox = Hive.box(Constant.boxAppPrefs);
    _cacheBox = Hive.box(Constant.boxSongsCache);
    _downloadsBox = Hive.box(Constant.boxSongDownloads);

    // Load preferences
    cacheSizeLimit.value = _prefsBox.get('cacheSizeLimit', defaultValue: 350) as int;
    autoCacheEnabled.value = _prefsBox.get(Constant.prefCacheSongs, defaultValue: true) as bool;

    // Initialize default directories
    final appDir = await getApplicationDocumentsDirectory();

    final savedAudioDir = _prefsBox.get('customAudioDir') as String?;
    final savedVideoDir = _prefsBox.get('customVideoDir') as String?;
    final savedCacheDir = _prefsBox.get('customCacheDir') as String?;

    audioDir.value = savedAudioDir ?? '${appDir.path}/Music';
    videoDir.value = savedVideoDir ?? '${appDir.path}/Videos';
    cacheDir.value = savedCacheDir ?? '${appDir.path}/${Constant.tempCacheDirName}';

    // Create directories if they don't exist
    await Directory(audioDir.value).create(recursive: true);
    await Directory(videoDir.value).create(recursive: true);
    await Directory(cacheDir.value).create(recursive: true);

    await updateCacheStats();
    return this;
  }

  /// Update directory path in settings
  Future<void> setAudioDir(String path) async {
    audioDir.value = path;
    await _prefsBox.put('customAudioDir', path);
    await Directory(path).create(recursive: true);
  }

  Future<void> setVideoDir(String path) async {
    videoDir.value = path;
    await _prefsBox.put('customVideoDir', path);
    await Directory(path).create(recursive: true);
  }

  Future<void> setCacheDir(String path) async {
    cacheDir.value = path;
    await _prefsBox.put('customCacheDir', path);
    await Directory(path).create(recursive: true);
    await updateCacheStats();
  }

  Future<void> setCacheLimit(int limit) async {
    cacheSizeLimit.value = limit;
    await _prefsBox.put('cacheSizeLimit', limit);
    await enforceCacheLimit();
  }

  Future<void> toggleAutoCache(bool enabled) async {
    autoCacheEnabled.value = enabled;
    await _prefsBox.put(Constant.prefCacheSongs, enabled);
  }

  /// Auto-cache a song in the background for fast replay
  Future<void> autoCacheSong(SongItem song, String audioUrl) async {
    if (!autoCacheEnabled.value) return;
    if (_cacheBox.containsKey(song.videoId) || _downloadsBox.containsKey(song.videoId)) {
      return; // Already cached or downloaded
    }

    try {
      final ext = audioUrl.contains('.m4a') ? 'm4a' : 'opus';
      final fileName = '${song.videoId}.$ext';
      final savePath = '${cacheDir.value}/$fileName';

      // Download audio stream chunk in background
      await _dio.download(
        audioUrl,
        savePath,
        deleteOnError: true,
      );

      final file = File(savePath);
      final fileSize = await file.length();

      // Record in cache box
      await _cacheBox.put(song.videoId, {
        ...song.toJson(),
        'filePath': savePath,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
        'sizeBytes': fileSize,
      });

      await enforceCacheLimit();
      await updateCacheStats();
    } catch (e) {
      debugPrint('[CacheService] Auto-cache error for ${song.title}: $e');
    }
  }

  /// Check if a song is cached locally
  bool isSongCached(String videoId) {
    if (!_cacheBox.containsKey(videoId)) return false;
    final data = _cacheBox.get(videoId);
    if (data is Map && data['filePath'] != null) {
      return File(data['filePath'] as String).existsSync();
    }
    return false;
  }

  /// Get local file path if cached
  String? getCachedFilePath(String videoId) {
    final data = _cacheBox.get(videoId);
    if (data is Map && data['filePath'] != null) {
      final path = data['filePath'] as String;
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  /// Enforce cache limit (FIFO eviction when exceeding cacheSizeLimit)
  Future<void> enforceCacheLimit() async {
    final keys = _cacheBox.keys.toList();
    if (keys.length <= cacheSizeLimit.value) return;

    // Sort by cachedAt ascending (oldest first)
    final entries = <Map<String, dynamic>>[];
    for (final key in keys) {
      final val = _cacheBox.get(key);
      if (val is Map) {
        entries.add({
          'key': key,
          'cachedAt': val['cachedAt'] ?? 0,
          'filePath': val['filePath'],
        });
      }
    }

    entries.sort((a, b) => (a['cachedAt'] as int).compareTo(b['cachedAt'] as int));

    final toRemove = entries.length - cacheSizeLimit.value;
    for (int i = 0; i < toRemove; i++) {
      final item = entries[i];
      final path = item['filePath'] as String?;
      if (path != null) {
        final f = File(path);
        if (await f.exists()) await f.delete();
      }
      await _cacheBox.delete(item['key']);
    }
  }

  /// Get list of all currently cached songs
  List<SongItem> getCachedSongs() {
    final list = <SongItem>[];
    for (final key in _cacheBox.keys) {
      final val = _cacheBox.get(key);
      if (val is Map) {
        list.add(SongItem.fromJson(val).copyWith(isCached: true));
      }
    }
    return list;
  }

  /// Clear entire cache
  Future<void> clearCache() async {
    final dir = Directory(cacheDir.value);
    if (await dir.exists()) {
      final entities = dir.listSync();
      for (final e in entities) {
        if (e is File) {
          try {
            await e.delete();
          } catch (_) {}
        }
      }
    }
    await _cacheBox.clear();
    await updateCacheStats();
  }

  /// Update statistics for UI display
  Future<void> updateCacheStats() async {
    cachedSongsCount.value = _cacheBox.length;
    int totalBytes = 0;

    final dir = Directory(cacheDir.value);
    if (await dir.exists()) {
      try {
        final files = dir.listSync();
        for (final f in files) {
          if (f is File) {
            totalBytes += f.lengthSync();
          }
        }
      } catch (_) {}
    }

    final mb = totalBytes / (1024 * 1024);
    cachedTotalSize.value = mb > 1024
        ? '${(mb / 1024).toStringAsFixed(1)} GB'
        : '${mb.toStringAsFixed(1)} MB';
  }
}

