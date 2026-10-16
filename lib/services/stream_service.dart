import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:hive/hive.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'cache_service.dart';
import 'constant.dart';
import 'settings_controller.dart';
import 'utils.dart';

/// Stream service for resolving audio URLs
class StreamService extends GetxService {
  late YoutubeExplode _youtubeExplode;
  late Box _urlCacheBox;
  late Box _songsCacheBox;
  late Box _songDownloadsBox;
  late Directory _tempCacheDir;
  late Directory _downloadDir;

  /// Initialize service
  Future<StreamService> init() async {
    _youtubeExplode = YoutubeExplode();
    _urlCacheBox = Hive.box(Constant.boxSongsUrlCache);
    _songsCacheBox = Hive.box(Constant.boxSongsCache);
    _songDownloadsBox = Hive.box(Constant.boxSongDownloads);

    // Setup unified directories
    if (Get.isRegistered<CacheService>()) {
      final cacheService = Get.find<CacheService>();
      _tempCacheDir = Directory(cacheService.cacheDir.value);
      _downloadDir = Directory(cacheService.downloadsDir.value);
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      _tempCacheDir = Directory('${appDir.path}/${Constant.tempCacheDirName}');
      _downloadDir = Directory('${appDir.path}/${Constant.downloadDirName}');
    }

    if (!await _tempCacheDir.exists()) {
      await _tempCacheDir.create(recursive: true);
    }
    if (!await _downloadDir.exists()) {
      await _downloadDir.create(recursive: true);
    }

    return this;
  }

  /// Get streaming data for a song (3-tier priority)
  Future<HMStreamingData> getStreamingData(String videoId, {bool generateNewUrl = false}) async {
    // Tier 1: SongsCache (temp cached files)
    if (!generateNewUrl) {
      final cacheHit = _songsCacheBox.get(videoId);
      if (cacheHit != null) {
        final file = File(cacheHit['filePath'] as String);
        if (await file.exists()) {
          return HMStreamingData(
            playable: true,
            statusMsg: 'From temp cache',
            low: StreamInfo(
              itag: 249,
              codec: 'opus',
              bitrate: 50000,
              duration: _safeInt(cacheHit['durationSeconds'], cacheHit['duration']),
              url: 'file://${file.path}',
              size: await file.length(),
            ),
            high: StreamInfo(
              itag: 251,
              codec: 'opus',
              bitrate: 160000,
              duration: _safeInt(cacheHit['durationSeconds'], cacheHit['duration']),
              url: 'file://${file.path}',
              size: await file.length(),
            ),
            qualityIndex: Constant.qualityHigh,
          );
        }
      }
    }

    // Tier 2: SongDownloads (permanent downloads)
    if (!generateNewUrl) {
      final downloadHit = _songDownloadsBox.get(videoId);
      if (downloadHit != null) {
        final filePath = downloadHit['url'] as String? ?? '';
        final file = File(filePath);
        if (await file.exists()) {
          return HMStreamingData(
            playable: true,
            statusMsg: 'From downloads',
            low: StreamInfo(
              itag: 139,
              codec: 'mp4a',
              bitrate: 48000,
              duration: _safeInt(downloadHit['durationSeconds'], downloadHit['duration']),
              url: 'file://$filePath',
              size: await file.length(),
            ),
            high: StreamInfo(
              itag: 140,
              codec: 'mp4a',
              bitrate: 128000,
              duration: _safeInt(downloadHit['durationSeconds'], downloadHit['duration']),
              url: 'file://$filePath',
              size: await file.length(),
            ),
            qualityIndex: Constant.qualityHigh,
          );
        } else {
          // File missing, fall through to online
          debugPrint('Download file missing for $videoId, falling back to online');
        }
      }
    }

    // Tier 3: SongsUrlCache (cached URLs with expiry)
    if (!generateNewUrl) {
      final urlCacheHit = _urlCacheBox.get(videoId);
      if (urlCacheHit != null) {
        HMStreamingData? data;
        try {
          if (urlCacheHit is Map) {
            data = HMStreamingData.fromJson(Map<String, dynamic>.from(urlCacheHit));
          } else if (urlCacheHit is HMStreamingData) {
            data = urlCacheHit;
          }
        } catch (_) {}

        if (data != null && data.playable && !Utils.isExpired(data.high?.url)) {
          return data;
        } else {
          debugPrint('URL cache expired or invalid for $videoId');
        }
      }
    }

    // Tier 4: Fetch via yt-dlp first (fast, handles signature ciphers reliably on desktop)
    if (Constant.isDesktop) {
      final ytdlpData = await _fetchFromYtDlp(videoId);
      if (ytdlpData.playable) {
        return ytdlpData;
      }
    }

    // Tier 5: Direct signed stream resolution via youtube_explode with Android and iOS clients
    return await _fetchFromYouTube(videoId);
  }

  /// Invalidate cached URL for a video ID (e.g. after a 403 or playback error)
  Future<void> invalidateUrlCache(String videoId) async {
    try {
      await _urlCacheBox.delete(videoId);
    } catch (_) {}
  }

  /// Fetch stream info from YouTube using youtube_explode
  Future<HMStreamingData> _fetchFromYouTube(String videoId) async {
    try {
      final manifest = await _youtubeExplode.videos.streamsClient.getManifest(
        videoId,
        ytClients: [
          YoutubeApiClient.androidSdkless,
          YoutubeApiClient.ios,
        ],
      );
      final audioOnly = manifest.audioOnly.toList();

      if (audioOnly.isEmpty) {
        return HMStreamingData(
          playable: false,
          statusMsg: 'No audio streams found',
        );
      }

      // Sort by bitrate descending
      audioOnly.sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));

      // Find low (opus 249/139) and high (opus 251/140) quality
      StreamInfo? low;
      StreamInfo? high;

      for (final stream in audioOnly) {
        final isWebM = stream.container == StreamContainer.webM;
        final isMp4 = stream.container == StreamContainer.mp4;
        if (isWebM || isMp4) {
          final bps = stream.bitrate.bitsPerSecond;
          if (low == null && (bps <= 64000 || stream.tag == 249 || stream.tag == 139)) {
            low = StreamInfo.fromYoutubeStream(stream);
          }
          if (high == null && (bps >= 128000 || stream.tag == 251 || stream.tag == 140)) {
            high = StreamInfo.fromYoutubeStream(stream);
          }
        }
      }

      // Fallback: use lowest and highest bitrate
      if (audioOnly.isNotEmpty) {
        final lowest = audioOnly.reduce(
          (a, b) => a.bitrate.bitsPerSecond < b.bitrate.bitsPerSecond ? a : b,
        );
        final highest = audioOnly.reduce(
          (a, b) => a.bitrate.bitsPerSecond > b.bitrate.bitsPerSecond ? a : b,
        );
        low ??= StreamInfo.fromYoutubeStream(lowest);
        high ??= StreamInfo.fromYoutubeStream(highest);
      }

      final streamingData = HMStreamingData(
        playable: true,
        statusMsg: 'OK',
        low: low,
        high: high,
        qualityIndex: Constant.qualityHigh,
      );

      // Cache the URL safely as JSON map
      await _urlCacheBox.put(videoId, streamingData.toJson());

      return streamingData;
    } catch (e) {
      debugPrint('[StreamService] youtube_explode error for $videoId: $e');
      return HMStreamingData(
        playable: false,
        statusMsg: 'Error: $e',
      );
    }
  }

  /// Resolve direct streaming URL via yt-dlp
  Future<HMStreamingData> _fetchFromYtDlp(String videoId) async {
    try {
      final ytdlpPath = await _findYtDlpPath();
      if (ytdlpPath == null) {
        return HMStreamingData(playable: false, statusMsg: 'yt-dlp not found');
      }

      final url = 'https://www.youtube.com/watch?v=$videoId';
      final res = await Process.run(ytdlpPath, [
        '--no-warnings',
        '--extractor-args',
        'youtube:player_client=android,mweb,web',
        '-g',
        '-f',
        'ba/b/18',
        '--no-playlist',
        url,
      ]);

      if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
        final lines = res.stdout.toString().trim().split('\n');
        String? streamUrl;
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
            streamUrl = trimmed;
            break;
          }
        }
        if (streamUrl != null) {
          final streamInfo = StreamInfo(
            itag: 251,
            codec: 'opus',
            bitrate: 160000,
            duration: 0,
            url: streamUrl,
            size: 0,
          );
          final data = HMStreamingData(
            playable: true,
            statusMsg: 'OK',
            low: streamInfo,
            high: streamInfo,
            qualityIndex: Constant.qualityHigh,
          );
          await _urlCacheBox.put(videoId, data.toJson());
          return data;
        }
      } else {
        debugPrint('[StreamService] yt-dlp failed: code=${res.exitCode}, stderr=${res.stderr}');
      }
    } catch (e) {
      debugPrint('[StreamService] yt-dlp stream resolution error: $e');
    }
    return HMStreamingData(playable: false, statusMsg: 'yt-dlp resolution failed');
  }

  /// Locate yt-dlp binary
  Future<String?> _findYtDlpPath() async {
    String? exeDir;
    try {
      exeDir = File(Platform.resolvedExecutable).parent.path;
    } catch (_) {}

    final candidates = [
      if (exeDir != null) '$exeDir/bin/yt-dlp',
      if (exeDir != null) '$exeDir/bin/yt-dlp.exe',
      if (exeDir != null) '$exeDir/yt-dlp',
      if (exeDir != null) '$exeDir/yt-dlp.exe',
      '/home/gokul/.local/bin/yt-dlp',
      '/home/gokul/Dev/Github/self/villupaatukaaran/linux/bin/yt-dlp',
      'yt-dlp',
      'yt-dlp.exe',
    ];
    for (final p in candidates) {
      if (p == 'yt-dlp' || p == 'yt-dlp.exe') {
        try {
          final cmd = Platform.isWindows ? 'where' : 'which';
          final which = await Process.run(cmd, [p]);
          if (which.exitCode == 0 && which.stdout.toString().trim().isNotEmpty) {
            return which.stdout.toString().trim().split(RegExp(r'[\r\n]+')).first.trim();
          }
        } catch (_) {}
      } else if (File(p).existsSync()) {
        return p;
      }
    }
    return null;
  }

  /// Get stream URL based on quality preference
  Future<String?> getStreamUrl(String videoId, {int? quality}) async {
    final streamingData = await getStreamingData(videoId);
    if (!streamingData.playable) return null;

    final prefQuality = quality ?? Get.find<SettingsController>().streamingQuality.value;
    final streamInfo = prefQuality == Constant.qualityHigh ? streamingData.high : streamingData.low;

    return streamInfo?.url;
  }

  /// Promote temp cached file to SongsCache if >= 98% buffered
  Future<void> checkAndPromoteCache(String videoId, String url, int bufferedPercent) async {
    if (bufferedPercent >= 98 && url.startsWith('file://') && url.contains(Constant.tempCacheDirName)) {
      final filePath = url.replaceFirst('file://', '');
      final file = File(filePath);
      if (await file.exists()) {
        final size = await file.length();
        // Store in SongsCache
        await _songsCacheBox.put(videoId, {
          'filePath': filePath,
          'size': size,
          'duration': 0, // Will be updated when known
        });
        debugPrint('Promoted $videoId to SongsCache');
      }
    }
  }

  /// Clear expired URL cache entries
  Future<void> clearExpiredUrlCache() async {
    final keysToDelete = <String>[];
    for (final key in _urlCacheBox.keys) {
      final data = _urlCacheBox.get(key);
      if (data is HMStreamingData && Utils.isExpired(data.high?.url)) {
        keysToDelete.add(key as String);
      }
    }
    for (final key in keysToDelete) {
      await _urlCacheBox.delete(key);
    }
    debugPrint('Cleared ${keysToDelete.length} expired URL cache entries');
  }

  /// Clear missing download files from database
  Future<void> clearMissingDownloads() async {
    final keysToDelete = <String>[];
    for (final key in _songDownloadsBox.keys) {
      final data = _songDownloadsBox.get(key);
      if (data != null) {
        final filePath = data['url'] as String? ?? '';
        final file = File(filePath);
        if (!await file.exists()) {
          keysToDelete.add(key as String);
        }
      }
    }
    for (final key in keysToDelete) {
      await _songDownloadsBox.delete(key);
    }
    debugPrint('Cleared ${keysToDelete.length} missing download entries');
  }

  /// Dispose
  @override
  void onClose() {
    _youtubeExplode.close();
    super.onClose();
  }
}

/// Stream info model
class StreamInfo {
  final int itag;
  final String codec;
  final int bitrate;
  final int duration;
  final String url;
  final int size;
  final double? loudnessDb;

  StreamInfo({
    required this.itag,
    required this.codec,
    required this.bitrate,
    required this.duration,
    required this.url,
    required this.size,
    this.loudnessDb,
  });

  factory StreamInfo.fromYoutubeStream(AudioOnlyStreamInfo stream) {
    return StreamInfo(
      itag: stream.tag,
      codec: stream.container == StreamContainer.webM ? 'opus' : 'mp4a',
      bitrate: stream.bitrate.bitsPerSecond,
      duration: 0,
      url: stream.url.toString(),
      size: stream.size.totalBytes,
    );
  }

  Map<String, dynamic> toJson() => {
        'itag': itag,
        'codec': codec,
        'bitrate': bitrate,
        'duration': duration,
        'url': url,
        'size': size,
        'loudnessDb': loudnessDb,
      };

  factory StreamInfo.fromJson(Map<dynamic, dynamic> json) => StreamInfo(
        itag: _safeInt(json['itag']),
        codec: json['codec']?.toString() ?? '',
        bitrate: _safeInt(json['bitrate']),
        duration: _safeInt(json['durationSeconds'], json['duration']),
        url: json['url']?.toString() ?? '',
        size: _safeInt(json['size']),
        loudnessDb: (json['loudnessDb'] as num?)?.toDouble(),
      );
}

/// Helper to safely parse ints from int, num, string, or mm:ss timestamps
int _safeInt(dynamic val, [dynamic fallback]) {
  if (val is int) return val;
  if (val is num) return val.toInt();
  if (val is String && val.trim().isNotEmpty) {
    final direct = int.tryParse(val.trim());
    if (direct != null) return direct;
    final parts = val.split(':').map((p) => int.tryParse(p.trim()) ?? 0).toList();
    if (parts.length == 2) return parts[0] * 60 + parts[1];
    if (parts.length == 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
  }
  if (fallback != null) return _safeInt(fallback);
  return 0;
}

/// Streaming data container
class HMStreamingData {
  final bool playable;
  final String statusMsg;
  final StreamInfo? low;
  final StreamInfo? high;
  final int qualityIndex;

  HMStreamingData({
    required this.playable,
    required this.statusMsg,
    this.low,
    this.high,
    this.qualityIndex = Constant.qualityHigh,
  });

  Map<String, dynamic> toJson() => {
        'playable': playable,
        'statusMsg': statusMsg,
        'low': low?.toJson(),
        'high': high?.toJson(),
        'qualityIndex': qualityIndex,
      };

  factory HMStreamingData.fromJson(Map<dynamic, dynamic> json) => HMStreamingData(
        playable: json['playable'] == true,
        statusMsg: json['statusMsg']?.toString() ?? '',
        low: json['low'] is Map ? StreamInfo.fromJson(json['low'] as Map) : null,
        high: json['high'] is Map ? StreamInfo.fromJson(json['high'] as Map) : null,
        qualityIndex: _safeInt(json['qualityIndex'], Constant.qualityHigh),
      );
}