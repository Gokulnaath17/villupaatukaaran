import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'cache_service.dart';
import 'constant.dart';
import 'library_service.dart';
import 'stream_service.dart';
import '../models/song_item.dart';

/// Status of a download task
enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
  cancelled,
}

/// Observable model tracking an individual song download
class DownloadTask {
  final SongItem song;
  final Rx<DownloadStatus> status;
  final RxDouble progress; // 0.0 to 1.0
  final RxInt downloadedBytes;
  final RxInt totalBytes;
  final RxnString errorMessage;
  CancelToken? cancelToken;

  DownloadTask({
    required this.song,
    DownloadStatus initialStatus = DownloadStatus.pending,
  })  : status = initialStatus.obs,
        progress = 0.0.obs,
        downloadedBytes = 0.obs,
        totalBytes = 0.obs,
        errorMessage = RxnString();

  String get videoId => song.videoId;
  String get title => song.title;
  String get artist => song.artist;

  String get progressPercentage => '${(progress.value * 100).toInt()}%';

  String get sizeStatusText {
    if (totalBytes.value <= 0) return '';
    final dlMb = (downloadedBytes.value / (1024 * 1024)).toStringAsFixed(1);
    final totMb = (totalBytes.value / (1024 * 1024)).toStringAsFixed(1);
    return '$dlMb MB / $totMb MB';
  }
}

/// Service managing the song download queue, background streaming, and offline persistence
class DownloadService extends GetxService {
  late final Box _downloadsBox;
  late final CacheService _cacheService;
  late final StreamService _streamService;
  final Dio _dio = Dio();

  final RxList<DownloadTask> downloadQueue = <DownloadTask>[].obs;
  final RxInt activeDownloadsCount = 0.obs;
  final int maxConcurrentDownloads = 2;

  Future<DownloadService> init() async {
    _downloadsBox = Hive.isBoxOpen(Constant.boxSongDownloads)
        ? Hive.box(Constant.boxSongDownloads)
        : await Hive.openBox(Constant.boxSongDownloads);

    _cacheService = Get.find<CacheService>();
    _streamService = Get.find<StreamService>();

    return this;
  }

  /// Check if a song is currently in the download queue
  bool isSongDownloading(String videoId) {
    return downloadQueue.any((t) =>
        t.videoId == videoId &&
        (t.status.value == DownloadStatus.downloading ||
            t.status.value == DownloadStatus.pending));
  }

  /// Get the download task for a song, if any
  DownloadTask? getTask(String videoId) {
    return downloadQueue.firstWhereOrNull((t) => t.videoId == videoId);
  }

  /// Check if a song is already downloaded and present on disk
  bool isSongDownloaded(String videoId) {
    if (!_downloadsBox.containsKey(videoId)) return false;
    final data = _downloadsBox.get(videoId);
    if (data is Map) {
      final path = (data['url'] ?? data['filePath']) as String?;
      if (path != null && File(path).existsSync()) return true;
    }
    return false;
  }

  /// Enqueue a song for offline download
  Future<void> downloadSong(SongItem song) async {
    // 1. Check if already downloaded
    if (isSongDownloaded(song.videoId)) {
      _notify('Already Downloaded', '"${song.title}" is already saved in offline storage');
      return;
    }

    // 2. Check if already in active queue
    if (isSongDownloading(song.videoId)) {
      _notify('In Queue', '"${song.title}" is already being downloaded');
      return;
    }

    // 3. Fast cache transfer: If already cached locally, copy instantly with zero network
    if (_cacheService.isSongCached(song.videoId)) {
      final cachedPath = _cacheService.getCachedFilePath(song.videoId);
      if (cachedPath != null && File(cachedPath).existsSync()) {
        try {
          final ext = cachedPath.contains('.') ? cachedPath.split('.').last : 'opus';
          final targetPath = '${_cacheService.downloadsDir.value}/${song.videoId}.$ext';
          await File(cachedPath).copy(targetPath);
          final fileSize = await File(targetPath).length();

          await _persistDownload(song, targetPath, fileSize);

          final instantTask = DownloadTask(song: song, initialStatus: DownloadStatus.completed);
          instantTask.progress.value = 1.0;
          instantTask.downloadedBytes.value = fileSize;
          instantTask.totalBytes.value = fileSize;
          downloadQueue.insert(0, instantTask);

          _notify('Downloaded Offline', 'Saved "${song.title}" instantly from local cache');
          return;
        } catch (e) {
          debugPrint('[DownloadService] Fast cache copy failed, falling back to network: $e');
        }
      }
    }

    // 4. Create and enqueue task
    final task = DownloadTask(song: song);
    downloadQueue.add(task);

    _notify('Download Queued', 'Added "${song.title}" to download queue');

    _processQueue();
  }

  /// Process pending tasks up to max concurrency
  void _processQueue() {
    final active = downloadQueue.where((t) => t.status.value == DownloadStatus.downloading).length;
    activeDownloadsCount.value = active;

    if (active >= maxConcurrentDownloads) return;

    final pending = downloadQueue.where((t) => t.status.value == DownloadStatus.pending).toList();
    if (pending.isEmpty) return;

    final slotsAvailable = maxConcurrentDownloads - active;
    for (int i = 0; i < slotsAvailable && i < pending.length; i++) {
      _executeDownload(pending[i]);
    }
  }

  /// Execute an individual download task
  Future<void> _executeDownload(DownloadTask task) async {
    task.status.value = DownloadStatus.downloading;
    activeDownloadsCount.value = downloadQueue.where((t) => t.status.value == DownloadStatus.downloading).length;

    try {
      // 1. Resolve playable audio stream URL
      final streamingData = await _streamService.getStreamingData(task.song.videoId);
      if (!streamingData.playable) {
        task.status.value = DownloadStatus.failed;
        task.errorMessage.value = streamingData.statusMsg.isNotEmpty
            ? streamingData.statusMsg
            : 'Could not resolve audio stream';
        _processQueue();
        return;
      }

      final streamInfo = streamingData.high ?? streamingData.low;
      if (streamInfo == null || streamInfo.url.isEmpty) {
        task.status.value = DownloadStatus.failed;
        task.errorMessage.value = 'Stream URL unavailable';
        _processQueue();
        return;
      }

      // 2. Prepare target file path in unified downloads folder
      final isM4a = streamInfo.codec.contains('mp4') || streamInfo.url.contains('.m4a');
      final ext = isM4a ? 'm4a' : 'opus';
      final fileName = '${task.song.videoId}.$ext';
      final savePath = '${_cacheService.downloadsDir.value}/$fileName';

      task.cancelToken = CancelToken();

      // 3. Download stream with real-time progress callbacks
      await _dio.download(
        streamInfo.url,
        savePath,
        cancelToken: task.cancelToken,
        options: Options(headers: {
          'User-Agent': Constant.innertubeUserAgent,
        }),
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            task.downloadedBytes.value = received;
            task.totalBytes.value = total;
            task.progress.value = (received / total).clamp(0.0, 1.0);
          }
        },
      );

      final file = File(savePath);
      if (await file.exists()) {
        final fileSize = await file.length();
        await _persistDownload(task.song, savePath, fileSize);

        task.progress.value = 1.0;
        task.status.value = DownloadStatus.completed;

        _notify('Download Complete', 'Saved "${task.song.title}" for offline playback');
      } else {
        task.status.value = DownloadStatus.failed;
        task.errorMessage.value = 'Target file was not saved';
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        task.status.value = DownloadStatus.cancelled;
      } else {
        task.status.value = DownloadStatus.failed;
        task.errorMessage.value = e.toString();
        debugPrint('[DownloadService] Download error for ${task.song.title}: $e');
      }
    } finally {
      activeDownloadsCount.value = downloadQueue.where((t) => t.status.value == DownloadStatus.downloading).length;
      _processQueue();
    }
  }

  /// Persist downloaded song metadata in Hive and refresh library
  Future<void> _persistDownload(SongItem song, String savePath, int fileSize) async {
    final payload = {
      ...song.toJson(),
      'filePath': savePath,
      'url': savePath,
      'isDownloaded': true,
      'downloadedAt': DateTime.now().millisecondsSinceEpoch,
      'sizeBytes': fileSize,
    };

    await _downloadsBox.put(song.videoId, payload);

    if (Get.isRegistered<LibraryService>()) {
      await Get.find<LibraryService>().refreshAll();
    }
  }

  /// Cancel an ongoing or pending download
  void cancelDownload(String videoId) {
    final task = getTask(videoId);
    if (task != null) {
      task.cancelToken?.cancel('Cancelled by user');
      task.status.value = DownloadStatus.cancelled;
      _processQueue();
    }
  }

  /// Retry a failed or cancelled download
  void retryDownload(String videoId) {
    final task = getTask(videoId);
    if (task != null) {
      task.status.value = DownloadStatus.pending;
      task.progress.value = 0.0;
      task.errorMessage.value = null;
      _processQueue();
    }
  }

  /// Remove completed and cancelled tasks from the queue list
  void clearCompleted() {
    downloadQueue.removeWhere((t) =>
        t.status.value == DownloadStatus.completed ||
        t.status.value == DownloadStatus.cancelled);
  }

  /// Clear all tasks
  void clearAllTasks() {
    for (final task in downloadQueue) {
      task.cancelToken?.cancel('App reset');
    }
    downloadQueue.clear();
    activeDownloadsCount.value = 0;
  }

  /// Batch-move all cached songs to offline downloads
  Future<int> moveAllCachedToDownloads() async {
    final count = await _cacheService.moveAllCachedToDownloads();
    if (count > 0 && Get.isRegistered<LibraryService>()) {
      await Get.find<LibraryService>().refreshAll();
    }
    return count;
  }

  void _notify(String title, String message) {
    if (Get.context != null) {
      try {
        Get.snackbar(
          title,
          message,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      } catch (_) {}
    }
  }
}
