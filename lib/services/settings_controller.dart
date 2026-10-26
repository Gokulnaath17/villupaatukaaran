import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'backup_service.dart';
import 'cache_service.dart';
import 'constant.dart';
import 'download_service.dart';
import 'library_service.dart';
import 'player_controller.dart';
import 'storage_service.dart';
import '../ui/theme/theme_controller.dart';
import '../ui/widgets/boxy_card.dart';

/// Controller for settings screen and user preferences
class SettingsController extends GetxController {
  late Box _prefsBox;
  late CacheService _cacheService;

  final RxInt streamingQuality = Constant.qualityHigh.obs;
  final RxBool skipSilence = false.obs;
  final RxBool loudnessNormalization = true.obs;
  final RxString currentAppLanguageCode = 'en'.obs;
  final RxString closeAction = Constant.closeActionAsk.obs;

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
    closeAction.value =
        _prefsBox.get(Constant.prefCloseAction, defaultValue: Constant.closeActionAsk) as String;
  }

  /// Update window close action preference
  Future<void> setCloseAction(String action) async {
    closeAction.value = action;
    await _prefsBox.put(Constant.prefCloseAction, action);
  }

  // Directory getters from CacheService & StorageService
  RxString get baseDir => _cacheService.baseDir;
  RxString get dataDir => Get.isRegistered<StorageService>() ? Get.find<StorageService>().dataDir : ''.obs;
  RxString get downloadsDir => _cacheService.downloadsDir;
  RxString get cacheDir => _cacheService.cacheDir;
  RxString get audioDir => _cacheService.downloadsDir;
  RxString get videoDir => _cacheService.downloadsDir;
  RxInt get cacheSizeLimit => _cacheService.cacheSizeLimit;
  RxBool get autoCacheEnabled => _cacheService.autoCacheEnabled;
  RxInt get cachedSongsCount => _cacheService.cachedSongsCount;
  RxString get cachedTotalSize => _cacheService.cachedTotalSize;

  /// Pick unified base storage directory and migrate all files
  Future<void> pickBaseDirectory() async {
    try {
      final selected = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Unified Storage Vault Folder',
      );
      if (selected != null && selected.isNotEmpty) {
        if (Get.isRegistered<StorageService>()) {
          await Get.find<StorageService>().changeBaseDirectory(selected);
        } else {
          await _cacheService.setBaseDir(selected);
        }
        if (Get.isRegistered<LibraryService>()) {
          await Get.find<LibraryService>().refreshAll();
        }
        _notify(
          'Storage Vault Updated',
          'All databases and music files moved to $selected',
        );
      }
    } catch (e) {
      debugPrint('[Settings] Base directory picker error: $e');
    }
  }

  /// Export library, playlists, downloads, and cache metadata to a single file
  Future<void> exportBackup() async {
    if (!Get.isRegistered<BackupService>()) return;
    final backupService = Get.find<BackupService>();
    final result = await backupService.exportBackup();
    if (result.success) {
      _notify(
        'Backup Exported',
        'Exported ${result.likedCount} liked, ${result.playlistsCount} playlists, ${result.downloadedCount} downloads, and ${result.cachedCount} cached songs.',
      );
    } else if (result.message != 'Export cancelled') {
      _notify(
        'Backup Export Failed',
        result.message,
      );
    }
  }

  /// Import backup file with a preview confirmation dialog
  Future<void> importBackup(BuildContext context) async {
    if (!Get.isRegistered<BackupService>()) return;
    final backupService = Get.find<BackupService>();

    // 1. Pick file
    final fileResult = await FilePicker.pickFiles(
      dialogTitle: 'Select Villupaatukaaran Backup File',
      type: FileType.custom,
      allowedExtensions: ['json', 'vpb'],
    );
    if (fileResult == null || fileResult.files.isEmpty) return;
    final filePath = fileResult.files.first.path;
    if (filePath == null) return;

    // 2. Inspect file for preview
    final preview = await backupService.inspectBackupFile(filePath);
    if (preview == null) {
      _notify('Invalid Backup', 'The selected file could not be parsed as JSON.');
      return;
    }

    final data = preview['data'] is Map ? preview['data'] as Map : preview;
    final likedCount = (data['likedSongs'] as List?)?.length ?? 0;
    final playlistsCount = (data['playlists'] as List?)?.length ?? 0;
    final downloadedCount = (data['downloadedSongs'] as List?)?.length ?? 0;
    final cachedCount = (data['cachedSongs'] as List?)?.length ?? 0;

    // 3. Show confirmation dialog
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppTheme.windowBg,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.radiusLarge,
            side: const BorderSide(color: AppTheme.borderSubtle, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.settings_backup_restore_rounded, color: AppTheme.redAccent, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'RESTORE BACKUP?',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Found the following contents in this backup:',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardSurface,
                  borderRadius: AppTheme.radiusMedium,
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  children: [
                    _buildPreviewRow(Icons.favorite_rounded, '$likedCount Liked Songs', AppTheme.redAccent),
                    const SizedBox(height: 6),
                    _buildPreviewRow(Icons.queue_music_rounded, '$playlistsCount Custom Playlists', AppTheme.albumYellow),
                    const SizedBox(height: 6),
                    _buildPreviewRow(Icons.download_rounded, '$downloadedCount Offline Downloads (will be downloaded)', AppTheme.albumCyan),
                    const SizedBox(height: 6),
                    _buildPreviewRow(Icons.speed_rounded, '$cachedCount Cached Streaming Songs (will be cached)', AppTheme.albumLavender),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Playlists and liked tracks will restore immediately. Downloaded and cached songs will be queued to download and cache into your storage vault.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.3),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('CANCEL', style: TextStyle(color: AppTheme.textMuted)),
            ),
            BoxyButton(
              label: 'RESTORE & DOWNLOAD',
              icon: Icons.restore_rounded,
              isPrimary: true,
              onPressed: () => Navigator.of(dialogCtx).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // 4. Perform import
    final result = await backupService.importBackup(sourceFilePath: filePath);
    if (result.success) {
      _notify(
        'Backup Restored',
        'Restored ${result.likedCount} liked, ${result.playlistsCount} playlists. Queued ${result.downloadedCount} downloads and ${result.cachedCount} caches.',
      );
    } else {
      _notify(
        'Restore Failed',
        result.message,
      );
    }
  }

  Widget _buildPreviewRow(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textWhite, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
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
      closeAction.value = Constant.closeActionAsk;

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

