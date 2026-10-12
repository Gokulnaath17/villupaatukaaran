import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:villupaatukaaran/services/constant.dart';
import 'package:villupaatukaaran/services/stream_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    },
  );

  test('Test StreamService yt-dlp stream resolution and caching', () async {
    final tempDir = Directory.systemTemp.createTempSync('hive_test');
    Hive.init(tempDir.path);
    await Hive.openBox(Constant.boxSongsUrlCache);
    await Hive.openBox(Constant.boxSongsCache);
    await Hive.openBox(Constant.boxSongDownloads);

    final service = StreamService();
    await service.init();

    // Test direct stream resolution for a known track
    final data = await service.getStreamingData('kJQP7kiw5Fk');

    expect(data.playable, isTrue);
    expect(data.high?.url, isNotNull);
    expect(data.high!.url.startsWith('https://'), isTrue);

    // Test cached hit (should be instant < 5ms)
    final cachedData = await service.getStreamingData('kJQP7kiw5Fk');
    expect(cachedData.playable, isTrue);
    expect(cachedData.high?.url, equals(data.high?.url));
  }, timeout: const Timeout(Duration(seconds: 45)));
}
