import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'cache_service.dart';
import 'constant.dart';
import '../models/playlist_item.dart';
import '../models/song_item.dart';

/// Service managing Library data: Playlists, Liked Songs, and Cached Songs
class LibraryService extends GetxService {
  late Box _playlistBox;
  late Box _favBox;
  late CacheService _cacheService;

  final RxList<PlaylistItem> playlists = <PlaylistItem>[].obs;
  final RxList<SongItem> likedSongs = <SongItem>[].obs;
  final RxList<SongItem> cachedSongs = <SongItem>[].obs;

  Future<LibraryService> init() async {
    _playlistBox = Hive.isBoxOpen(Constant.boxLibraryPlaylists)
        ? Hive.box(Constant.boxLibraryPlaylists)
        : await Hive.openBox(Constant.boxLibraryPlaylists);

    _favBox = Hive.isBoxOpen(Constant.boxLibFav)
        ? Hive.box(Constant.boxLibFav)
        : await Hive.openBox(Constant.boxLibFav);

    _cacheService = Get.find<CacheService>();

    await refreshAll();
    return this;
  }

  /// Reload all library sections from Hive and disk
  Future<void> refreshAll() async {
    await loadPlaylists();
    await loadLikedSongs();
    await loadCachedSongs();
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
  }

  /// Load cached songs from CacheService
  Future<void> loadCachedSongs() async {
    cachedSongs.value = _cacheService.getCachedSongs();
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
