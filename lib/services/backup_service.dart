import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../models/playlist_item.dart';
import '../models/song_item.dart';
import 'cache_service.dart';
import 'constant.dart';
import 'download_service.dart';
import 'library_service.dart';
import 'player_controller.dart';

/// Result summary of a backup export or import operation
class BackupResult {
  final bool success;
  final String message;
  final String? filePath;
  final int likedCount;
  final int playlistsCount;
  final int downloadedCount;
  final int cachedCount;

  const BackupResult({
    required this.success,
    required this.message,
    this.filePath,
    this.likedCount = 0,
    this.playlistsCount = 0,
    this.downloadedCount = 0,
    this.cachedCount = 0,
  });
}

/// Service managing export and import of application backups in a single portable JSON file.
/// On backup restore:
/// - Liked songs and custom playlists are restored into Hive
/// - Downloaded songs list is processed by queuing downloads to disk
/// - Cached songs list is processed by caching audio streams in background
class BackupService extends GetxService {
  /// Generate the in-memory JSON data map representing the full backup
  Map<String, dynamic> generateBackupData() {
    final favBox = Hive.box(Constant.boxLibFav);
    final playlistBox = Hive.box(Constant.boxLibraryPlaylists);
    final downloadsBox = Hive.box(Constant.boxSongDownloads);
    final cacheBox = Hive.box(Constant.boxSongsCache);
    final prefsBox = Hive.box(Constant.boxAppPrefs);

    // 1. Liked songs
    final likedList = <Map<String, dynamic>>[];
    for (final key in favBox.keys) {
      final val = favBox.get(key);
      if (val is Map) {
        likedList.add(SongItem.fromJson(Map<String, dynamic>.from(val)).copyWith(isLiked: true).toJson());
      }
    }

    // 2. Playlists
    final playlistsList = <Map<String, dynamic>>[];
    for (final key in playlistBox.keys) {
      final val = playlistBox.get(key);
      if (val is Map) {
        playlistsList.add(PlaylistItem.fromJson(Map<String, dynamic>.from(val)).toJson());
      }
    }

    // 3. Downloaded songs list
    final downloadedList = <Map<String, dynamic>>[];
    for (final key in downloadsBox.keys) {
      final val = downloadsBox.get(key);
      if (val is Map) {
        downloadedList.add(SongItem.fromJson(Map<String, dynamic>.from(val)).copyWith(isDownloaded: true).toJson());
      }
    }

    // 4. Cached songs list
    final cachedList = <Map<String, dynamic>>[];
    for (final key in cacheBox.keys) {
      final val = cacheBox.get(key);
      if (val is Map) {
        cachedList.add(SongItem.fromJson(Map<String, dynamic>.from(val)).copyWith(isCached: true).toJson());
      }
    }

    // 5. Preferences
    final prefsMap = <String, dynamic>{
      Constant.prefStreamingQuality: prefsBox.get(Constant.prefStreamingQuality, defaultValue: Constant.qualityHigh),
      Constant.prefSkipSilenceEnabled: prefsBox.get(Constant.prefSkipSilenceEnabled, defaultValue: false),
      Constant.prefLoudnessNormalization: prefsBox.get(Constant.prefLoudnessNormalization, defaultValue: true),
      Constant.prefCacheSongs: prefsBox.get(Constant.prefCacheSongs, defaultValue: true),
      Constant.prefCloseAction: prefsBox.get(Constant.prefCloseAction, defaultValue: Constant.closeActionAsk),
    };

    return {
      'appName': 'Villupaatukaaran',
      'format': 'villupaatukaaran_backup',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'summary': {
        'likedCount': likedList.length,
        'playlistsCount': playlistsList.length,
        'downloadedCount': downloadedList.length,
        'cachedCount': cachedList.length,
      },
      'likedSongs': likedList,
      'playlists': playlistsList,
      'downloadedSongs': downloadedList,
      'cachedSongs': cachedList,
      'preferences': prefsMap,
    };
  }

  /// Export backup to a single JSON file.
  /// If [targetFilePath] is null, opens file picker for user selection.
  Future<BackupResult> exportBackup({String? targetFilePath}) async {
    try {
      final backupData = generateBackupData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);

      String? savePath = targetFilePath;
      if (savePath == null) {
        final nowStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final defaultName = 'villupaatukaaran_backup_$nowStr.json';
        savePath = await FilePicker.saveFile(
          dialogTitle: 'Export Villupaatukaaran Backup',
          fileName: defaultName,
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
      }

      if (savePath == null || savePath.isEmpty) {
        return const BackupResult(success: false, message: 'Export cancelled');
      }

      if (!savePath.toLowerCase().endsWith('.json')) {
        savePath = '$savePath.json';
      }

      final file = File(savePath);
      await file.writeAsString(jsonString);

      final summary = backupData['summary'] as Map<String, dynamic>;
      return BackupResult(
        success: true,
        message: 'Backup exported successfully to $savePath',
        filePath: savePath,
        likedCount: summary['likedCount'] as int,
        playlistsCount: summary['playlistsCount'] as int,
        downloadedCount: summary['downloadedCount'] as int,
        cachedCount: summary['cachedCount'] as int,
      );
    } catch (e) {
      debugPrint('[BackupService] Export error: $e');
      return BackupResult(
        success: false,
        message: 'Export failed: $e',
      );
    }
  }

  /// Inspect a backup file without applying modifications
  Future<Map<String, dynamic>?> inspectBackupFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      final data = jsonDecode(content);
      if (data is Map<String, dynamic>) {
        return data;
      } else if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      debugPrint('[BackupService] Inspect error: $e');
    }
    return null;
  }

  /// Import backup from file and restore data.
  /// Downloaded tracks are queued for download to disk.
  /// Cached tracks are queued for caching into stream cache.
  Future<BackupResult> importBackup({
    String? sourceFilePath,
    bool queueDownloads = true,
    bool queueCaching = true,
  }) async {
    try {
      String? loadPath = sourceFilePath;
      if (loadPath == null) {
        final result = await FilePicker.pickFiles(
          dialogTitle: 'Select Villupaatukaaran Backup File',
          type: FileType.custom,
          allowedExtensions: ['json', 'vpb'],
        );
        if (result == null || result.files.isEmpty) {
          return const BackupResult(success: false, message: 'Import cancelled');
        }
        loadPath = result.files.first.path;
      }

      if (loadPath == null || loadPath.isEmpty) {
        return const BackupResult(success: false, message: 'No file selected');
      }

      final file = File(loadPath);
      if (!await file.exists()) {
        return BackupResult(success: false, message: 'File not found: $loadPath');
      }

      final rawContent = await file.readAsString();
      final parsed = jsonDecode(rawContent);
      if (parsed is! Map) {
        return const BackupResult(success: false, message: 'Invalid backup file format');
      }
      final backup = Map<String, dynamic>.from(parsed);

      // Support root-level keys and nested 'data' key
      final data = backup['data'] is Map ? Map<String, dynamic>.from(backup['data'] as Map) : backup;

      final rawLiked = data['likedSongs'] is List ? (data['likedSongs'] as List) : [];
      final rawPlaylists = data['playlists'] is List ? (data['playlists'] as List) : [];
      final rawDownloaded = data['downloadedSongs'] is List ? (data['downloadedSongs'] as List) : [];
      final rawCached = data['cachedSongs'] is List ? (data['cachedSongs'] as List) : [];
      final rawPrefs = data['preferences'] is Map ? (data['preferences'] as Map) : null;

      // 1. Restore Liked Songs
      final favBox = Hive.box(Constant.boxLibFav);
      int likedCount = 0;
      for (final item in rawLiked) {
        if (item is Map) {
          final song = SongItem.fromJson(Map<String, dynamic>.from(item)).copyWith(isLiked: true);
          await favBox.put(song.videoId, song.toJson());
          likedCount++;
        }
      }

      // 2. Restore Playlists
      final playlistBox = Hive.box(Constant.boxLibraryPlaylists);
      int playlistsCount = 0;
      for (final item in rawPlaylists) {
        if (item is Map) {
          final pl = PlaylistItem.fromJson(Map<String, dynamic>.from(item));
          await playlistBox.put(pl.id, pl.toJson());
          playlistsCount++;
        }
      }

      // 3. Restore Preferences
      if (rawPrefs != null) {
        final prefsBox = Hive.box(Constant.boxAppPrefs);
        for (final entry in rawPrefs.entries) {
          await prefsBox.put(entry.key.toString(), entry.value);
        }
      }

      // 4. Restore Downloaded Songs (queued for offline download "as such")
      int downloadedQueued = 0;
      final songsToDownload = <SongItem>[];
      if (queueDownloads && Get.isRegistered<DownloadService>()) {
        final downloadService = Get.find<DownloadService>();
        for (final item in rawDownloaded) {
          if (item is Map) {
            final song = SongItem.fromJson(Map<String, dynamic>.from(item));
            if (!downloadService.isSongDownloaded(song.videoId)) {
              songsToDownload.add(song);
            }
          }
        }
        for (final song in songsToDownload) {
          await downloadService.downloadSong(song);
          downloadedQueued++;
        }
      }

      // 5. Restore Cached Songs (queued for background caching "as such")
      int cachedQueued = 0;
      final songsToCache = <SongItem>[];
      if (queueCaching && Get.isRegistered<CacheService>()) {
        final cacheService = Get.find<CacheService>();
        final downloadService = Get.isRegistered<DownloadService>() ? Get.find<DownloadService>() : null;
        for (final item in rawCached) {
          if (item is Map) {
            final song = SongItem.fromJson(Map<String, dynamic>.from(item));
            final alreadyDl = downloadService?.isSongDownloaded(song.videoId) ?? false;
            if (!cacheService.isSongCached(song.videoId) && !alreadyDl) {
              songsToCache.add(song);
            }
          }
        }
        _startBackgroundCaching(songsToCache);
        cachedQueued = songsToCache.length;
      }

      // 6. Refresh UI services
      if (Get.isRegistered<LibraryService>()) {
        await Get.find<LibraryService>().refreshAll();
      }
      if (Get.isRegistered<PlayerController>()) {
        final favKeys = favBox.keys.map((k) => k.toString()).toSet();
        Get.find<PlayerController>().likedSongIds.assignAll(favKeys);
      }

      return BackupResult(
        success: true,
        message: 'Backup restored: $likedCount liked, $playlistsCount playlists, $downloadedQueued downloads queued, $cachedQueued caching.',
        filePath: loadPath,
        likedCount: likedCount,
        playlistsCount: playlistsCount,
        downloadedCount: downloadedQueued,
        cachedCount: cachedQueued,
      );
    } catch (e) {
      debugPrint('[BackupService] Import error: $e');
      return BackupResult(
        success: false,
        message: 'Import failed: $e',
      );
    }
  }

  /// Sequential background caching processor
  void _startBackgroundCaching(List<SongItem> songs) {
    if (songs.isEmpty) return;
    Future.microtask(() async {
      if (!Get.isRegistered<CacheService>()) return;
      final cacheService = Get.find<CacheService>();
      for (final song in songs) {
        try {
          if (!cacheService.isSongCached(song.videoId)) {
            await cacheService.cacheSong(song);
            await Future.delayed(const Duration(milliseconds: 300));
          }
        } catch (e) {
          debugPrint('[BackupService] Background cache error for ${song.title}: $e');
        }
      }
      if (Get.isRegistered<LibraryService>()) {
        await Get.find<LibraryService>().loadCachedSongs();
      }
    });
  }
}
