import 'dart:async';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide StreamInfo;
import 'stream_service.dart';

/// Background task for stream resolution (runs in isolate)
class BackgroundTask {
  BackgroundTask._();

  /// Get stream info in background isolate
  static Future<HMStreamingData> getStreamInfo(String videoId, RootIsolateToken rootIsolateToken) async {
    // Initialize background isolate
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);

    final youtubeExplode = YoutubeExplode();
    try {
      final manifest = await youtubeExplode.videos.streamsClient.getManifest(videoId);
      final audioOnly = manifest.audioOnly.toList();

      youtubeExplode.close();

      if (audioOnly.isEmpty) {
        return HMStreamingData(
          playable: false,
          statusMsg: 'No audio streams found',
        );
      }

      // Sort by bitrate descending
      audioOnly.sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));

      // Find low and high quality
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

      return HMStreamingData(
        playable: true,
        statusMsg: 'OK',
        low: low,
        high: high,
        qualityIndex: 1, // High
      );
    } catch (e) {
      youtubeExplode.close();
      return HMStreamingData(
        playable: false,
        statusMsg: 'Error: $e',
      );
    }
  }
}

/// Entry point for isolate
Future<void> backgroundTaskEntryPoint(SendPort sendPort) async {
  final port = ReceivePort();
  sendPort.send(port.sendPort);

  await for (final message in port) {
    if (message is Map) {
      final requestId = message['requestId'] as int;
      final videoId = message['videoId'] as String;
      final token = message['rootIsolateToken'] as RootIsolateToken;
      final replyPort = message['responsePort'] as SendPort;

      try {
        final result = await BackgroundTask.getStreamInfo(videoId, token);
        replyPort.send({'requestId': requestId, 'data': result});
      } catch (e) {
        replyPort.send({'requestId': requestId, 'error': e.toString()});
      }
    }
  }
}

/// Helper to run stream fetch in isolate
class StreamIsolate {
  static Isolate? _isolate;
  static SendPort? _isolatePort;
  static ReceivePort? _responsePort;
  static final Map<int, Completer<HMStreamingData>> _pendingRequests = {};
  static int _requestId = 0;

  /// Initialize isolate
  static Future<void> init() async {
    if (_isolate != null) return;

    final initPort = ReceivePort();
    _isolate = await Isolate.spawn(backgroundTaskEntryPoint, initPort.sendPort);
    _isolatePort = await initPort.first as SendPort;

    // Listen for responses
    _responsePort = ReceivePort();
    _responsePort!.listen((message) {
      if (message is Map && message.containsKey('requestId')) {
        final requestId = message['requestId'] as int;
        final completer = _pendingRequests.remove(requestId);
        if (completer != null) {
          if (message['error'] != null) {
            completer.completeError(message['error'] as Object);
          } else {
            completer.complete(message['data'] as HMStreamingData);
          }
        }
      }
    });
  }

  /// Get stream info via isolate
  static Future<HMStreamingData> getStreamInfo(String videoId) async {
    if (_isolatePort == null) {
      await init();
    }

    final completer = Completer<HMStreamingData>();
    final requestId = _requestId++;
    _pendingRequests[requestId] = completer;

    _isolatePort!.send({
      'requestId': requestId,
      'videoId': videoId,
      'rootIsolateToken': RootIsolateToken.instance!,
      'responsePort': _responsePort!.sendPort,
    });

    return completer.future;
  }

  /// Dispose isolate
  static void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _isolatePort = null;
    _responsePort?.close();
    _responsePort = null;
    _pendingRequests.clear();
  }
}