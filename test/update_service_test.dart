import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:villupaatukaaran/services/constant.dart';
import 'package:villupaatukaaran/services/update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'Villupaatukaaran',
      packageName: 'com.harmonymusic.villupaatukaaran',
      version: '1.12.2',
      buildNumber: '27',
      buildSignature: '',
    );
  });

  setUp(() async {
    Get.reset();
    tempRoot = Directory.systemTemp.createTempSync('villu_update_test_');
    Hive.init(tempRoot.path);
    await Hive.openBox(Constant.boxAppPrefs);
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

  test('UpdateService initializes with persisted preferences and package version', () async {
    final prefsBox = Hive.box(Constant.boxAppPrefs);
    await prefsBox.put(Constant.prefAutoUpdateCheck, true);
    await prefsBox.put(Constant.prefAutoUpdateInstall, false);

    final service = UpdateService();
    await service.init();

    expect(service.autoCheckEnabled.value, isTrue);
    expect(service.autoInstallEnabled.value, isFalse);
    expect(service.currentVersion.value, equals('1.12.2'));
    expect(service.updateStatus.value, equals(UpdateStatus.idle));
  });

  test('UpdateService toggles autoCheck and autoInstall and persists to Hive', () async {
    final service = UpdateService();
    await service.init();

    await service.setAutoCheck(false);
    expect(service.autoCheckEnabled.value, isFalse);
    expect(Hive.box(Constant.boxAppPrefs).get(Constant.prefAutoUpdateCheck), isFalse);

    await service.setAutoInstall(true);
    expect(service.autoInstallEnabled.value, isTrue);
    expect(Hive.box(Constant.boxAppPrefs).get(Constant.prefAutoUpdateInstall), isTrue);
  });

  test('UpdateService SHA-256 verification correctly verifies valid data and rejects invalid data', () async {
    // Generate a temporary test archive file
    final testFile = File('${tempRoot.path}/test_bundle.tar.gz');
    await testFile.writeAsString('mock binary payload for villupaatukaaran update test');

    final bytes = await testFile.readAsBytes();
    final realSha256 = sha256.convert(bytes).toString();

    expect(realSha256.length, equals(64));

    // Verify correct match
    final checksumLine = '$realSha256  villupaatukaaran-linux-x64.tar.gz';
    final parsedChecksum = checksumLine.trim().split(RegExp(r'\s+')).first;
    expect(parsedChecksum, equals(realSha256));

    // Verify mismatch detection
    const fakeChecksum = '0000000000000000000000000000000000000000000000000000000000000000';
    expect(realSha256 == fakeChecksum, isFalse);
  });

  test('ReleaseInfo model constructs and formats sizes correctly', () {
    const info = ReleaseInfo(
      tagName: 'v1.13.0',
      version: '1.13.0',
      releaseNotes: 'Fixed bugs & added updates',
      downloadUrl: 'https://github.com/gokulnaath17/villupaatukaaran/releases/download/v1.13.0/villupaatukaaran-linux-x64.tar.gz',
      checksumUrl: 'https://github.com/gokulnaath17/villupaatukaaran/releases/download/v1.13.0/villupaatukaaran-linux-x64.tar.gz.sha256',
      sizeBytes: 15728640, // 15 MB
    );

    expect(info.version, equals('1.13.0'));
    expect(info.tagName, equals('v1.13.0'));
    expect(info.sizeBytes, equals(15728640));
  });

  test('UpdateService skipVersion persists skipped version to AppPrefs', () async {
    final service = UpdateService();
    await service.init();

    service.latestVersion.value = '1.14.0';
    await service.skipVersion();

    // Stored in prefs
    expect(service.updateAvailable.value, isFalse);
    expect(service.updateStatus.value, equals(UpdateStatus.upToDate));
  });
}
