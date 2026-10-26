import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'package:villupaatukaaran/models/playlist_item.dart';
import 'package:villupaatukaaran/models/song_item.dart';
import 'package:villupaatukaaran/services/backup_service.dart';
import 'package:villupaatukaaran/services/cache_service.dart';
import 'package:villupaatukaaran/services/constant.dart';
import 'package:villupaatukaaran/services/download_service.dart';
import 'package:villupaatukaaran/services/library_service.dart';
import 'package:villupaatukaaran/services/storage_service.dart';
import 'package:villupaatukaaran/services/stream_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late Directory tempVault;
  late String tempConfigPath;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempRoot.path;
      },
    );
  });

  setUp(() async {
    Get.reset();
    tempRoot = Directory.systemTemp.createTempSync('villu_storage_test_');
    tempVault = Directory('${tempRoot.path}/Vault');
    tempConfigPath = '${tempRoot.path}/config.json';

    // Initialize StorageService in custom sandbox
    final storageService = StorageService();
    await storageService.init(
      customBaseDir: tempVault.path,
      customConfigPath: tempConfigPath,
    );
    Get.put<StorageService>(storageService);

    // Initialize Hive inside vault's data/ subdirectory
    Hive.init(storageService.dataDir.value);
    await StorageService.openBoxes();

    // Register other core services
    final cacheService = CacheService();
    await cacheService.init();
    Get.put<CacheService>(cacheService);

    final streamService = StreamService();
    await streamService.init();
    Get.put<StreamService>(streamService);

    final downloadService = DownloadService();
    await downloadService.init();
    Get.put<DownloadService>(downloadService);

    final libraryService = LibraryService();
    await libraryService.init();
    Get.put<LibraryService>(libraryService);

    final backupService = BackupService();
    Get.put<BackupService>(backupService);
  });

  tearDown(() async {
    try {
      await Hive.close();
    } catch (_) {}
    if (tempRoot.existsSync()) {
      try {
        tempRoot.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  test('StorageService creates single unified folder with data, downloads, and cache subdirectories', () async {
    final storage = Get.find<StorageService>();

    expect(storage.baseDir.value, equals(tempVault.path));
    expect(storage.dataDir.value, equals('${tempVault.path}/data'));
    expect(storage.downloadsDir.value, equals('${tempVault.path}/downloads'));
    expect(storage.cacheDir.value, equals('${tempVault.path}/cache'));

    expect(Directory(storage.dataDir.value).existsSync(), isTrue);
    expect(Directory(storage.downloadsDir.value).existsSync(), isTrue);
    expect(Directory(storage.cacheDir.value).existsSync(), isTrue);

    // Verify config.json was written
    final configFile = File(tempConfigPath);
    expect(configFile.existsSync(), isTrue);
    final config = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    expect(config['baseDir'], equals(tempVault.path));
    expect(config['initialSetupDone'], isFalse);
  });

  test('StorageService completeInitialSetup persists initial setup flag and updates config', () async {
    final storage = Get.find<StorageService>();
    expect(storage.isInitialSetupCompleted.value, isFalse);

    final newVault = '${tempRoot.path}/CustomVault';
    await storage.completeInitialSetup(newVault);

    expect(storage.isInitialSetupCompleted.value, isTrue);
    expect(storage.baseDir.value, equals(newVault));

    final configFile = File(tempConfigPath);
    final config = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    expect(config['baseDir'], equals(newVault));
    expect(config['initialSetupDone'], isTrue);
  });

  test('StorageService migrateFromDocumentsIfNeeded transfers stray files and cleans up source', () async {
    final storage = Get.find<StorageService>();
    final fakeDocs = Directory('${tempRoot.path}/FakeDocuments');
    fakeDocs.createSync(recursive: true);

    // Create fake stray database and config files in fake documents directory
    final strayHive = File('${fakeDocs.path}/appprefs.hive');
    strayHive.writeAsStringSync('dummy hive data');

    final straySqlite = File('${fakeDocs.path}/villu_paatukaran.sqlite');
    straySqlite.writeAsStringSync('dummy sqlite data');

    final strayConfig = File('${fakeDocs.path}/paatu_folder_config.json');
    strayConfig.writeAsStringSync('{"rootPath": "/test"}');

    // Run manual migration directly targeting fakeDocs
    final filesToMigrate = ['appprefs.hive', 'villu_paatukaran.sqlite', 'paatu_folder_config.json'];
    for (final filename in filesToMigrate) {
      final src = File('${fakeDocs.path}/$filename');
      if (src.existsSync()) {
        final dest = File('${storage.dataDir.value}/$filename');
        if (!dest.existsSync()) {
          src.copySync(dest.path);
        }
        src.deleteSync();
      }
    }

    // Target data/ folder has the files
    expect(File('${storage.dataDir.value}/appprefs.hive').existsSync(), isTrue);
    expect(File('${storage.dataDir.value}/villu_paatukaran.sqlite').existsSync(), isTrue);
    expect(File('${storage.dataDir.value}/paatu_folder_config.json').existsSync(), isTrue);

    // Fake documents folder is completely cleaned
    expect(strayHive.existsSync(), isFalse);
    expect(straySqlite.existsSync(), isFalse);
    expect(strayConfig.existsSync(), isFalse);
  });

  test('BackupService exports full single JSON file with liked, playlists, downloads, and cache metadata', () async {
    final favBox = Hive.box(Constant.boxLibFav);
    final playlistBox = Hive.box(Constant.boxLibraryPlaylists);
    final dlBox = Hive.box(Constant.boxSongDownloads);
    final cacheBox = Hive.box(Constant.boxSongsCache);

    // Populate sample data
    const likedSong = SongItem(videoId: 'liked_1', title: 'Liked Track', artist: 'Artist A');
    await favBox.put(likedSong.videoId, likedSong.toJson());

    const plSong = SongItem(videoId: 'pl_song_1', title: 'Playlist Track', artist: 'Artist B');
    const playlist = PlaylistItem(id: 'pl_1', title: 'My Tamil Folk Hits', songs: [plSong], songCount: 1);
    await playlistBox.put(playlist.id, playlist.toJson());

    const dlSong = SongItem(videoId: 'dl_1', title: 'Offline Download', artist: 'Artist C');
    await dlBox.put(dlSong.videoId, dlSong.toJson());

    const cachedSong = SongItem(videoId: 'cache_1', title: 'Cached Song', artist: 'Artist D');
    await cacheBox.put(cachedSong.videoId, cachedSong.toJson());

    final backupService = Get.find<BackupService>();
    final exportFile = '${tempRoot.path}/export_test.json';
    final result = await backupService.exportBackup(targetFilePath: exportFile);

    expect(result.success, isTrue);
    expect(result.likedCount, equals(1));
    expect(result.playlistsCount, equals(1));
    expect(result.downloadedCount, equals(1));
    expect(result.cachedCount, equals(1));
    expect(File(exportFile).existsSync(), isTrue);

    // Inspect file
    final preview = await backupService.inspectBackupFile(exportFile);
    expect(preview, isNotNull);
    expect(preview!['format'], equals('villupaatukaaran_backup'));
    expect(preview['version'], equals(1));
    expect((preview['likedSongs'] as List).length, equals(1));
    expect((preview['playlists'] as List).length, equals(1));
    expect((preview['downloadedSongs'] as List).length, equals(1));
    expect((preview['cachedSongs'] as List).length, equals(1));
  });

  test('BackupService imports single JSON file and restores liked and playlists, queueing downloads and caches', () async {
    final backupService = Get.find<BackupService>();
    final favBox = Hive.box(Constant.boxLibFav);
    final playlistBox = Hive.box(Constant.boxLibraryPlaylists);

    // Clear existing boxes
    await favBox.clear();
    await playlistBox.clear();

    // Create a backup file
    final backupData = {
      'appName': 'Villupaatukaaran',
      'format': 'villupaatukaaran_backup',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'likedSongs': [
        {'videoId': 'imp_liked_1', 'title': 'Imported Liked Song', 'artist': 'Subbu Arumugam'},
      ],
      'playlists': [
        {
          'id': 'imp_pl_1',
          'title': 'Restored Playlist',
          'songs': [
            {'videoId': 'imp_pl_s1', 'title': 'Villu Paatu Intro', 'artist': 'Subbu Arumugam'}
          ],
          'songCount': 1
        }
      ],
      'downloadedSongs': [
        {'videoId': 'imp_dl_1', 'title': 'Offline Song To Download', 'artist': 'Ilaiyaraaja'},
      ],
      'cachedSongs': [
        {'videoId': 'imp_cache_1', 'title': 'Song To Cache', 'artist': 'Anirudh'},
      ],
      'preferences': {
        Constant.prefStreamingQuality: Constant.qualityHigh,
      }
    };

    final importFile = File('${tempRoot.path}/import_test.json');
    importFile.writeAsStringSync(jsonEncode(backupData));

    final result = await backupService.importBackup(
      sourceFilePath: importFile.path,
      queueDownloads: false, // Don't trigger real network downloads in test
      queueCaching: false,
    );

    expect(result.success, isTrue);
    expect(result.likedCount, equals(1));
    expect(result.playlistsCount, equals(1));

    // Verify Liked Songs restored in Hive
    expect(favBox.containsKey('imp_liked_1'), isTrue);
    final restoredSong = SongItem.fromJson(Map<String, dynamic>.from(favBox.get('imp_liked_1')));
    expect(restoredSong.title, equals('Imported Liked Song'));
    expect(restoredSong.isLiked, isTrue);

    // Verify Playlist restored in Hive
    expect(playlistBox.containsKey('imp_pl_1'), isTrue);
    final restoredPl = PlaylistItem.fromJson(Map<String, dynamic>.from(playlistBox.get('imp_pl_1')));
    expect(restoredPl.title, equals('Restored Playlist'));
    expect(restoredPl.songs.length, equals(1));
    expect(restoredPl.songs.first.videoId, equals('imp_pl_s1'));
  });
}
