import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'constant.dart';

// ─── Update status enum ────────────────────────────────────────────────────

enum UpdateStatus {
  idle,
  checking,
  available,
  downloading,
  verifying,
  installing,
  upToDate,
  failed,
}

// ─── Release info model ────────────────────────────────────────────────────

class ReleaseInfo {
  final String tagName;       // e.g. "v1.13.0"
  final String version;       // e.g. "1.13.0"
  final String releaseNotes;
  final String downloadUrl;   // .tar.gz asset URL
  final String checksumUrl;   // .sha256 asset URL
  final int sizeBytes;

  const ReleaseInfo({
    required this.tagName,
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.checksumUrl,
    required this.sizeBytes,
  });
}

// ─── UpdateService ─────────────────────────────────────────────────────────

/// Manages checking for, downloading, verifying, and applying updates
/// on Linux (and macOS/Windows in future).
class UpdateService extends GetxService {
  final Dio _dio = Dio();

  // Reactive state
  final Rx<UpdateStatus> updateStatus = UpdateStatus.idle.obs;
  final RxBool updateAvailable = false.obs;
  final RxString latestVersion = ''.obs;
  final RxString currentVersion = ''.obs;
  final RxString releaseNotes = ''.obs;
  final RxDouble downloadProgress = 0.0.obs;
  final RxString statusMessage = ''.obs;
  final RxBool autoCheckEnabled = true.obs;
  final RxBool autoInstallEnabled = false.obs;

  ReleaseInfo? _pendingRelease;
  CancelToken? _cancelToken;

  late Box _prefsBox;

  Future<UpdateService> init() async {
    _prefsBox = Hive.box(Constant.boxAppPrefs);

    // Load persisted preferences
    autoCheckEnabled.value  = _prefsBox.get(Constant.prefAutoUpdateCheck,   defaultValue: true)  as bool;
    autoInstallEnabled.value = _prefsBox.get(Constant.prefAutoUpdateInstall, defaultValue: false) as bool;

    // Resolve current version
    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion.value = info.version;
    } catch (_) {
      currentVersion.value = '1.0.0';
    }

    // Auto-check startup logic (debounced to once per 24h)
    if (autoCheckEnabled.value && Constant.isLinux) {
      _scheduleAutoCheck();
    }

    return this;
  }

  void _scheduleAutoCheck() {
    final lastCheckMs = _prefsBox.get(Constant.prefLastUpdateCheck, defaultValue: 0) as int;
    final lastCheck   = DateTime.fromMillisecondsSinceEpoch(lastCheckMs);
    final age         = DateTime.now().difference(lastCheck);

    if (age.inHours >= 24) {
      // Delay slightly so the app finishes loading first
      Future.delayed(const Duration(seconds: 5), () {
        checkForUpdate(silent: true);
      });
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Check GitHub Releases API for a newer version.
  /// [silent] = true: only set state, no error dialogs.
  Future<void> checkForUpdate({bool silent = false}) async {
    if (updateStatus.value == UpdateStatus.checking) return;

    updateStatus.value = UpdateStatus.checking;
    statusMessage.value = 'Checking for updates…';

    try {
      final uri = 'https://api.github.com/repos/'
          '${Constant.githubOwner}/${Constant.githubRepo}/releases/latest';

      final resp = await _dio.get<Map<String, dynamic>>(
        uri,
        options: Options(
          headers: {'Accept': 'application/vnd.github+json'},
          sendTimeout:    const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (resp.statusCode != 200 || resp.data == null) {
        throw Exception('GitHub API returned ${resp.statusCode}');
      }

      final data = resp.data!;
      final tag  = (data['tag_name'] as String? ?? '').replaceFirst(RegExp(r'^v'), '');
      final body = data['body'] as String? ?? '';

      // Find the .tar.gz and .sha256 assets
      final assets = (data['assets'] as List?) ?? [];
      String? dlUrl;
      String? shaUrl;
      int     dlSize = 0;

      for (final asset in assets.cast<Map>()) {
        final name = asset['name'] as String? ?? '';
        if (name == Constant.updateAssetName) {
          dlUrl  = asset['browser_download_url'] as String?;
          dlSize = asset['size'] as int? ?? 0;
        } else if (dlUrl == null && name.endsWith('.tar.gz') && !name.endsWith('.sha256')) {
          dlUrl  = asset['browser_download_url'] as String?;
          dlSize = asset['size'] as int? ?? 0;
        }

        if (name == '${Constant.updateAssetName}.sha256') {
          shaUrl = asset['browser_download_url'] as String?;
        } else if (shaUrl == null && name.endsWith('.tar.gz.sha256')) {
          shaUrl = asset['browser_download_url'] as String?;
        }
      }

      if (dlUrl == null) {
        throw Exception('No download asset "${Constant.updateAssetName}" found in release.');
      }

      // Save last-check timestamp
      await _prefsBox.put(Constant.prefLastUpdateCheck,
          DateTime.now().millisecondsSinceEpoch);

      // Compare versions
      final skipped = _prefsBox.get(Constant.prefSkippedVersion, defaultValue: '') as String;

      if (_isNewer(tag, currentVersion.value) && tag != skipped) {
        latestVersion.value = tag;
        releaseNotes.value  = body;
        updateAvailable.value = true;
        updateStatus.value    = UpdateStatus.available;
        statusMessage.value   = 'Update $tag available';

        _pendingRelease = ReleaseInfo(
          tagName:      'v$tag',
          version:      tag,
          releaseNotes: body,
          downloadUrl:  dlUrl,
          checksumUrl:  shaUrl ?? '',
          sizeBytes:    dlSize,
        );

        // Auto-install if enabled and not in debug mode
        if (autoInstallEnabled.value && !kDebugMode) {
          await applyUpdate();
        }
      } else {
        updateAvailable.value = false;
        updateStatus.value    = UpdateStatus.upToDate;
        statusMessage.value   = 'Up to date (${currentVersion.value})';
        latestVersion.value   = tag.isNotEmpty ? tag : currentVersion.value;
      }
    } catch (e) {
      updateStatus.value  = UpdateStatus.failed;
      statusMessage.value = 'Update check failed: $e';
      debugPrint('[UpdateService] checkForUpdate error: $e');
    }
  }

  /// Downloads, verifies, extracts, then spawns the updater script and exits.
  Future<void> applyUpdate() async {
    final release = _pendingRelease;
    if (release == null) {
      debugPrint('[UpdateService] applyUpdate called with no pending release.');
      return;
    }

    if (kDebugMode) {
      // Simulate in debug mode — don't actually replace files
      statusMessage.value = '[DEBUG] Would install ${release.version}. Skipping actual replacement.';
      updateStatus.value  = UpdateStatus.available;
      return;
    }

    try {
      // ── 1. Prepare update cache directory ────────────────────────────────
      final home      = Platform.environment['HOME'] ?? '/tmp';
      final updateDir = Directory('$home/.cache/villupaatukaaran/updates');
      await updateDir.create(recursive: true);

      final archivePath = '${updateDir.path}/${Constant.updateAssetName}';
      final shaPath     = '${updateDir.path}/${Constant.updateAssetName}.sha256';
      final extractDir  = '${updateDir.path}/extracted';

      // Clean any previous extraction
      final extractDirObj = Directory(extractDir);
      if (await extractDirObj.exists()) {
        await extractDirObj.delete(recursive: true);
      }
      await extractDirObj.create(recursive: true);

      // ── 2. Download archive ───────────────────────────────────────────────
      updateStatus.value    = UpdateStatus.downloading;
      statusMessage.value   = 'Downloading ${release.version}…';
      downloadProgress.value = 0.0;
      _cancelToken = CancelToken();

      await _dio.download(
        release.downloadUrl,
        archivePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            downloadProgress.value = received / total;
          }
        },
        options: Options(
          headers: {'Accept': 'application/octet-stream'},
          receiveTimeout: const Duration(minutes: 10),
        ),
      );
      downloadProgress.value = 1.0;

      // ── 3. Download checksum ──────────────────────────────────────────────
      if (release.checksumUrl.isNotEmpty) {
        await _dio.download(
          release.checksumUrl,
          shaPath,
          options: Options(receiveTimeout: const Duration(seconds: 30)),
        );
      }

      // ── 4. Verify SHA-256 ─────────────────────────────────────────────────
      updateStatus.value  = UpdateStatus.verifying;
      statusMessage.value = 'Verifying checksum…';

      final shaFile = File(shaPath);
      if (await shaFile.exists()) {
        final expectedLine = (await shaFile.readAsString()).trim().split(RegExp(r'\s+')).first;
        final archiveBytes = await File(archivePath).readAsBytes();
        final actual       = sha256.convert(archiveBytes).toString();

        if (actual != expectedLine) {
          await File(archivePath).delete();
          throw Exception('SHA-256 mismatch: expected $expectedLine, got $actual');
        }
      } else {
        debugPrint('[UpdateService] No checksum file — skipping verification.');
      }

      // ── 5. Extract archive ────────────────────────────────────────────────
      updateStatus.value  = UpdateStatus.installing;
      statusMessage.value = 'Extracting…';

      final tarResult = await Process.run(
        'tar', ['-xzf', archivePath, '-C', extractDir],
      );
      if (tarResult.exitCode != 0) {
        throw Exception('tar extraction failed: ${tarResult.stderr}');
      }

      // The extracted folder might be a single subdirectory — find it
      final extractedContents = await extractDirObj.list().toList();
      String newBundleDir = extractDir;
      if (extractedContents.length == 1 && extractedContents.first is Directory) {
        newBundleDir = extractedContents.first.path;
      }

      // ── 6. Spawn updater script ───────────────────────────────────────────
      statusMessage.value = 'Restarting…';

      final executablePath = Platform.resolvedExecutable;
      final bundleDir      = File(executablePath).parent.path;
      final scriptPath     = '$bundleDir/bin/villupaatukaaran-updater.sh';
      final appPid         = pid.toString();

      debugPrint('[UpdateService] Spawning updater: $scriptPath');
      debugPrint('[UpdateService] PID=$appPid  bundle=$bundleDir  new=$newBundleDir');

      await Process.start(
        'bash',
        [
          scriptPath,
          appPid,
          newBundleDir,
          bundleDir,
          executablePath,
        ],
        mode: ProcessStartMode.detached,
      );

      // Give the script a moment to start before we exit
      await Future.delayed(const Duration(milliseconds: 300));
      exit(0);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        updateStatus.value  = UpdateStatus.available;
        statusMessage.value = 'Download cancelled';
      } else {
        updateStatus.value  = UpdateStatus.failed;
        statusMessage.value = 'Download failed: ${e.message}';
        debugPrint('[UpdateService] download error: $e');
      }
    } catch (e) {
      updateStatus.value  = UpdateStatus.failed;
      statusMessage.value = 'Update failed: $e';
      debugPrint('[UpdateService] applyUpdate error: $e');
    }
  }

  /// Cancel an in-progress download
  void cancelDownload() {
    _cancelToken?.cancel('User cancelled');
    _cancelToken = null;
    updateStatus.value    = UpdateStatus.available;
    statusMessage.value   = 'Download cancelled';
    downloadProgress.value = 0.0;
  }

  /// Skip the current pending version
  Future<void> skipVersion() async {
    if (_pendingRelease != null) {
      await _prefsBox.put(Constant.prefSkippedVersion, _pendingRelease!.version);
    }
    updateAvailable.value = false;
    updateStatus.value    = UpdateStatus.upToDate;
    statusMessage.value   = 'Skipped ${latestVersion.value}';
  }

  Future<void> setAutoCheck(bool enabled) async {
    autoCheckEnabled.value = enabled;
    await _prefsBox.put(Constant.prefAutoUpdateCheck, enabled);
  }

  Future<void> setAutoInstall(bool enabled) async {
    autoInstallEnabled.value = enabled;
    await _prefsBox.put(Constant.prefAutoUpdateInstall, enabled);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Semantic version comparison: returns true if [candidate] > [current]
  bool _isNewer(String candidate, String current) {
    final c = _parseVersion(candidate);
    final v = _parseVersion(current);
    for (int i = 0; i < 3; i++) {
      if (c[i] > v[i]) return true;
      if (c[i] < v[i]) return false;
    }
    return false;
  }

  List<int> _parseVersion(String v) {
    final parts = v.replaceAll(RegExp(r'[^0-9.]'), '').split('.');
    return List.generate(3, (i) => i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0);
  }

  String get formattedDownloadProgress =>
      '${(downloadProgress.value * 100).toInt()}%';

  String? get pendingReleaseNotes => _pendingRelease?.releaseNotes;
  int get pendingSizeBytes => _pendingRelease?.sizeBytes ?? 0;
  String get pendingSizeMb =>
      pendingSizeBytes > 0 ? '${(pendingSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB' : '';
}

