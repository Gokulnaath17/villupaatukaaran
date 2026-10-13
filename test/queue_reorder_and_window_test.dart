import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:audio_service/audio_service.dart';

import 'package:villupaatukaaran/models/song_item.dart';
import 'package:villupaatukaaran/services/audio_handler.dart';
import 'package:villupaatukaaran/services/cache_service.dart';
import 'package:villupaatukaaran/services/constant.dart';
import 'package:villupaatukaaran/services/music_service.dart';
import 'package:villupaatukaaran/services/player_controller.dart';
import 'package:villupaatukaaran/services/tray_and_window_service.dart';

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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('tray_manager'),
      (MethodCall methodCall) async {
        return true;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'isMinimized') return false;
        if (methodCall.method == 'isVisible') return true;
        if (methodCall.method == 'getSize') return [1280.0, 800.0];
        return true;
      },
    );
  });

  setUp(() async {
    Get.reset();
    tempRoot = Directory.systemTemp.createTempSync('villupaatukaaran_queue_test_');
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

  test('MyAudioHandler reorders queue and adjusts currentQueueIndex accurately', () async {
    final handler = MyAudioHandler();
    final items = [
      const MediaItem(id: 'song1', title: 'Song 1', artist: 'Artist 1'),
      const MediaItem(id: 'song2', title: 'Song 2', artist: 'Artist 2'),
      const MediaItem(id: 'song3', title: 'Song 3', artist: 'Artist 3'),
      const MediaItem(id: 'song4', title: 'Song 4', artist: 'Artist 4'),
    ];

    await handler.updateQueue(items);
    expect(handler.queue.value.length, 4);
    expect(handler.queue.value[0].id, 'song1');
    expect(handler.queue.value[1].id, 'song2');
    expect(handler.queue.value[2].id, 'song3');
    expect(handler.queue.value[3].id, 'song4');

    // Simulate ReorderableListView moving song1 (index 0) to after song3 (newIndex 3 in Flutter reorder)
    await handler.reorderQueue(0, 3);
    // In Flutter ReorderableListView, oldIndex < newIndex decrements target to 2
    expect(handler.queue.value[0].id, 'song2');
    expect(handler.queue.value[1].id, 'song3');
    expect(handler.queue.value[2].id, 'song1');
    expect(handler.queue.value[3].id, 'song4');

    // Move song4 from index 3 to front (index 0)
    await handler.reorderQueue(3, 0);
    expect(handler.queue.value[0].id, 'song4');
    expect(handler.queue.value[1].id, 'song2');
    expect(handler.queue.value[2].id, 'song3');
    expect(handler.queue.value[3].id, 'song1');
  });

  test('PlayerController reorderQueue performs optimistic list reordering', () async {
    final musicService = await MusicService().init();
    Get.put<MusicService>(musicService);

    final cacheService = CacheService();
    await cacheService.init();
    Get.put<CacheService>(cacheService);

    final handler = MyAudioHandler();
    Get.put<MyAudioHandler>(handler);

    final controller = PlayerController();
    Get.put<PlayerController>(controller);
    await Future.delayed(const Duration(milliseconds: 50));

    controller.queue.assignAll([
      const SongItem(videoId: 'track1', title: 'Track 1', artist: 'Artist A'),
      const SongItem(videoId: 'track2', title: 'Track 2', artist: 'Artist B'),
      const SongItem(videoId: 'track3', title: 'Track 3', artist: 'Artist C'),
    ]);

    expect(controller.queue.length, 3);
    expect(controller.queue[0].videoId, 'track1');

    // Reorder track1 from index 0 to after track2 (newIndex 2)
    await controller.reorderQueue(0, 2);

    expect(controller.queue[0].videoId, 'track2');
    expect(controller.queue[1].videoId, 'track1');
    expect(controller.queue[2].videoId, 'track3');
  });

  test('TrayAndWindowService Single Instance IPC binds and signals correctly', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, TrayAndWindowService.singleInstancePort);
    String received = '';

    server.listen((client) {
      client.listen((data) {
        received += String.fromCharCodes(data);
      });
    });

    // Second instance attempts ensureSingleInstance -> should detect running server and return false
    final isPrimary = await TrayAndWindowService.ensureSingleInstance();
    expect(isPrimary, isFalse);

    // Give small delay for socket transmission
    await Future.delayed(const Duration(milliseconds: 50));
    expect(received.trim(), 'SHOW');

    await server.close();
  });
}
