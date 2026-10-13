import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'cache_service.dart';
import 'constant.dart';
import 'download_service.dart';
import 'library_service.dart';
import 'player_controller.dart';

/// Controller for settings screen and user preferences
class SettingsController extends GetxController {
  late final Box _prefsBox;
  late final CacheService _cacheService;

  final RxInt streamingQuality = Constant.qualityHigh.obs;
  final RxBool skipSilence = false.obs;
  final RxBool loudnessNormalization = true.obs;
  final RxString currentAppLanguageCode = 'en'.obs;

  @override
  void onInit() {
    super.onInit();
    _prefsBox = Hive.box(Constant.boxAppPrefs);
    _cacheService = Get.find<CacheService>();

    streamingQuality.value =
        _prefsBox.get(Constant.prefStreamingQuality, defaultValue: Constant.qualityHigh) as int;
    skipSilence.value =
        _prefsBox.get(Constant.prefSkipSilenceEnabled, defaultValue: false) as bool;
    loudnessNormalization.value =
        _prefsBox.get(Constant.prefLoudnessNormalization, defaultValue: true) as bool;
    currentAppLanguageCode.value =
        _prefsBox.get(Constant.prefCurrentAppLanguageCode, defaultValue: 'en') as String;
  }

  // Directory getters from CacheService
  RxString get baseDir => _cacheService.baseDir;
  RxString get downloadsDir => _cacheService.downloadsDir;
  RxString get cacheDir => _cacheService.cacheDir;
  RxString get audioDir => _cacheService.downloadsDir;
  RxString get videoDir => _cacheService.downloadsDir;
  RxInt get cacheSizeLimit => _cacheService.cacheSizeLimit;
  RxBool get autoCacheEnabled => _cacheService.autoCacheEnabled;
  RxInt get cachedSongsCount => _cacheService.cachedSongsCount;
  RxString get cachedTotalSize => _cacheService.cachedTotalSize;

  /// Pick unified base storage directory
  Future<void> pickBaseDirectory() async {
    try {
      final selected = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Base Storage Directory',
      );
      if (selected != null && selected.isNotEmpty) {
        await _cacheService.setBaseDir(selected);
        if (Get.isRegistered<LibraryService>()) {
          await Get.find<LibraryService>().refreshAll();
        }
      }
    } catch (e) {
      debugPrint('[Settings] Base directory picker error: $e');
    }
  }

  // Backward compatibility pickers
  Future<void> pickAudioDirectory() async => pickBaseDirectory();
  Future<void> pickVideoDirectory() async => pickBaseDirectory();
  Future<void> pickCacheDirectory() async => pickBaseDirectory();

  /// Set cache limit (up to 350 default, or custom)
  Future<void> setCacheSizeLimit(int limit) async {
    await _cacheService.setCacheLimit(limit);
  }

  /// Toggle auto-caching of all played songs
  Future<void> toggleAutoCache(bool enabled) async {
    await _cacheService.toggleAutoCache(enabled);
  }

  /// Clear cache
  Future<void> clearCache() async {
    await _cacheService.clearCache();
    Get.snackbar(
      'Cache Cleared',
      'Local streaming cache has been wiped',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  /// Set streaming quality
  Future<void> setStreamingQuality(int quality) async {
    streamingQuality.value = quality;
    await _prefsBox.put(Constant.prefStreamingQuality, quality);
  }

  /// Toggle loudness normalization
  Future<void> toggleLoudness(bool enabled) async {
    loudnessNormalization.value = enabled;
    await _prefsBox.put(Constant.prefLoudnessNormalization, enabled);
  }

  /// Factory reset: Wipes all databases, caches, downloads, and restores pristine clean slate
  Future<void> resetEntireApp() async {
    try {
      // 1. Stop audio playback immediately
      if (Get.isRegistered<PlayerController>()) {
        try {
          await Get.find<PlayerController>().stop();
        } catch (_) {}
      }

      // 2. Clear all open Hive boxes
      final boxNames = [
        Constant.boxSongsCache,
        Constant.boxSongDownloads,
        Constant.boxSongsUrlCache,
        Constant.boxAppPrefs,
        Constant.boxLibraryPlaylists,
        Constant.boxLibFav,
        Constant.boxLibRP,
        Constant.boxHomeScreenData,
        Constant.boxPrevSessionData,
        Constant.boxSearchQuery,
      ];

      for (final name in boxNames) {
        if (Hive.isBoxOpen(name)) {
          try {
            await Hive.box(name).clear();
          } catch (_) {}
        }
      }

      // 3. Wipe all downloaded and cached media files from disk
      await _cacheService.wipeAllStorageFiles();

      // 4. Reset default base storage directory
      final defaultBase = await CacheService.resolveDefaultBaseDir();
      await _cacheService.setBaseDir(defaultBase);

      // 5. Reset download queue if registered
      if (Get.isRegistered<DownloadService>()) {
        Get.find<DownloadService>().clearAllTasks();
      }

      // 6. Refresh library and player state
      if (Get.isRegistered<PlayerController>()) {
        Get.find<PlayerController>().clearLikedState();
      }
      if (Get.isRegistered<LibraryService>()) {
        await Get.find<LibraryService>().refreshAll();
      }

      // 7. Reset settings observables to defaults
      streamingQuality.value = Constant.qualityHigh;
      skipSilence.value = false;
      loudnessNormalization.value = true;
      _cacheService.cacheSizeLimit.value = 350;
      _cacheService.autoCacheEnabled.value = true;

      _notify(
        'App Reset Complete',
        'Villupaatukaaran has been restored to factory defaults',
      );
    } catch (e) {
      debugPrint('[SettingsController] Reset app error: $e');
    }
  }

  void _notify(String title, String message) {
    if (Get.context != null) {
      try {
        Get.snackbar(
          title,
          message,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
      } catch (_) {}
    }
  }
}

