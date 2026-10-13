import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'cache_service.dart';
import 'constant.dart';
import '../models/playlist_item.dart';
import '../models/song_item.dart';

/// Service managing Library data: Playlists, Liked Songs, Cached Songs, Downloaded, and Local Files
class LibraryService extends GetxService {
  late Box _playlistBox;
  late Box _favBox;
  late Box _cacheBox;
  late Box _downloadsBox;
  late Box _prefsBox;
  late CacheService _cacheService;

  final RxList<PlaylistItem> playlists = <PlaylistItem>[].obs;
  final RxList<SongItem> likedSongs = <SongItem>[].obs;
  final RxList<SongItem> cachedSongs = <SongItem>[].obs;
  final RxList<SongItem> downloadedSongs = <SongItem>[].obs;
  final RxList<SongItem> localSongs = <SongItem>[].obs;
  final RxMap<String, List<SongItem>> localSongsByFolder = <String, List<SongItem>>{}.obs;
  final RxList<String> additionalFolders = <String>[].obs;
  final RxList<SongItem> allSongs = <SongItem>[].obs;

  Future<LibraryService> init() async {
    _playlistBox = Hive.isBoxOpen(Constant.boxLibraryPlaylists)
        ? Hive.box(Constant.boxLibraryPlaylists)
        : await Hive.openBox(Constant.boxLibraryPlaylists);

    _favBox = Hive.isBoxOpen(Constant.boxLibFav)
        ? Hive.box(Constant.boxLibFav)
        : await Hive.openBox(Constant.boxLibFav);

    _cacheBox = Hive.isBoxOpen(Constant.boxSongsCache)
        ? Hive.box(Constant.boxSongsCache)
        : await Hive.openBox(Constant.boxSongsCache);

    _downloadsBox = Hive.isBoxOpen(Constant.boxSongDownloads)
        ? Hive.box(Constant.boxSongDownloads)
        : await Hive.openBox(Constant.boxSongDownloads);

    _prefsBox = Hive.isBoxOpen(Constant.boxAppPrefs)
        ? Hive.box(Constant.boxAppPrefs)
        : await Hive.openBox(Constant.boxAppPrefs);

    _cacheService = Get.find<CacheService>();

    // Load saved additional local folders
    final savedFolders = _prefsBox.get('additionalLocalFolders');
    if (savedFolders is List) {
      additionalFolders.value = savedFolders.map((e) => e.toString()).toList();
    }

    // Live box watchers to keep reactive lists synchronized automatically
    _favBox.watch().listen((_) => loadLikedSongs());
    _cacheBox.watch().listen((_) => loadCachedSongs());
    _playlistBox.watch().listen((_) => loadPlaylists());
    _downloadsBox.watch().listen((_) => loadDownloadedSongs());

    await refreshAll();
    return this;
  }

  /// Reload all library sections from Hive and disk
  Future<void> refreshAll() async {
    final savedFolders = _prefsBox.get('additionalLocalFolders');
    if (savedFolders is List) {
      additionalFolders.value = savedFolders.map((e) => e.toString()).toList();
    } else {
      additionalFolders.clear();
    }

    await loadPlaylists();
    await loadLikedSongs();
    await loadCachedSongs();
    await loadDownloadedSongs();
    await loadLocalSongs();
    _updateAllSongs();
  }

  /// Load playlists from Hive
  Future<void> loadPlaylists() async {
    final list = <PlaylistItem>[];
    for (final key in _playlistBox.keys) {
      final val = _playlistBox.get(key);
      if (val is Map) {
        list.add(PlaylistItem.fromJson(val));
      }
    }
    playlists.value = list;
  }

  /// Load liked songs from LIBFAV
  Future<void> loadLikedSongs() async {
    final list = <SongItem>[];
    for (final key in _favBox.keys) {
      final val = _favBox.get(key);
      if (val is Map) {
        list.add(SongItem.fromJson(val).copyWith(isLiked: true));
      }
    }
    // Newest liked songs first
    likedSongs.value = list.reversed.toList();
    _updateAllSongs();
  }

  /// Load cached songs from CacheService
  Future<void> loadCachedSongs() async {
    cachedSongs.value = _cacheService.getCachedSongs();
    _updateAllSongs();
  }

  /// Load downloaded songs from SongDownloads Hive box
  Future<void> loadDownloadedSongs() async {
    final list = <SongItem>[];
    for (final key in _downloadsBox.keys) {
      final val = _downloadsBox.get(key);
      if (val is Map) {
        list.add(SongItem.fromJson(Map<String, dynamic>.from(val)).copyWith(isDownloaded: true));
      }
    }
    downloadedSongs.value = list;
    _updateAllSongs();
  }

  /// Grant access to an additional music directory
  Future<void> addAdditionalFolder(String folderPath) async {
    final trimmed = folderPath.trim();
    if (trimmed.isEmpty) return;
    if (!additionalFolders.contains(trimmed)) {
      additionalFolders.add(trimmed);
      await _prefsBox.put('additionalLocalFolders', additionalFolders.toList());
      await loadLocalSongs();
    }
  }

  /// Revoke access to an additional music directory
  Future<void> removeAdditionalFolder(String folderPath) async {
    additionalFolders.remove(folderPath);
    await _prefsBox.put('additionalLocalFolders', additionalFolders.toList());
    await loadLocalSongs();
  }

  /// Scan and load audio files from base directory and all granted additional directories recursively
  Future<void> loadLocalSongs() async {
    final list = <SongItem>[];
    final folderMap = <String, List<SongItem>>{};
    final seenPaths = <String>{};
    final supportedExts = {'.mp3', '.m4a', '.opus', '.wav', '.flac', '.ogg', '.aac', '.wma'};
    final cachePath = _cacheService.cacheDir.value;

    final dirsToScan = <Directory>[];

    // 1. Base storage directory
    final basePath = _cacheService.baseDir.value;
    if (basePath.isNotEmpty) {
      final baseDir = Directory(basePath);
      if (await baseDir.exists()) {
        dirsToScan.add(baseDir);
      }
    }

    // 2. Additional granted directories
    for (final extraPath in additionalFolders) {
      if (extraPath.isNotEmpty) {
        final extraDir = Directory(extraPath);
        if (await extraDir.exists()) {
          dirsToScan.add(extraDir);
        }
      }
    }

    for (final dir in dirsToScan) {
      try {
        final entities = dir.listSync(recursive: true, followLinks: false);
        for (final entity in entities) {
          if (entity is File) {
            final path = entity.path;
            // Skip internal streaming cache files
            if (cachePath.isNotEmpty && path.startsWith(cachePath)) {
              continue;
            }

            if (seenPaths.contains(path)) continue;

            final dotIdx = path.lastIndexOf('.');
            if (dotIdx == -1) continue;
            final ext = path.substring(dotIdx).toLowerCase();
            if (!supportedExts.contains(ext)) continue;

            final sep = Platform.pathSeparator;
            final fileName = path.contains(sep) ? path.substring(path.lastIndexOf(sep) + 1) : path;
            if (fileName.startsWith('.')) continue;

            final baseName = fileName.substring(0, fileName.lastIndexOf('.'));
            String artist = 'Local Audio';
            String title = baseName;

            if (baseName.contains(' - ')) {
              final parts = baseName.split(' - ');
              if (parts.length >= 2) {
                artist = parts[0].trim();
                title = parts.sublist(1).join(' - ').trim();
              }
            }

            // Group by parent folder name
            final parentDir = entity.parent;
            final folderName = parentDir.path.split(sep).last;
            final cleanFolderName = folderName.isNotEmpty ? folderName : 'Local Files';

            final song = SongItem(
              videoId: 'local_${path.hashCode.abs()}',
              title: title.isNotEmpty ? title : fileName,
              artist: artist.isNotEmpty ? artist : 'Local Audio',
              album: cleanFolderName,
              url: path,
              isDownloaded: true,
            );

            seenPaths.add(path);
            list.add(song);

            folderMap.putIfAbsent(cleanFolderName, () => []).add(song);
          }
        }
      } catch (e) {
        debugPrint('[LibraryService] Error scanning dir ${dir.path}: $e');
      }
    }

    // Apply custom order if saved
    final savedOrder = _prefsBox.get('localSongsOrder');
    if (savedOrder is List && savedOrder.isNotEmpty) {
      final orderMap = <String, int>{};
      for (int i = 0; i < savedOrder.length; i++) {
        orderMap[savedOrder[i].toString()] = i;
      }
      list.sort((a, b) {
        final aKey = a.url ?? a.videoId;
        final bKey = b.url ?? b.videoId;
        final aIndex = orderMap[aKey] ?? 999999;
        final bIndex = orderMap[bKey] ?? 999999;
        return aIndex.compareTo(bIndex);
      });
    }

    localSongs.value = list;
    localSongsByFolder.value = folderMap;
    _updateAllSongs();
  }

  /// Reorder local songs list and persist custom arrangement
  Future<void> reorderLocalSongs(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= localSongs.length) return;
    if (newIndex < 0 || newIndex > localSongs.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = localSongs.removeAt(oldIndex);
    localSongs.insert(newIndex, item);

    final orderList = localSongs.map((s) => s.url ?? s.videoId).toList();
    await _prefsBox.put('localSongsOrder', orderList);
    _updateAllSongs();
  }

  /// Sort local songs by title, artist, or folder
  Future<void> sortLocalSongs(String sortType) async {
    final list = List<SongItem>.from(localSongs);
    if (sortType == 'title') {
      list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (sortType == 'artist') {
      list.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
    } else if (sortType == 'folder') {
      list.sort((a, b) => (a.album ?? '').toLowerCase().compareTo((b.album ?? '').toLowerCase()));
    }
    localSongs.value = list;
    final orderList = localSongs.map((s) => s.url ?? s.videoId).toList();
    await _prefsBox.put('localSongsOrder', orderList);
    _updateAllSongs();
  }

  /// Rebuild combined de-duplicated all songs list
  void _updateAllSongs() {
    final map = <String, SongItem>{};
    for (final s in likedSongs) {
      map[s.videoId] = s;
    }
    for (final s in downloadedSongs) {
      map[s.videoId] = s;
    }
    for (final s in cachedSongs) {
      map[s.videoId] = s;
    }
    for (final s in localSongs) {
      map[s.videoId] = s;
    }
    allSongs.value = map.values.toList();
  }

  /// Create a new local playlist
  Future<PlaylistItem> createPlaylist(String title, {String? description}) async {
    final id = 'playlist_${DateTime.now().millisecondsSinceEpoch}';
    final playlist = PlaylistItem(
      id: id,
      title: title.trim().isEmpty ? 'My Playlist' : title.trim(),
      description: description,
      songCount: 0,
      songs: [],
      isCustom: true,
    );

    await _playlistBox.put(id, playlist.toJson());
    await loadPlaylists();
    return playlist;
  }

  /// Delete a playlist
  Future<void> deletePlaylist(String playlistId) async {
    await _playlistBox.delete(playlistId);
    await loadPlaylists();
  }

  /// Add a song to a playlist
  Future<void> addSongToPlaylist(String playlistId, SongItem song) async {
    final raw = _playlistBox.get(playlistId);
    if (raw is Map) {
      final current = PlaylistItem.fromJson(raw);
      // Avoid duplicate song entries
      if (current.songs.any((s) => s.videoId == song.videoId)) return;

      final updatedSongs = List<SongItem>.from(current.songs)..add(song);
      final updated = current.copyWith(
        songs: updatedSongs,
        songCount: updatedSongs.length,
        thumbnailUrl: current.thumbnailUrl ?? song.thumbnailUrl,
      );

      await _playlistBox.put(playlistId, updated.toJson());
      await loadPlaylists();
    }
  }

  /// Remove a song from a playlist
  Future<void> removeSongFromPlaylist(String playlistId, String videoId) async {
    final raw = _playlistBox.get(playlistId);
    if (raw is Map) {
      final current = PlaylistItem.fromJson(raw);
      final updatedSongs = current.songs.where((s) => s.videoId != videoId).toList();
      final updated = current.copyWith(
        songs: updatedSongs,
        songCount: updatedSongs.length,
      );

      await _playlistBox.put(playlistId, updated.toJson());
      await loadPlaylists();
    }
  }
}
