import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:villupaatukaaran/utils/linux_audio_init.dart';
import 'package:hive/hive.dart';
import 'package:get/get.dart';
import 'package:villupaatukaaran/services/constant.dart';
import 'package:villupaatukaaran/services/stream_service.dart';
import 'package:villupaatukaaran/services/audio_handler.dart';
import 'package:villupaatukaaran/models/song_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    },
  );

  test('Test MyAudioHandler setQueueAndPlay', () async {
    LinuxAudioInit.ensureInitialized();

    final tempDir = Directory.systemTemp.createTempSync('hive_test');
    Hive.init(tempDir.path);
    await Hive.openBox(Constant.boxSongsUrlCache);
    await Hive.openBox(Constant.boxSongsCache);
    await Hive.openBox(Constant.boxSongDownloads);

    final streamService = await StreamService().init();
    Get.put<StreamService>(streamService);

    final handler = MyAudioHandler();

    const testSong = SongItem(
      videoId: 'kJQP7kiw5Fk',
      title: 'Kalaivaniyo Raniyo',
      artist: 'SPB',
      duration: '4:42',
      durationSeconds: 282,
    );

    await handler.setQueueAndPlay([testSong.toMediaItem()]);

    expect(handler.player.playing, isTrue);
    await handler.player.stop();
  }, timeout: const Timeout(Duration(seconds: 45)));
}
