import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'cache_service.dart';
import 'constant.dart';

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
  RxString get audioDir => _cacheService.audioDir;
  RxString get videoDir => _cacheService.videoDir;
  RxString get cacheDir => _cacheService.cacheDir;
  RxInt get cacheSizeLimit => _cacheService.cacheSizeLimit;
  RxBool get autoCacheEnabled => _cacheService.autoCacheEnabled;
  RxInt get cachedSongsCount => _cacheService.cachedSongsCount;
  RxString get cachedTotalSize => _cacheService.cachedTotalSize;

  /// Pick base audio directory using native folder picker
  Future<void> pickAudioDirectory() async {
    try {
      final selected = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Base Audio / Music Directory',
      );
      if (selected != null && selected.isNotEmpty) {
        await _cacheService.setAudioDir(selected);
      }
    } catch (e) {
      debugPrint('[Settings] Directory picker error: $e');
    }
  }

  /// Pick base video directory
  Future<void> pickVideoDirectory() async {
    try {
      final selected = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Base Video Directory',
      );
      if (selected != null && selected.isNotEmpty) {
        await _cacheService.setVideoDir(selected);
      }
    } catch (e) {
      debugPrint('[Settings] Directory picker error: $e');
    }
  }

  /// Pick cache directory
  Future<void> pickCacheDirectory() async {
    try {
      final selected = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Cache Directory',
      );
      if (selected != null && selected.isNotEmpty) {
        await _cacheService.setCacheDir(selected);
      }
    } catch (e) {
      debugPrint('[Settings] Directory picker error: $e');
    }
  }

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
}
