import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:get/get.dart' hide Response;
import 'constant.dart';
import 'utils.dart';
import 'nav_parser.dart';

/// Main service for Innertube API communication
class MusicService extends GetxService {
  late Dio _dio;
  late Box _prefsBox;
  String _visitorId = '';
  int _signatureTimestamp = 0;
  String _clientVersion = '';
  String _hlCode = 'en';

  /// Initialize service
  Future<MusicService> init() async {
    _prefsBox = Hive.box(Constant.boxAppPrefs);

    // Load or generate visitorId (cached for 30 days)
    final visitorData = _prefsBox.get('visitorId');
    final visitorTime = _prefsBox.get('visitorIdTime', defaultValue: 0) as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    const thirtyDays = 30 * 24 * 60 * 60 * 1000;

    if (visitorData != null && (now - visitorTime) < thirtyDays) {
      _visitorId = visitorData as String;
    } else {
      _visitorId = Utils.generateVisitorId();
      await _prefsBox.put('visitorId', _visitorId);
      await _prefsBox.put('visitorIdTime', now);
    }

    // Generate client version (date-based)
    _clientVersion = '1.${Utils.getDatestamp()}.01.00';

    // Signature timestamp (days since epoch - 1)
    _signatureTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ (24 * 60 * 60 * 1000)) - 1;

    // Language code
    _hlCode = _prefsBox.get(Constant.prefCurrentAppLanguageCode, defaultValue: 'en') as String;

    // Setup Dio
    _dio = Dio(BaseOptions(
      baseUrl: Constant.innertubeBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent': Constant.innertubeUserAgent,
        'Origin': Constant.innertubeOrigin,
        'Cookie': Constant.innertubeCookie,
        'X-Goog-Visitor-Id': _visitorId,
        'Content-Type': 'application/json',
      },
    ));

    // Add interceptors for logging
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => debugPrint('[MusicService] $obj'),
    ));

    return this;
  }

  /// Build request context
  Map<String, dynamic> _buildContext({Map<String, dynamic>? additional}) {
    return {
      'context': {
        'client': {
          'clientName': Constant.innertubeClientName,
          'clientVersion': _clientVersion,
          'hl': _hlCode,
          'gl': 'US',
          'timeZone': 'UTC',
          'utcOffsetMinutes': 0,
        },
        'user': {},
        'request': {
          'useSsl': true,
          'internalExperimentFlags': [],
        },
        if (additional != null) ...additional,
      },
    };
  }

  /// Send POST request to Innertube
  Future<Response> post(String action, Map<String, dynamic> data) {
    final context = _buildContext();
    final body = {...context, ...data};

    final url = '$action?prettyPrint=false&alt=json&key=${Constant.innertubeApiKey}';

    return _dio.post(url, data: body);
  }

  /// Send POST with signature timestamp
  Future<Response> postWithSignature(String action, Map<String, dynamic> data) {
    final context = _buildContext(additional: {
      'playbackContext': {
        'contentPlaybackContext': {
          'signatureTimestamp': _signatureTimestamp,
        },
      },
    });
    final body = {...context, ...data};

    final url = '$action?prettyPrint=false&alt=json&key=${Constant.innertubeApiKey}';

    return _dio.post(url, data: body);
  }

  // ========== Home ==========

  /// Get home screen data
  Future<Map<String, dynamic>> getHome({int limit = 30}) async {
    final response = await post('browse', {
      'browseId': 'FEmusic_home',
      'params': 'EgYIBhABGAE%3D',
    });

    if (response.data != null) {
      return NavParser.parseHome(response.data as Map<String, dynamic>);
    }
    return {'quickPicks': [], 'middle': [], 'fixed': []};
  }

  // ========== Watch Playlist (Queue/Radio) ==========

  /// Get watch playlist for video/playlist/radio
  Future<Map<String, dynamic>> getWatchPlaylist({
    String? videoId,
    String? playlistId,
    bool radio = false,
    bool shuffle = false,
    String? params,
  }) async {
    final data = <String, dynamic>{
      'playlistId': playlistId,
      'videoId': videoId,
      'params': params ?? (radio ? 'wAEB' : (shuffle ? 'wAEB8gECKAE%3D' : '')),
      'enablePersistentPlaylistPanel': true,
      'isRadio': radio,
      'radioLocation': radio ? 'WATCH_NEXT' : null,
    };

    data.removeWhere((key, value) => value == null);

    final response = await postWithSignature('next', data);

    if (response.data != null) {
      return NavParser.parseWatchPlaylist(response.data as Map<String, dynamic>);
    }
    return {'tracks': [], 'playlistId': '', 'lyricsBrowseId': null, 'related': [], 'additionalParamsForNext': null};
  }

  /// Get playlist or album songs
  Future<Map<String, dynamic>> getPlaylistOrAlbumSongs({
    required String browseId,
    String? playlistId,
    String? params,
    int limit = 100,
  }) async {
    final data = <String, dynamic>{
      'browseId': browseId,
      'params': params,
    };
    data.removeWhere((key, value) => value == null);

    final response = await post('browse', data);

    if (response.data != null) {
      final parsed = NavParser.parsePlaylist(response.data as Map<String, dynamic>);
      return parsed;
    }
    return {};
  }

  // ========== Search ==========

  /// Search query with Innertube and automatic yt-dlp fallback
  Future<Map<String, dynamic>> search({
    required String query,
    String? params,
    String? continuation,
  }) async {
    // Default to Innertube Songs chip if no custom params passed
    final searchParams = params ?? 'Eg-KAQwIABAAGAEgASgB';
    try {
      final data = <String, dynamic>{
        'query': query,
        'params': searchParams,
      };
      if (continuation != null) {
        data['continuation'] = continuation;
      }

      final response = await post('search', data);
      if (response.data != null) {
        final parsed = NavParser.parseSearch(response.data as Map<String, dynamic>);
        final results = parsed['results'] as List? ?? [];
        if (results.isNotEmpty) {
          return parsed;
        }
      }
    } catch (e) {
      debugPrint('[MusicService] Innertube search exception: $e');
    }

    // Fallback to yt-dlp search
    debugPrint('[MusicService] Falling back to yt-dlp search for "$query"');
    final ytdlpResults = await searchWithYtDlp(query);
    return {
      'chips': ['Songs'],
      'results': ytdlpResults,
      'continuation': null,
    };
  }

  /// Search directly with yt-dlp filtering for music tracks
  Future<List<Map<String, dynamic>>> searchWithYtDlp(String query) async {
    try {
      final ytdlpPath = await findYtDlpPath();
      if (ytdlpPath == null) return [];

      final searchQuery = query.toLowerCase().contains('song') || query.toLowerCase().contains('music')
          ? query
          : '$query song';

      final res = await Process.run(ytdlpPath, [
        '--no-warnings',
        '-j',
        '--flat-playlist',
        '--default-search',
        'ytsearch25:',
        searchQuery,
      ]);

      if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
        final lines = res.stdout.toString().trim().split('\n');
        final items = <Map<String, dynamic>>[];
        final seenIds = <String>{};

        for (final line in lines) {
          try {
            if (!line.trim().startsWith('{')) continue;
            final json = jsonDecode(line) as Map<String, dynamic>;
            final id = json['id']?.toString() ?? '';
            final title = json['title']?.toString() ?? '';
            final durationSec = json['duration'] is int
                ? json['duration'] as int
                : (json['duration'] is num ? (json['duration'] as num).toInt() : 0);

            // Filter out very long compilations (> 20 min) unless explicitly requested
            final isLongComp = durationSec > 1200 && !query.toLowerCase().contains('jukebox');

            if (id.isNotEmpty && title.isNotEmpty && !seenIds.contains(id) && !isLongComp) {
              seenIds.add(id);
              final channel = json['channel']?.toString() ?? json['uploader']?.toString() ?? 'Artist';
              final duration = json['duration_string']?.toString() ?? '3:30';
              String thumb = 'https://i.ytimg.com/vi/$id/hqdefault.jpg';
              if (json['thumbnails'] is List && (json['thumbnails'] as List).isNotEmpty) {
                thumb = (json['thumbnails'] as List).last['url']?.toString() ?? thumb;
              }
              items.add({
                'type': 'song',
                'videoId': id,
                'title': title,
                'artists': [{'name': channel}],
                'duration': duration,
                'durationSeconds': durationSec > 0 ? durationSec : Utils.parseDuration(duration),
                'thumbnail': {'url': thumb, 'width': 544, 'height': 544},
              });
            }
          } catch (_) {}
        }
        return items;
      }
    } catch (e) {
      debugPrint('[MusicService] yt-dlp search error: $e');
    }
    return [];
  }

  /// Locate yt-dlp binary
  static Future<String?> findYtDlpPath() async {
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

  /// Get search suggestions
  Future<List<String>> getSearchSuggestion(String query) async {
    final response = await post('music/get_search_suggestions', {
      'input': query,
      'clientContext': {
        'clientName': Constant.innertubeClientName,
        'clientVersion': _clientVersion,
      },
    });

    if (response.data != null) {
      final nav = Nav.of(response.data);
      return nav.listString(['contents', 0, 'searchSuggestionsRenderer', 'contents']);
    }
    return [];
  }

  // ========== Artist ==========

  /// Get artist detail
  Future<Map<String, dynamic>> getArtist(String browseId) async {
    final response = await post('browse', {
      'browseId': browseId,
    });

    if (response.data != null) {
      return NavParser.parseArtist(response.data as Map<String, dynamic>);
    }
    return {};
  }

  /// Get artist related content
  Future<Map<String, dynamic>> getArtistRelatedContent(String browseId) async {
    final response = await post('browse', {
      'browseId': browseId,
      'params': 'EgYKAxgBGAE%3D', // Related content params
    });

    if (response.data != null) {
      // Parse related content
      return {'related': [], 'albums': [], 'singles': []};
    }
    return {'related': [], 'albums': [], 'singles': []};
  }

  // ========== Charts ==========

  /// Get charts
  Future<Map<String, dynamic>> getCharts() async {
    final response = await post('browse', {
      'browseId': 'FEmusic_charts',
    });

    if (response.data != null) {
      return NavParser.parseHome(response.data as Map<String, dynamic>);
    }
    return {};
  }

  // ========== Related ==========

  /// Get content related to song
  Future<List<Map<String, dynamic>>> getContentRelatedToSong(String videoId) async {
    final response = await post('next', {
      'videoId': videoId,
      'params': 'wAEB8gECKAE%3D',
    });

    if (response.data != null) {
      final parsed = NavParser.parseWatchPlaylist(response.data as Map<String, dynamic>);
      return parsed['tracks'] as List<Map<String, dynamic>>? ?? [];
    }
    return [];
  }

  // ========== Lyrics ==========

  /// Get lyrics by browseId
  Future<Map<String, dynamic>> getLyrics(String browseId) async {
    final response = await post('browse', {
      'browseId': browseId,
    });

    if (response.data != null) {
      return NavParser.parseLyrics(response.data as Map<String, dynamic>);
    }
    return {'syncedLyrics': null, 'plainLyrics': null};
  }

  // ========== Song Year ==========

  /// Get song year from player endpoint
  Future<int?> getSongYear(String videoId) async {
    final response = await post('player', {
      'videoId': videoId,
    });

    if (response.data != null) {
      final nav = Nav.of(response.data);
      final yearStr = nav.string(['playabilityStatus', 'contextParams', 'publishDate']);
      if (yearStr != null) {
        return int.tryParse(yearStr.split('-').first);
      }
    }
    return null;
  }

  // ========== Song Detail ==========

  /// Get song with ID (player endpoint -> music check -> watchPlaylist)
  Future<Map<String, dynamic>?> getSongWithId(String videoId) async {
    // Try player endpoint first
    final playerResponse = await post('player', {
      'videoId': videoId,
    });

    if (playerResponse.data != null) {
      final nav = Nav.of(playerResponse.data);
      if (nav.string(['playabilityStatus', 'status']) == 'OK') {
        // Get full details from watchPlaylist
        return getWatchPlaylist(videoId: videoId);
      }
    }

    // Fallback to watchPlaylist
    return getWatchPlaylist(videoId: videoId);
  }

  // ========== Helpers ==========

  /// Update client version (call periodically)
  void updateClientVersion() {
    _clientVersion = '1.${Utils.getDatestamp()}.01.00';
  }

  /// Update signature timestamp
  void updateSignatureTimestamp() {
    _signatureTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ (24 * 60 * 60 * 1000)) - 1;
  }

  /// Update language
  void updateLanguage(String langCode) {
    _hlCode = langCode;
  }

  /// Refresh visitor ID
  Future<void> refreshVisitorId() async {
    _visitorId = Utils.generateVisitorId();
    await _prefsBox.put('visitorId', _visitorId);
    await _prefsBox.put('visitorIdTime', DateTime.now().millisecondsSinceEpoch);
    _dio.options.headers['X-Goog-Visitor-Id'] = _visitorId;
  }
}