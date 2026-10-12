import 'utils.dart';

/// Safe navigation parser for Innertube JSON responses
/// Provides null-safe traversal of nested maps/lists
class Nav {
  final dynamic _data;

  Nav(this._data);

  /// Create Nav from dynamic data
  static Nav of(dynamic data) => Nav(data);

  /// Underlying raw data
  dynamic get raw => _data;

  /// Check if data is present and non-null
  bool get isPresent => _data != null;

  /// Get nested Nav object
  Nav nav(List<Object> path) => Nav(get(path));

  /// Get value at path, return null if not found
  dynamic get(List<Object> path, {dynamic defaultValue}) {
    if (path.isEmpty) return _data ?? defaultValue;
    dynamic current = _data;
    for (final key in path) {
      if (current == null) return defaultValue;
      if (current is Map) {
        current = current[key];
      } else if (current is List) {
        if (key is int && key >= 0 && key < current.length) {
          current = current[key];
        } else {
          return defaultValue;
        }
      } else {
        return defaultValue;
      }
    }
    return current ?? defaultValue;
  }

  /// Get string value
  String? string(List<Object> path) {
    final v = get(path);
    if (v is String) return v;
    return null;
  }

  /// Get int value
  int? integer(List<Object> path) {
    final v = get(path);
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    if (v is double) return v.toInt();
    return null;
  }

  /// Get double value
  double? doubleVal(List<Object> path) {
    final v = get(path);
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// Get bool value
  bool boolVal(List<Object> path) {
    final v = get(path);
    if (v is bool) return v;
    if (v is String) return v == 'true';
    if (v is int) return v != 0;
    return false;
  }

  /// Get list of maps
  List<Map<String, dynamic>> listMap(List<Object> path) {
    final v = get(path);
    if (v is List) {
      return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// Get list of strings
  List<String> listString(List<Object> path) {
    final v = get(path);
    if (v is List) {
      return v.whereType<String>().toList();
    }
    return [];
  }

  /// Get map
  Map<String, dynamic>? map(List<Object> path) {
    final v = get(path);
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  /// Get list of Nav objects
  List<Nav> listNav(List<Object> path) {
    final v = get(path);
    if (v is List) {
      return v.map((e) => Nav(e)).toList();
    }
    return [];
  }

  /// Get first item of list as Nav
  Nav? firstNav(List<Object> path) {
    final list = listNav(path);
    return list.isNotEmpty ? list.first : null;
  }

  /// Check if path exists and has value
  bool has(List<Object> path) {
    return get(path) != null;
  }

  /// Get as string or empty
  String stringOrEmpty(List<Object> path) => string(path) ?? '';

  /// Get as int or zero
  int intOrZero(List<Object> path) => integer(path) ?? 0;
}

/// Parser functions for specific Innertube response types
class NavParser {
  NavParser._();

  /// Parse home screen sections (quickPicks, middle, fixed)
  static Map<String, dynamic> parseHome(Map<String, dynamic> data) {
    final nav = Nav.of(data);
    final result = <String, dynamic>{
      'quickPicks': <dynamic>[],
      'middle': <dynamic>[],
      'fixed': <dynamic>[],
    };

    // Parse tabs/sections from browse response
    final tabs = nav.listNav(['contents', 'singleColumnBrowseResultsRenderer', 'tabs']);
    for (final tab in tabs) {
      final sections = tab.listNav(['tabRenderer', 'content', 'sectionListRenderer', 'contents']);
      for (final section in sections) {
        final title = section.string(['musicCarouselShelfRenderer', 'title', 'runs', 0, 'text']);
        final items = _parseMusicCarouselItems(section);

        if (title != null && title.toLowerCase().contains('quick pick')) {
          result['quickPicks'] = items;
        } else if (title != null && title.toLowerCase().contains('mood')) {
          result['middle'] = items;
        } else if (items.isNotEmpty) {
          result['fixed'] = items;
        }
      }
    }

    return result;
  }

  /// Parse music carousel shelf items
  static List<Map<String, dynamic>> _parseMusicCarouselItems(Nav section) {
    final items = <Map<String, dynamic>>[];
    final contents = section.listNav(['musicCarouselShelfRenderer', 'contents']);

    for (final item in contents) {
      final parsed = _parseSearchItem(item);
      if (parsed != null) items.add(parsed);
    }

    return items;
  }

  /// Parse musicTwoRowItemRenderer
  static Map<String, dynamic>? parseMusicTwoRowItem(Nav item) {
    final renderer = item.has(['musicTwoRowItemRenderer'])
        ? item.nav(['musicTwoRowItemRenderer'])
        : item;

    final title = renderer.string(['title', 'runs', 0, 'text']);
    final subtitle = renderer.string(['subtitle', 'runs', 0, 'text']);
    final thumbnail = _parseThumbnail(renderer.get(['thumbnail', 'musicThumbnailRenderer']));
    final browseId = renderer.string(['navigationEndpoint', 'browseEndpoint', 'browseId']);
    final params = renderer.string(['navigationEndpoint', 'browseEndpoint', 'params']);
    final videoId = renderer.string(['navigationEndpoint', 'watchEndpoint', 'videoId']);

    if (title == null) return null;

    return {
      'title': title,
      'subtitle': subtitle,
      'thumbnail': thumbnail,
      'browseId': browseId,
      'params': params,
      if (videoId != null) 'videoId': videoId,
    };
  }

  /// Parse thumbnail
  static Map<String, dynamic>? _parseThumbnail(dynamic data) {
    if (data == null) return null;
    final nav = Nav.of(data);
    List<Map<String, dynamic>> thumbnails = nav.listMap(['thumbnail', 'thumbnails']);
    if (thumbnails.isEmpty) {
      thumbnails = nav.listMap(['thumbnails']);
    }
    if (thumbnails.isEmpty && data is Map && data.containsKey('musicThumbnailRenderer')) {
      final inner = Nav.of(data['musicThumbnailRenderer']);
      thumbnails = inner.listMap(['thumbnail', 'thumbnails']);
      if (thumbnails.isEmpty) thumbnails = inner.listMap(['thumbnails']);
    }
    if (thumbnails.isEmpty && data is List) {
      thumbnails = data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (thumbnails.isEmpty) return null;

    // Get highest quality thumbnail
    final best = thumbnails.reduce((a, b) {
      final aw = a['width'] as int? ?? 0;
      final bw = b['width'] as int? ?? 0;
      return aw > bw ? a : b;
    });

    return {
      'url': best['url'] as String? ?? '',
      'width': best['width'] as int? ?? 0,
      'height': best['height'] as int? ?? 0,
    };
  }

  /// Parse watch playlist (queue/radio source)
  static Map<String, dynamic> parseWatchPlaylist(Map<String, dynamic> data) {
    final nav = Nav.of(data);
    final tracks = <Map<String, dynamic>>[];

    // Parse playlistPanelRenderer
    final items = nav.listNav([
      'contents',
      'singleColumnMusicWatchNextResultsRenderer',
      'tabbedRenderer',
      'watchNextTabbedResultsRenderer',
      'tabs',
      0,
      'tabRenderer',
      'content',
      'musicPlaylistShelfRenderer',
      'contents'
    ]);

    for (final item in items) {
      final track = parsePlaylistPanelItem(item);
      if (track != null) tracks.add(track);
    }

    // Get continuation params
    final continuation = nav.string([
      'contents',
      'singleColumnMusicWatchNextResultsRenderer',
      'tabbedRenderer',
      'watchNextTabbedResultsRenderer',
      'tabs',
      0,
      'tabRenderer',
      'content',
      'musicPlaylistShelfRenderer',
      'continuations',
      0,
      'nextContinuationData',
      'continuation'
    ]);

    return {
      'tracks': tracks,
      'playlistId': nav.string(['playlistId']),
      'lyricsBrowseId': nav.string(['lyrics', 'browseId']),
      'related': <dynamic>[],
      'additionalParamsForNext': continuation,
    };
  }

  /// Parse playlist panel item
  static Map<String, dynamic>? parsePlaylistPanelItem(Nav item) {
    final nav = item.has(['playlistPanelVideoRenderer'])
        ? item.nav(['playlistPanelVideoRenderer'])
        : (item.has(['musicPlaylistItemRenderer'])
            ? item.nav(['musicPlaylistItemRenderer'])
            : item);

    final videoId = nav.string(['videoId']) ??
        nav.string(['navigationEndpoint', 'watchEndpoint', 'videoId']);
    if (videoId == null) return null;

    final title = nav.string(['title', 'runs', 0, 'text']);
    final artists = _parseArtists(nav.listNav(['longBylineText', 'runs']));
    final album = nav.string(['bylineText', 'runs', 0, 'text']);
    final duration = nav.string([
          'fixedColumns',
          0,
          'musicFixedColumnItemRenderer',
          'text',
          'runs',
          0,
          'text'
        ]) ??
        nav.string(['lengthText', 'runs', 0, 'text']);
    final thumbnail = _parseThumbnail(
      nav.get(['thumbnail', 'musicThumbnailRenderer']) ?? nav.get(['thumbnail', 'thumbnails']),
    );

    return {
      'videoId': videoId,
      'title': title ?? '',
      'artists': artists,
      'album': album,
      'duration': duration,
      'durationSeconds': Utils.parseDuration(duration),
      'thumbnail': thumbnail,
      'isAvailable': !nav.boolVal(['unplayableText']),
    };
  }

  /// Parse artist runs
  static List<Map<String, dynamic>> _parseArtists(List<Nav> runs) {
    final list = runs
        .where((r) => r.has(['navigationEndpoint', 'browseEndpoint']))
        .map((r) => {
              'name': r.string(['text']),
              'browseId': r.string(['navigationEndpoint', 'browseEndpoint', 'browseId']),
            })
        .where((a) {
          final name = a['name'];
          if (name == null || name.isEmpty) return false;
          final browseId = a['browseId'] ?? '';
          if (browseId.startsWith('MPRE') || browseId.startsWith('VL')) return false;
          return true;
        })
        .toList();

    if (list.isNotEmpty) return list;

    // Fallback: extract valid artist text from runs
    for (final r in runs) {
      final t = r.string(['text'])?.trim();
      if (t == null || t.isEmpty) continue;
      if (t == '•' || t == '·' || t == '|' || t == '/') continue;
      final lower = t.toLowerCase();
      if (lower == 'song' || lower == 'video' || lower == 'album' || lower == 'single' || lower == 'ep') continue;
      if (RegExp(r'^\d+:\d+$').hasMatch(t)) continue;
      if (RegExp(r'^\d+(\.\d+)?[KM]?\s*(views|plays)?$').hasMatch(t)) continue;
      return [{'name': t}];
    }
    return [];
  }

  /// Parse search results
  static Map<String, dynamic> parseSearch(Map<String, dynamic> data) {
    final nav = Nav.of(data);
    final results = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    // Recursively collect all song items across all sections and tabs
    _collectRenderers(data, results, seenIds);

    // Get continuation token if any
    final continuation = nav.string([
          'continuationContents',
          'sectionListContinuation',
          'continuations',
          0,
          'nextContinuationData',
          'continuation'
        ]) ??
        nav.string([
          'contents',
          'sectionListRenderer',
          'continuations',
          0,
          'nextContinuationData',
          'continuation'
        ]);

    return {
      'chips': <String>['Songs', 'Featured'],
      'results': results,
      'continuation': continuation,
    };
  }

  /// Recursively collect all song renderers
  static void _collectRenderers(dynamic node, List<Map<String, dynamic>> results, Set<String> seenIds) {
    if (node == null) return;
    if (node is Map) {
      if (node.containsKey('musicResponsiveListItemRenderer')) {
        final parsed = _parseResponsiveListItem(Nav.of(node['musicResponsiveListItemRenderer']));
        if (parsed != null && parsed['videoId'] != null && (parsed['videoId'] as String).isNotEmpty) {
          final id = parsed['videoId'] as String;
          if (!seenIds.contains(id)) {
            seenIds.add(id);
            results.add(parsed);
          }
        }
      }
      if (node.containsKey('musicCardShelfRenderer')) {
        final card = Nav.of(node['musicCardShelfRenderer']);
        final videoId = card.string(['title', 'runs', 0, 'navigationEndpoint', 'watchEndpoint', 'videoId']) ??
            card.string(['onTap', 'watchEndpoint', 'videoId']) ??
            card.string(['buttons', 0, 'buttonRenderer', 'command', 'watchEndpoint', 'videoId']);
        final title = card.string(['title', 'runs', 0, 'text']);
        final subtitle = card.string(['subtitle', 'runs', 0, 'text']);
        final thumb = _parseThumbnail(card.get(['thumbnail', 'musicThumbnailRenderer']));
        if (videoId != null && videoId.isNotEmpty && !seenIds.contains(videoId)) {
          seenIds.add(videoId);
          results.add({
            'type': 'song',
            'videoId': videoId,
            'title': title ?? '',
            'artists': [{'name': subtitle ?? 'Artist'}],
            'thumbnail': thumb,
          });
        }
      }
      for (final value in node.values) {
        _collectRenderers(value, results, seenIds);
      }
    } else if (node is List) {
      for (final item in node) {
        _collectRenderers(item, results, seenIds);
      }
    }
  }

  /// Parse individual search item
  static Map<String, dynamic>? _parseSearchItem(Nav item) {
    if (item.has(['musicTwoRowItemRenderer'])) {
      return parseMusicTwoRowItem(item.nav(['musicTwoRowItemRenderer']));
    }
    if (item.has(['musicResponsiveListItemRenderer'])) {
      return _parseResponsiveListItem(item.nav(['musicResponsiveListItemRenderer']));
    }
    return null;
  }

  /// Parse musicResponsiveListItemRenderer
  static Map<String, dynamic>? _parseResponsiveListItem(Nav nav) {
    final videoId = nav.string(['playlistItemData', 'videoId']) ??
        nav.string(['navigationEndpoint', 'watchEndpoint', 'videoId']) ??
        nav.string(['overlay', 'musicItemThumbnailOverlayRenderer', 'content', 'musicPlayButtonRenderer', 'playNavigationEndpoint', 'watchEndpoint', 'videoId']) ??
        nav.string(['flexColumns', 0, 'musicResponsiveListItemFlexColumnRenderer', 'text', 'runs', 0, 'navigationEndpoint', 'watchEndpoint', 'videoId']) ??
        nav.string(['doubleTapCommand', 'watchEndpoint', 'videoId']);

    final playlistId = nav.string(['navigationEndpoint', 'browseEndpoint', 'browseId']);

    final title = nav.string([
          'flexColumns',
          0,
          'musicResponsiveListItemFlexColumnRenderer',
          'text',
          'runs',
          0,
          'text'
        ]) ??
        nav.string(['title', 'runs', 0, 'text']);

    var thumbnail = _parseThumbnail(
      nav.get(['thumbnail', 'musicThumbnailRenderer']) ??
          nav.get(['thumbnail', 'thumbnails']) ??
          nav.get(['thumbnail']),
    );

    if (videoId != null && videoId.isNotEmpty) {
      thumbnail ??= {
        'url': 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
        'width': 480,
        'height': 360,
      };

      final runs = nav.listNav([
        'flexColumns',
        1,
        'musicResponsiveListItemFlexColumnRenderer',
        'text',
        'runs'
      ]);

      List<Map<String, dynamic>> artists = _parseArtists(runs);
      if (artists.isEmpty) {
        artists = [{'name': 'Artist'}];
      }

      final durationText = nav.string([
            'fixedColumns',
            0,
            'musicFixedColumnItemRenderer',
            'text',
            'runs',
            0,
            'text'
          ]) ??
          (runs.length > 2 ? runs.last.string(['text']) : null);

      return {
        'type': 'song',
        'videoId': videoId,
        'title': title ?? '',
        'artists': artists,
        'duration': durationText,
        'durationSeconds': Utils.parseDuration(durationText),
        'thumbnail': thumbnail,
      };
    }

    if (playlistId != null && playlistId.startsWith('VL')) {
      return {
        'type': 'playlist',
        'playlistId': playlistId,
        'title': title ?? '',
        'thumbnail': thumbnail,
      };
    }

    return null;
  }

  /// Parse artist detail
  static Map<String, dynamic> parseArtist(Map<String, dynamic> data) {
    final nav = Nav.of(data);
    final header = nav.nav(['header', 'musicHeaderRenderer']);

    return {
      'name': header.string(['title', 'runs', 0, 'text']) ?? '',
      'browseId': nav.string(['browseId']),
      'subscribers': header.string(['subtitle', 'runs', 0, 'text']),
      'thumbnail': _parseThumbnail(header.get(['thumbnail', 'musicThumbnailRenderer'])),
      'description': header.string(['description', 'runs', 0, 'text']),
      'radioId': nav.string([
        'contents',
        'singleColumnBrowseResultsRenderer',
        'tabs',
        1,
        'tabRenderer',
        'content',
        'sectionListRenderer',
        'contents',
        0,
        'musicCarouselShelfRenderer',
        'navigationEndpoint',
        'browseEndpoint',
        'browseId'
      ]),
    };
  }

  /// Parse album detail
  static Map<String, dynamic> parseAlbum(Map<String, dynamic> data) {
    final nav = Nav.of(data);
    final header = nav.nav(['header', 'musicHeaderRenderer']);

    return {
      'browseId': nav.string(['browseId']),
      'audioPlaylistId': nav.string(['audioPlaylistId']),
      'title': header.string(['title', 'runs', 0, 'text']) ?? '',
      'artists': _parseArtists(nav.listNav(['header', 'musicHeaderRenderer', 'subtitle', 'runs'])),
      'year': header.string(['subtitle', 'runs', 2, 'text']),
      'description': header.string(['description', 'runs', 0, 'text']),
      'thumbnail': _parseThumbnail(header.get(['thumbnail', 'musicThumbnailRenderer'])),
      'songCount': nav.intOrZero([
        'contents',
        'singleColumnBrowseResultsRenderer',
        'tabs',
        0,
        'tabRenderer',
        'content',
        'sectionListRenderer',
        'contents',
        0,
        'musicShelfRenderer',
        'title',
        'runs',
        0,
        'text'
      ]),
    };
  }

  /// Parse playlist detail
  static Map<String, dynamic> parsePlaylist(Map<String, dynamic> data) {
    final nav = Nav.of(data);
    final header = nav.nav(['header', 'musicHeaderRenderer']);

    return {
      'playlistId': nav.string(['playlistId']),
      'title': header.string(['title', 'runs', 0, 'text']) ?? '',
      'thumbnail': _parseThumbnail(header.get(['thumbnail', 'musicThumbnailRenderer'])),
      'description': header.string(['description', 'runs', 0, 'text']),
      'songCount': nav.intOrZero([
        'contents',
        'singleColumnBrowseResultsRenderer',
        'tabs',
        0,
        'tabRenderer',
        'content',
        'sectionListRenderer',
        'contents',
        0,
        'musicShelfRenderer',
        'title',
        'runs',
        0,
        'text'
      ]),
      'isPipedPlaylist': false,
      'isCloudPlaylist': true,
    };
  }

  /// Parse lyrics
  static Map<String, dynamic> parseLyrics(Map<String, dynamic> data) {
    final nav = Nav.of(data);
    final segments = <Map<String, dynamic>>[];

    // Parse synced lyrics runs
    final runs = nav.listNav([
      'contents',
      'sectionListRenderer',
      'contents',
      0,
      'musicDescriptionShelfRenderer',
      'description',
      'runs'
    ]);
    for (final run in runs) {
      final text = run.string(['text']);
      final time = run.string(['navigationEndpoint', 'watchEndpoint', 'videoId']);
      if (text != null) {
        segments.add({'time': time, 'text': text});
      }
    }

    // Fallback to plain lyrics
    final plainLyrics = nav.string([
      'contents',
      'sectionListRenderer',
      'contents',
      0,
      'musicDescriptionShelfRenderer',
      'description',
      'runs',
      0,
      'text'
    ]);

    return {
      'syncedLyrics': segments.isNotEmpty ? segments : null,
      'plainLyrics': plainLyrics,
    };
  }

  /// Parse LRCLIB response
  static Map<String, dynamic> parseLrclib(Map<String, dynamic> data) {
    return {
      'syncedLyrics': data['syncedLyrics'],
      'plainLyrics': data['plainLyrics'],
    };
  }
}