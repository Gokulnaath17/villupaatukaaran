import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'constant.dart';
import 'music_service.dart';
import '../models/song_item.dart';

/// Controller for Discover page content and top search
class DiscoverController extends GetxController {
  late final MusicService _musicService;
  late final Box _homeCacheBox;

  final TextEditingController searchInputController = TextEditingController();

  final RxBool isLoading = true.obs;
  final RxBool isSearching = false.obs;
  final RxString activeQuery = ''.obs;

  final RxList<SongItem> topSongs = <SongItem>[].obs;
  final RxList<SongItem> quickPicks = <SongItem>[].obs;
  final RxList<Map<String, dynamic>> featuredPlaylists = <Map<String, dynamic>>[].obs;

  final RxList<String> suggestions = <String>[].obs;
  final RxList<SongItem> searchResults = <SongItem>[].obs;

  Timer? _debounceTimer;

  @override
  void onInit() {
    super.onInit();
    _initDiscover();
  }

  Future<void> _initDiscover() async {
    _musicService = Get.find<MusicService>();
    _homeCacheBox = Hive.isBoxOpen(Constant.boxHomeScreenData)
        ? Hive.box(Constant.boxHomeScreenData)
        : await Hive.openBox(Constant.boxHomeScreenData);

    await loadHomeFeed();
  }

  /// Load home feed from Innertube with fallback to cache
  Future<void> loadHomeFeed({bool forceRefresh = false}) async {
    isLoading.value = true;
    try {
      final homeData = await _musicService.getHome();

      final qp = homeData['quickPicks'] as List? ?? [];
      final mid = homeData['middle'] as List? ?? [];
      final fixed = homeData['fixed'] as List? ?? [];

      final allParsed = <SongItem>[];
      for (final item in [...qp, ...mid, ...fixed]) {
        if (item is Map<String, dynamic>) {
          final s = SongItem.fromInnertube(item);
          if (s.videoId.isNotEmpty) {
            allParsed.add(s);
          }
        }
      }

      if (allParsed.length >= 6) {
        topSongs.value = allParsed.take(15).toList();
        quickPicks.value = allParsed.skip(15).take(15).toList();
        await _homeCacheBox.put('cachedFeed', allParsed.map((s) => s.toJson()).toList());
      } else {
        await _loadFallbackOrYtDlp();
      }
    } catch (e) {
      debugPrint('[DiscoverController] Feed load error: $e. Using fallback.');
      await _loadFallbackOrYtDlp();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadFallbackOrYtDlp() async {
    final cached = _homeCacheBox.get('cachedFeed');
    if (cached is List && cached.isNotEmpty) {
      final cachedSongs = cached
          .map((e) => SongItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((s) => s.videoId.isNotEmpty)
          .toList();
      if (cachedSongs.isNotEmpty) {
        topSongs.value = cachedSongs.take(15).toList();
        quickPicks.value = cachedSongs.skip(15).take(15).toList();
        return;
      }
    }

    // Fetch dynamic top tracks via yt-dlp
    try {
      final ytItems = await _musicService.searchWithYtDlp('top tamil songs');
      if (ytItems.isNotEmpty) {
        final songs = ytItems.map((m) => SongItem.fromInnertube(m)).toList();
        topSongs.value = songs.take(12).toList();
        quickPicks.value = songs.skip(12).take(12).toList();
        await _homeCacheBox.put('cachedFeed', songs.map((s) => s.toJson()).toList());
        return;
      }
    } catch (e) {
      debugPrint('[DiscoverController] yt-dlp initial feed error: $e');
    }

    _loadFallbackTracks();
  }

  /// Fallback curated folk / Tamil tracks if network is uninitialized
  void _loadFallbackTracks() {
    final fallbacks = [
      const SongItem(
        videoId: 'kJQP7kiw5Fk',
        title: 'Kalaivaniyo Raniyo (Villupaatukaran)',
        artist: 'S.P. Balasubrahmanyam, Ilaiyaraaja',
        duration: '4:42',
        durationSeconds: 282,
        thumbnailUrl: 'https://i.ytimg.com/vi/kJQP7kiw5Fk/hqdefault.jpg',
      ),
      const SongItem(
        videoId: 'fJ9rUzIMcZQ',
        title: 'Solai Malai Ooram (Villupaatukaran)',
        artist: 'S.P. Balasubrahmanyam, S. Janaki, Ilaiyaraaja',
        duration: '4:55',
        durationSeconds: 295,
        thumbnailUrl: 'https://i.ytimg.com/vi/fJ9rUzIMcZQ/hqdefault.jpg',
      ),
      const SongItem(
        videoId: 'L_LUpnjgPso',
        title: 'Ponnil Vaanam (Villupaatukaran)',
        artist: 'S. Janaki, Ilaiyaraaja',
        duration: '4:30',
        durationSeconds: 270,
        thumbnailUrl: 'https://i.ytimg.com/vi/L_LUpnjgPso/hqdefault.jpg',
      ),
      const SongItem(
        videoId: '2Vv-BfVoq4g',
        title: 'Thandhen Thandhen (Villupaatukaran)',
        artist: 'Malaysia Vasudevan, Ilaiyaraaja',
        duration: '5:10',
        durationSeconds: 310,
        thumbnailUrl: 'https://i.ytimg.com/vi/2Vv-BfVoq4g/hqdefault.jpg',
      ),
      const SongItem(
        videoId: '9bZkp7q19f0',
        title: 'Thanthanathom Enru Solliye (Folk)',
        artist: 'Traditional Folk, Gangai Amaran',
        duration: '3:50',
        durationSeconds: 230,
        thumbnailUrl: 'https://i.ytimg.com/vi/9bZkp7q19f0/hqdefault.jpg',
      ),
    ];

    topSongs.value = fallbacks;
    quickPicks.value = fallbacks.reversed.toList();
  }

  /// On search query typed (debounced suggestions)
  void onSearchChanged(String query) {
    activeQuery.value = query;
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      isSearching.value = false;
      suggestions.clear();
      searchResults.clear();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final sug = await _musicService.getSearchSuggestion(query.trim());
      suggestions.value = sug;
    });
  }

  /// Execute search query
  Future<void> search(String query) => performSearch(query);

  /// Execute search query
  Future<void> performSearch(String query) async {
    if (query.trim().isEmpty) return;

    activeQuery.value = query.trim();
    isSearching.value = true;
    isLoading.value = true;
    suggestions.clear();

    try {
      final data = await _musicService.search(query: query.trim());
      final rawResults = data['results'] as List? ?? [];
      final parsed = <SongItem>[];

      for (final r in rawResults) {
        if (r is Map<String, dynamic>) {
          final s = SongItem.fromInnertube(r);
          if (s.videoId.isNotEmpty) {
            parsed.add(s);
          }
        }
      }

      if (parsed.isEmpty) {
        final ytItems = await _musicService.searchWithYtDlp(query.trim());
        for (final r in ytItems) {
          final s = SongItem.fromInnertube(r);
          if (s.videoId.isNotEmpty) {
            parsed.add(s);
          }
        }
      }

      searchResults.value = parsed;
    } catch (e) {
      debugPrint('[DiscoverController] Search execution error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Clear active search
  void clearSearch() {
    searchInputController.clear();
    activeQuery.value = '';
    isSearching.value = false;
    suggestions.clear();
    searchResults.clear();
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    searchInputController.dispose();
    super.onClose();
  }
}
