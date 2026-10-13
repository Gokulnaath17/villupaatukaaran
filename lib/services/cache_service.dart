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

  final RxString baseDir = ''.obs;
  final RxString downloadsDir = ''.obs;
  final RxString cacheDir = ''.obs;
  final RxInt cacheSizeLimit = 350.obs; // Default 350 songs limit
  final RxBool autoCacheEnabled = true.obs;
  final RxInt cachedSongsCount = 0.obs;
  final RxString cachedTotalSize = '0 MB'.obs;

  // Backward compatibility getters
  RxString get audioDir => downloadsDir;
  RxString get videoDir => downloadsDir;

  /// Resolves the default storage root directory on the system
  static Future<String> resolveDefaultBaseDir() async {
    if (Constant.isLinux || Constant.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        final music = Directory('$home/Music');
        if (await music.exists()) {
          return '$home/Music/${Constant.baseDirName}';
        }
        return '$home/${Constant.baseDirName}';
      }
    } else if (Constant.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        final music = Directory('$userProfile\\Music');
        if (await music.exists()) {
          return '$userProfile\\Music\\${Constant.baseDirName}';
        }
        return '$userProfile\\${Constant.baseDirName}';
      }
    }
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/${Constant.baseDirName}';
  }

  Future<CacheService> init() async {
    _prefsBox = Hive.box(Constant.boxAppPrefs);
    _cacheBox = Hive.box(Constant.boxSongsCache);
    _downloadsBox = Hive.box(Constant.boxSongDownloads);

    // Load preferences
    cacheSizeLimit.value = _prefsBox.get('cacheSizeLimit', defaultValue: 350) as int;
    autoCacheEnabled.value = _prefsBox.get(Constant.prefCacheSongs, defaultValue: true) as bool;

    // Initialize unified base directory
    final savedBaseDir = _prefsBox.get(Constant.prefBaseStorageDir) as String?;
    final defaultBase = await resolveDefaultBaseDir();
    final effectiveBase = (savedBaseDir != null && savedBaseDir.isNotEmpty) ? savedBaseDir : defaultBase;

    await setBaseDir(effectiveBase);
    await updateCacheStats();
    return this;
  }

  /// Update unified base storage directory and its subfolders
  Future<void> setBaseDir(String path) async {
    baseDir.value = path;
    downloadsDir.value = '$path/${Constant.downloadDirName}';
    cacheDir.value = '$path/${Constant.tempCacheDirName}';

    await _prefsBox.put(Constant.prefBaseStorageDir, path);

    // Ensure subdirectories exist
    await Directory(downloadsDir.value).create(recursive: true);
    await Directory(cacheDir.value).create(recursive: true);
    await updateCacheStats();
  }

  // Backward compatibility setters
  Future<void> setAudioDir(String path) async => setBaseDir(path);
  Future<void> setVideoDir(String path) async => setBaseDir(path);
  Future<void> setCacheDir(String path) async => setBaseDir(path);

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
    if (audioUrl.startsWith('file://') || audioUrl.startsWith('/')) {
      return; // Already a local file
    }
    if (_cacheBox.containsKey(song.videoId) || _downloadsBox.containsKey(song.videoId)) {
      return; // Already cached or downloaded
    }

    try {
      final ext = audioUrl.contains('.m4a') ? 'm4a' : 'opus';
      final fileName = '${song.videoId}.$ext';
      final savePath = '${cacheDir.value}/$fileName';

      // Download audio stream in background with proper headers
      await _dio.download(
        audioUrl,
        savePath,
        options: Options(headers: {
          'User-Agent': Constant.innertubeUserAgent,
        }),
        deleteOnError: true,
      );

      final file = File(savePath);
      if (await file.exists()) {
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
      }
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

    int safeCachedAt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val != null) return int.tryParse(val.toString()) ?? 0;
      return 0;
    }

    entries.sort((a, b) => safeCachedAt(a['cachedAt']).compareTo(safeCachedAt(b['cachedAt'])));

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

  /// Batch-move all cached songs to the permanent offline downloads directory
  Future<int> moveAllCachedToDownloads() async {
    int count = 0;
    final keys = _cacheBox.keys.toList();

    for (final key in keys) {
      final val = _cacheBox.get(key);
      if (val is Map) {
        final cachedPath = val['filePath'] as String?;
        if (cachedPath != null && File(cachedPath).existsSync()) {
          final ext = cachedPath.contains('.') ? cachedPath.split('.').last : 'opus';
          final song = SongItem.fromJson(Map<String, dynamic>.from(val));
          final cleanArtist = song.artist
              .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          final cleanTitle = song.title
              .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          String baseName = (cleanArtist.isNotEmpty && cleanArtist.toLowerCase() != 'unknown artist')
              ? '$cleanArtist - $cleanTitle'
              : (cleanTitle.isNotEmpty ? cleanTitle : key.toString());
          if (baseName.length > 120) baseName = baseName.substring(0, 120).trim();
          final targetPath = '${downloadsDir.value}/$baseName.$ext';
          try {
            await File(cachedPath).copy(targetPath);
            final targetFile = File(targetPath);
            final targetSize = await targetFile.length();

            final songData = Map<String, dynamic>.from(val);
            songData['filePath'] = targetPath;
            songData['url'] = targetPath;
            songData['isDownloaded'] = true;
            songData['downloadedAt'] = DateTime.now().millisecondsSinceEpoch;
            songData['sizeBytes'] = targetSize;

            await _downloadsBox.put(key, songData);
            count++;
          } catch (e) {
            debugPrint('[CacheService] Error moving cached song $key to downloads: $e');
          }
        }
      }
    }
    return count;
  }

  /// Wipes all files from cache and downloads folders
  Future<void> wipeAllStorageFiles() async {
    for (final dirPath in [cacheDir.value, downloadsDir.value]) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        try {
          final entities = dir.listSync();
          for (final e in entities) {
            if (e is File) {
              try {
                await e.delete();
              } catch (_) {}
            }
          }
        } catch (_) {}
      }
    }
    await _cacheBox.clear();
    await _downloadsBox.clear();
    await updateCacheStats();
  }
}

