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
  late CacheService _cacheService;

  final RxList<PlaylistItem> playlists = <PlaylistItem>[].obs;
  final RxList<SongItem> likedSongs = <SongItem>[].obs;
  final RxList<SongItem> cachedSongs = <SongItem>[].obs;
  final RxList<SongItem> downloadedSongs = <SongItem>[].obs;
  final RxList<SongItem> localSongs = <SongItem>[].obs;
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

    _cacheService = Get.find<CacheService>();

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

  /// Scan and load audio files from local music directory
  Future<void> loadLocalSongs() async {
    final list = <SongItem>[];
    try {
      final musicPath = _cacheService.audioDir.value;
      if (musicPath.isNotEmpty) {
        final dir = Directory(musicPath);
        if (await dir.exists()) {
          final supportedExts = ['.mp3', '.m4a', '.opus', '.wav', '.flac', '.ogg'];
          final entities = dir.listSync(recursive: false);
          for (final entity in entities) {
            if (entity is File) {
              final path = entity.path;
              final dotIdx = path.lastIndexOf('.');
              if (dotIdx != -1) {
                final ext = path.substring(dotIdx).toLowerCase();
                if (supportedExts.contains(ext)) {
                  final sep = Platform.pathSeparator;
                  final fileName = path.contains(sep) ? path.substring(path.lastIndexOf(sep) + 1) : path;
                  final title = fileName.substring(0, fileName.lastIndexOf('.'));
                  list.add(SongItem(
                    videoId: 'local_${path.hashCode.abs()}',
                    title: title,
                    artist: 'Local Audio',
                    album: 'Device Music',
                    url: path,
                    isDownloaded: true,
                  ));
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[LibraryService] Error scanning local songs: $e');
    }
    localSongs.value = list;
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
