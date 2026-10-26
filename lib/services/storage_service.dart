import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'cache_service.dart';
import 'constant.dart';
import 'library_service.dart';

/// StorageService unifies all application storage into a single dedicated folder:
/// - <baseDir>/data/       -> Hive database boxes (*.hive, *.lock), configs, and metadata
/// - <baseDir>/downloads/  -> Downloaded offline audio tracks
/// - <baseDir>/cache/      -> Streaming replay cache
/// - <baseDir>/            -> Local audio files and music root
///
/// Prevents cluttering the user's ~/Documents folder and provides seamless folder setup & migration.
class StorageService extends GetxService {
  final RxString baseDir = ''.obs;
  final RxString dataDir = ''.obs;
  final RxString downloadsDir = ''.obs;
  final RxString cacheDir = ''.obs;
  final RxBool isInitialSetupCompleted = false.obs;

  String? _customConfigPath;

  /// Path to standard Linux desktop configuration pointer: ~/.config/villupaatukaaran/config.json
  String get configFilePath {
    if (_customConfigPath != null && _customConfigPath!.isNotEmpty) {
      return _customConfigPath!;
    }
    final xdgConfig = Platform.environment['XDG_CONFIG_HOME'];
    if (xdgConfig != null && xdgConfig.isNotEmpty) {
      return '$xdgConfig/villupaatukaaran/config.json';
    }
    final home = Platform.environment['HOME'] ?? '';
    return '$home/.config/villupaatukaaran/config.json';
  }

  /// Resolve default storage directory
  static Future<String> resolveDefaultBaseDir() async {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      final music = Directory('$home/Music');
      if (await music.exists()) {
        return '$home/Music/${Constant.baseDirName}';
      }
      return '$home/${Constant.baseDirName}';
    }
    return '/tmp/${Constant.baseDirName}';
  }

  /// Initialize StorageService before Hive initializes
  Future<StorageService> init({String? customBaseDir, String? customConfigPath}) async {
    _customConfigPath = customConfigPath;

    // 1. Determine base directory
    String resolvedBase = customBaseDir ?? '';
    if (resolvedBase.isEmpty) {
      resolvedBase = await _readSavedBaseDir();
    }
    if (resolvedBase.isEmpty) {
      resolvedBase = await resolveDefaultBaseDir();
    }

    // 2. Set directory paths
    baseDir.value = resolvedBase;
    dataDir.value = '$resolvedBase/${Constant.dataDirName}';
    downloadsDir.value = '$resolvedBase/${Constant.downloadDirName}';
    cacheDir.value = '$resolvedBase/${Constant.tempCacheDirName}';

    // 3. Ensure subdirectories exist
    await Directory(dataDir.value).create(recursive: true);
    await Directory(downloadsDir.value).create(recursive: true);
    await Directory(cacheDir.value).create(recursive: true);

    // 4. Migrate stray files from ~/Documents if present (only when not in custom test mode)
    if (customBaseDir == null) {
      await migrateFromDocumentsIfNeeded(dataDir.value);
    }

    // 5. Read initial setup completed status
    isInitialSetupCompleted.value = await _readInitialSetupStatus();

    // 6. Persist config pointer
    await _saveConfigFile();

    return this;
  }

  /// Open all core eager startup Hive storage boxes
  static Future<void> openBoxes() async {
    await Hive.openBox(Constant.boxSongsCache);
    await Hive.openBox(Constant.boxSongDownloads);
    await Hive.openBox(Constant.boxSongsUrlCache);
    await Hive.openBox(Constant.boxAppPrefs);
    await Hive.openBox(Constant.boxLibraryPlaylists);
    await Hive.openBox(Constant.boxLibFav);
    await Hive.openBox(Constant.boxLibRP);
    await Hive.openBox(Constant.boxHomeScreenData);
    await Hive.openBox(Constant.boxPrevSessionData);
  }

  /// Migrate stray Hive, JSON, and SQLite files from ~/Documents to targetDataDir
  Future<void> migrateFromDocumentsIfNeeded(String targetDataDir) async {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return;

    final documentsDir = Directory('$home/Documents');
    if (!await documentsDir.exists()) return;

    final filesToMigrate = [
      'appprefs.hive',
      'appprefs.lock',
      'AppPrefs.hive',
      'AppPrefs.lock',
      'homescreendata.hive',
      'homescreendata.lock',
      'homeScreenData.hive',
      'homeScreenData.lock',
      'libfav.hive',
      'libfav.lock',
      'LIBFAV.hive',
      'LIBFAV.lock',
      'libraryplaylists.hive',
      'libraryplaylists.lock',
      'LibraryPlaylists.hive',
      'LibraryPlaylists.lock',
      'librp.hive',
      'librp.lock',
      'LIBRP.hive',
      'LIBRP.lock',
      'prevsessiondata.hive',
      'prevsessiondata.lock',
      'prevSessionData.hive',
      'prevSessionData.lock',
      'songdownloads.hive',
      'songdownloads.lock',
      'SongDownloads.hive',
      'SongDownloads.lock',
      'songscache.hive',
      'songscache.lock',
      'SongsCache.hive',
      'SongsCache.lock',
      'songsurlcache.hive',
      'songsurlcache.lock',
      'SongsUrlCache.hive',
      'SongsUrlCache.lock',
      'searchquery.hive',
      'searchquery.lock',
      'searchQuery.hive',
      'searchQuery.lock',
      'paatu_folder_config.json',
      'villu_paatukaran.sqlite',
      'villu_paatukaran.sqlite-journal',
    ];

    for (final filename in filesToMigrate) {
      final docFile = File('${documentsDir.path}/$filename');
      if (await docFile.exists()) {
        final targetFile = File('$targetDataDir/$filename');
        try {
          if (!await targetFile.exists()) {
            await docFile.copy(targetFile.path);
          }
          await docFile.delete();
          debugPrint('[StorageService] Migrated $filename from Documents to $targetDataDir');
        } catch (e) {
          debugPrint('[StorageService] Error migrating $filename: $e');
        }
      }
    }
  }

  /// Read saved base directory from config file or legacy config
  Future<String> _readSavedBaseDir() async {
    try {
      final configFile = File(configFilePath);
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        final json = jsonDecode(content);
        if (json is Map && json['baseDir'] != null) {
          final p = json['baseDir'].toString().trim();
          if (p.isNotEmpty) return p;
        }
      }
    } catch (_) {}

    // Fallback: check legacy ~/Documents/paatu_folder_config.json if present
    try {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        final oldConfig = File('$home/Documents/paatu_folder_config.json');
        if (await oldConfig.exists()) {
          final content = await oldConfig.readAsString();
          final json = jsonDecode(content);
          if (json is Map && json['rootPath'] != null) {
            final p = json['rootPath'].toString().trim();
            if (p.isNotEmpty) return p;
          }
        }
      }
    } catch (_) {}

    return '';
  }

  /// Read initial setup completed status
  Future<bool> _readInitialSetupStatus() async {
    try {
      final configFile = File(configFilePath);
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        final json = jsonDecode(content);
        if (json is Map && json['initialSetupDone'] == true) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Save current configuration pointer to disk
  Future<void> _saveConfigFile() async {
    try {
      final file = File(configFilePath);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      final data = {
        'baseDir': baseDir.value,
        'initialSetupDone': isInitialSetupCompleted.value,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    } catch (e) {
      debugPrint('[StorageService] Error saving config file: $e');
    }
  }

  /// Complete initial setup flow and persist folder preference
  Future<void> completeInitialSetup(String chosenPath) async {
    final cleanPath = chosenPath.trim();
    if (cleanPath.isNotEmpty && cleanPath != baseDir.value) {
      await changeBaseDirectory(cleanPath);
    }
    isInitialSetupCompleted.value = true;
    await _saveConfigFile();

    if (Hive.isBoxOpen(Constant.boxAppPrefs)) {
      await Hive.box(Constant.boxAppPrefs).put(Constant.prefInitialSetupDone, true);
    }
  }

  /// Change base directory and cleanly transfer all data, downloads, and cache
  Future<void> changeBaseDirectory(String newPath) async {
    final cleanPath = newPath.trim();
    if (cleanPath.isEmpty || cleanPath == baseDir.value) return;

    final oldDataDir = dataDir.value;
    final oldDownloadsDir = downloadsDir.value;
    final oldCacheDir = cacheDir.value;

    final newDataDir = '$cleanPath/${Constant.dataDirName}';
    final newDownloadsDir = '$cleanPath/${Constant.downloadDirName}';
    final newCacheDir = '$cleanPath/${Constant.tempCacheDirName}';

    await Directory(newDataDir).create(recursive: true);
    await Directory(newDownloadsDir).create(recursive: true);
    await Directory(newCacheDir).create(recursive: true);

    // 1. Close open Hive boxes cleanly
    try {
      await Hive.close();
    } catch (e) {
      debugPrint('[StorageService] Error closing Hive before migration: $e');
    }

    // 2. Transfer all database files from old data/ to new data/
    final oldData = Directory(oldDataDir);
    if (await oldData.exists()) {
      try {
        await for (final entity in oldData.list()) {
          if (entity is File) {
            final fileName = entity.uri.pathSegments.last;
            final target = File('$newDataDir/$fileName');
            if (!await target.exists()) {
              await entity.copy(target.path);
            }
          }
        }
      } catch (e) {
        debugPrint('[StorageService] Error copying data files: $e');
      }
    }

    // Transfer downloaded songs if present
    final oldDl = Directory(oldDownloadsDir);
    if (await oldDl.exists()) {
      try {
        await for (final entity in oldDl.list()) {
          if (entity is File) {
            final fileName = entity.uri.pathSegments.last;
            final target = File('$newDownloadsDir/$fileName');
            if (!await target.exists()) {
              await entity.copy(target.path);
            }
          }
        }
      } catch (e) {
        debugPrint('[StorageService] Error copying downloads: $e');
      }
    }

    // Transfer cache files if present
    final oldCache = Directory(oldCacheDir);
    if (await oldCache.exists()) {
      try {
        await for (final entity in oldCache.list()) {
          if (entity is File) {
            final fileName = entity.uri.pathSegments.last;
            final target = File('$newCacheDir/$fileName');
            if (!await target.exists()) {
              await entity.copy(target.path);
            }
          }
        }
      } catch (e) {
        debugPrint('[StorageService] Error copying cache: $e');
      }
    }

    // 3. Re-initialize Hive at new data location and reopen boxes
    Hive.init(newDataDir);
    await openBoxes();

    // 4. Update reactive observables
    baseDir.value = cleanPath;
    dataDir.value = newDataDir;
    downloadsDir.value = newDownloadsDir;
    cacheDir.value = newCacheDir;

    // 5. Update pointer config and AppPrefs
    await _saveConfigFile();
    if (Hive.isBoxOpen(Constant.boxAppPrefs)) {
      await Hive.box(Constant.boxAppPrefs).put(Constant.prefBaseStorageDir, cleanPath);
    }

    // 6. Notify CacheService and LibraryService
    if (Get.isRegistered<CacheService>()) {
      await Get.find<CacheService>().setBaseDir(cleanPath);
    }
    if (Get.isRegistered<LibraryService>()) {
      await Get.find<LibraryService>().refreshAll();
    }
  }
}
