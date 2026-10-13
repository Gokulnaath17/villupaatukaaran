import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'package:villupaatukaaran/models/song_item.dart';
import 'package:villupaatukaaran/services/cache_service.dart';
import 'package:villupaatukaaran/services/constant.dart';
import 'package:villupaatukaaran/services/download_service.dart';
import 'package:villupaatukaaran/services/library_service.dart';
import 'package:villupaatukaaran/services/settings_controller.dart';
import 'package:villupaatukaaran/services/stream_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

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
    tempRoot = Directory.systemTemp.createTempSync('villupaatukaaran_test_');
    Hive.init(tempRoot.path);

    await Hive.openBox(Constant.boxAppPrefs);
    await Hive.openBox(Constant.boxSongsCache);
    await Hive.openBox(Constant.boxSongDownloads);
    await Hive.openBox(Constant.boxSongsUrlCache);
    await Hive.openBox(Constant.boxLibraryPlaylists);
    await Hive.openBox(Constant.boxLibFav);
    await Hive.openBox(Constant.boxLibRP);
    await Hive.openBox(Constant.boxHomeScreenData);
    await Hive.openBox(Constant.boxPrevSessionData);
  });

  tearDown(() async {
    await Hive.close();
    if (tempRoot.existsSync()) {
      try {
        tempRoot.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  test('CacheService initializes unified baseDir with downloads and cache subfolders', () async {
    final cacheService = CacheService();
    await cacheService.init();
    Get.put<CacheService>(cacheService);

    expect(cacheService.baseDir.value.isNotEmpty, isTrue);
    expect(cacheService.downloadsDir.value, equals('${cacheService.baseDir.value}/downloads'));
    expect(cacheService.cacheDir.value, equals('${cacheService.baseDir.value}/cache'));

    // Check directory creation
    expect(Directory(cacheService.downloadsDir.value).existsSync(), isTrue);
    expect(Directory(cacheService.cacheDir.value).existsSync(), isTrue);

    // Custom base dir update
    final customBase = '${tempRoot.path}/CustomMusicVault';
    await cacheService.setBaseDir(customBase);
    expect(cacheService.baseDir.value, equals(customBase));
    expect(cacheService.downloadsDir.value, equals('$customBase/downloads'));
    expect(cacheService.cacheDir.value, equals('$customBase/cache'));
    expect(Directory(cacheService.downloadsDir.value).existsSync(), isTrue);
  });

  test('DownloadService fast-copies cached songs instantly without network', () async {
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

    // Create a mock cached song file in cache/
    final videoId = 'test_song_cached_123';
    final fakeCachedFile = File('${cacheService.cacheDir.value}/$videoId.opus');
    await fakeCachedFile.writeAsString('mock audio byte data');

    final cacheBox = Hive.box(Constant.boxSongsCache);
    await cacheBox.put(videoId, {
      'videoId': videoId,
      'title': 'Villu Paatu Folk Ballad',
      'artist': 'Subbu Arumugam',
      'filePath': fakeCachedFile.path,
      'isCached': true,
      'duration': 180,
    });

    expect(cacheService.isSongCached(videoId), isTrue);
    expect(downloadService.isSongDownloaded(videoId), isFalse);

    // Request download for the cached song
    final song = SongItem(
      videoId: videoId,
      title: 'Villu Paatu Folk Ballad',
      artist: 'Subbu Arumugam',
    );
    await downloadService.downloadSong(song);

    // Should now be downloaded instantly via local copy
    expect(downloadService.isSongDownloaded(videoId), isTrue);

    final expectedFileName = DownloadService.generateSongFileName(song, 'opus');
    final targetFile = File('${cacheService.downloadsDir.value}/$expectedFileName');
    expect(targetFile.existsSync(), isTrue);
    expect(targetFile.readAsStringSync(), equals('mock audio byte data'));

    final downloadsBox = Hive.box(Constant.boxSongDownloads);
    expect(downloadsBox.containsKey(videoId), isTrue);
    expect(downloadsBox.get(videoId)['isDownloaded'], isTrue);
  });

  test('CacheService batch moves all cached tracks to downloads', () async {
    final cacheService = CacheService();
    await cacheService.init();
    Get.put<CacheService>(cacheService);

    final libraryService = LibraryService();
    await libraryService.init();
    Get.put<LibraryService>(libraryService);

    final cacheBox = Hive.box(Constant.boxSongsCache);
    for (int i = 1; i <= 3; i++) {
      final id = 'song_$i';
      final file = File('${cacheService.cacheDir.value}/$id.opus');
      await file.writeAsString('audio content $i');
      await cacheBox.put(id, {
        'videoId': id,
        'title': 'Track $i',
        'artist': 'Artist $i',
        'filePath': file.path,
        'isCached': true,
      });
    }

    final transferred = await cacheService.moveAllCachedToDownloads();
    expect(transferred, equals(3));

    final downloadsBox = Hive.box(Constant.boxSongDownloads);
    expect(downloadsBox.length, equals(3));
    for (int i = 1; i <= 3; i++) {
      final id = 'song_$i';
      expect(downloadsBox.containsKey(id), isTrue);
      final destFile = File('${cacheService.downloadsDir.value}/Artist $i - Track $i.opus');
      expect(destFile.existsSync(), isTrue);
    }
  });

  test('SettingsController factory reset wipes all boxes, caches, and downloads', () async {
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

    final settings = SettingsController();
    Get.put<SettingsController>(settings);

    // Populate data
    final file = File('${cacheService.downloadsDir.value}/sample.opus');
    await file.writeAsString('sample content');
    await Hive.box(Constant.boxSongDownloads).put('sample', {'title': 'Sample'});
    await Hive.box(Constant.boxLibFav).put('sample', {'title': 'Sample Fav'});

    expect(Hive.box(Constant.boxSongDownloads).isNotEmpty, isTrue);
    expect(Hive.box(Constant.boxLibFav).isNotEmpty, isTrue);
    expect(file.existsSync(), isTrue);

    // Execute Factory Reset
    await settings.resetEntireApp();

    // Verify clean slate
    expect(Hive.box(Constant.boxSongDownloads).isEmpty, isTrue);
    expect(Hive.box(Constant.boxLibFav).isEmpty, isTrue);
    expect(Hive.box(Constant.boxSongsCache).isEmpty, isTrue);
    expect(file.existsSync(), isFalse);
  });

  test('LibraryService scans recursively, groups by folder, and allows reordering', () async {
    final cacheService = CacheService();
    await cacheService.init();
    Get.put<CacheService>(cacheService);

    final libraryService = LibraryService();
    await libraryService.init();
    Get.put<LibraryService>(libraryService);

    // 1. Create nested folders in baseDir
    final subFolder = Directory('${cacheService.baseDir.value}/TamilClassics');
    await subFolder.create(recursive: true);
    final songFile1 = File('${subFolder.path}/Subbu Arumugam - Villu Song.opus');
    await songFile1.writeAsString('audio 1');

    final songFile2 = File('${cacheService.downloadsDir.value}/Anirudh - Hukum.mp3');
    await songFile2.writeAsString('audio 2');

    // 2. Create additional granted folder
    final extraDir = Directory('${tempRoot.path}/ExternalMusic/Ilaiyaraaja');
    await extraDir.create(recursive: true);
    final songFile3 = File('${extraDir.path}/Ilaiyaraaja - Thendral Vandhu.wav');
    await songFile3.writeAsString('audio 3');

    // Add granted folder
    await libraryService.addAdditionalFolder(extraDir.path);
    expect(libraryService.additionalFolders.contains(extraDir.path), isTrue);

    // Scan
    await libraryService.loadLocalSongs();

    // Verify all 3 songs are found recursively
    expect(libraryService.localSongs.length, equals(3));
    expect(libraryService.localSongs.any((s) => s.title == 'Villu Song'), isTrue);
    expect(libraryService.localSongs.any((s) => s.title == 'Hukum'), isTrue);
    expect(libraryService.localSongs.any((s) => s.title == 'Thendral Vandhu'), isTrue);

    // Verify folder grouping
    final groups = libraryService.localSongsByFolder;
    expect(groups.containsKey('TamilClassics'), isTrue);
    expect(groups['TamilClassics']!.length, equals(1));
    expect(groups.containsKey(Constant.downloadDirName), isTrue);
    expect(groups.containsKey('Ilaiyaraaja'), isTrue);

    // Verify reordering
    final firstSongId = libraryService.localSongs[0].videoId;
    await libraryService.reorderLocalSongs(0, 2);
    expect(libraryService.localSongs[1].videoId, equals(firstSongId));

    // Verify removing additional folder
    await libraryService.removeAdditionalFolder(extraDir.path);
    expect(libraryService.additionalFolders.contains(extraDir.path), isFalse);
    expect(libraryService.localSongs.length, equals(2));
  });

  test('SettingsController closeAction defaults to ask and persists choices', () async {
    final cacheService = CacheService();
    await cacheService.init();
    Get.put<CacheService>(cacheService);

    final settings = SettingsController();
    Get.put<SettingsController>(settings);

    // Default is ask
    expect(settings.closeAction.value, equals(Constant.closeActionAsk));

    // Change to background
    await settings.setCloseAction(Constant.closeActionBackground);
    expect(settings.closeAction.value, equals(Constant.closeActionBackground));
    expect(Hive.box(Constant.boxAppPrefs).get(Constant.prefCloseAction), equals(Constant.closeActionBackground));

    // Change to exit
    await settings.setCloseAction(Constant.closeActionExit);
    expect(settings.closeAction.value, equals(Constant.closeActionExit));
    expect(Hive.box(Constant.boxAppPrefs).get(Constant.prefCloseAction), equals(Constant.closeActionExit));

    // Reset app should restore closeAction to ask
    await settings.resetEntireApp();
    expect(settings.closeAction.value, equals(Constant.closeActionAsk));
  });
}
