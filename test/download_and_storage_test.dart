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

    final targetFile = File('${cacheService.downloadsDir.value}/$videoId.opus');
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
      final destFile = File('${cacheService.downloadsDir.value}/$id.opus');
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
}
