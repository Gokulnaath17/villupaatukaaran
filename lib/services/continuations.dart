import 'package:flutter/foundation.dart';
import 'music_service.dart';

/// Continuation handling for paginated Innertube responses
class Continuations {
  Continuations._();

  /// Get continuation token from response
  static String? getContinuationToken(Map<String, dynamic> data) {
    // Try various continuation paths
    final paths = [
      ['contents', 'sectionListRenderer', 'contents', -1, 'continuationItemRenderer', 'continuationEndpoint', 'continuationCommand', 'token'],
      ['contents', 'singleColumnBrowseResultsRenderer', 'tabs', 0, 'tabRenderer', 'content', 'sectionListRenderer', 'contents', -1, 'continuationItemRenderer', 'continuationEndpoint', 'continuationCommand', 'token'],
      ['continuationContents', 'sectionListContinuation', 'contents', -1, 'continuationItemRenderer', 'continuationEndpoint', 'continuationCommand', 'token'],
      ['onResponseReceivedCommands', 0, 'appendContinuationItemsAction', 'continuationItems', -1, 'continuationItemRenderer', 'continuationEndpoint', 'continuationCommand', 'token'],
    ];

    for (final path in paths) {
      final token = _getNestedValue(data, path);
      if (token is String && token.isNotEmpty) return token;
    }
    return null;
  }

  /// Get playlist continuation token
  static String? getPlaylistContinuationToken(Map<String, dynamic> data) {
    final paths = [
      ['contents', 'singleColumnMusicWatchNextResultsRenderer', 'tabbedRenderer', 'watchNextTabbedResultsRenderer', 'tabs', 0, 'tabRenderer', 'content', 'musicPlaylistShelfRenderer', 'continuations', 0, 'nextContinuationData', 'continuation'],
      ['contents', 'singleColumnMusicWatchNextResultsRenderer', 'playlist', 'playlist', 'contents', 'musicPlaylistShelfContinuation', 'continuations', 0, 'nextContinuationData', 'continuation'],
    ];

    for (final path in paths) {
      final token = _getNestedValue(data, path);
      if (token is String && token.isNotEmpty) return token;
    }
    return null;
  }

  /// Get section list continuation (for home, search, etc.)
  static String? getSectionListContinuation(Map<String, dynamic> data) {
    return _getNestedValue(data, [
      'contents', 'sectionListRenderer', 'contents', -1, 'continuationItemRenderer', 'continuationEndpoint', 'continuationCommand', 'token'
    ]);
  }

  /// Get music shelf continuation
  static String? getMusicShelfContinuation(Map<String, dynamic> data) {
    return _getNestedValue(data, [
      'contents', 'singleColumnBrowseResultsRenderer', 'tabs', 0, 'tabRenderer', 'content', 'sectionListRenderer', 'contents', -1, 'musicShelfRenderer', 'continuations', 0, 'nextContinuationData', 'continuation'
    ]);
  }

  /// Generic nested value getter
  static dynamic _getNestedValue(Map<String, dynamic> data, List<Object> path) {
    dynamic current = data;
    for (final key in path) {
      if (current == null) return null;
      if (current is Map) {
        current = current[key];
      } else if (current is List) {
        if (key is int) {
          final index = key < 0 ? current.length + key : key;
          if (index >= 0 && index < current.length) {
            current = current[index];
          } else {
            return null;
          }
        } else {
          return null;
        }
      } else {
        return null;
      }
    }
    return current;
  }

  /// Fetch next page of results
  static Future<Map<String, dynamic>?> fetchNext({
    required MusicService musicService,
    required String continuation,
    required String browseId,
    Map<String, dynamic>? additionalParams,
  }) async {
    try {
      final response = await musicService.post('next', {
        'continuation': continuation,
        'browseId': browseId,
        if (additionalParams != null) ...additionalParams,
      });

      if (response.data != null) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Continuation fetch error: $e');
    }
    return null;
  }

  /// Fetch all pages until exhausted or limit reached
  static Future<List<Map<String, dynamic>>> fetchAllPages({
    required MusicService musicService,
    required String initialContinuation,
    required String browseId,
    required List<Map<String, dynamic>> Function(Map<String, dynamic>) parseItems,
    Map<String, dynamic>? additionalParams,
    int maxPages = 10,
  }) async {
    final allItems = <Map<String, dynamic>>[];
    String? continuation = initialContinuation;
    int pagesFetched = 0;

    while (continuation != null && pagesFetched < maxPages) {
      final pageData = await fetchNext(
        musicService: musicService,
        continuation: continuation,
        browseId: browseId,
        additionalParams: additionalParams,
      );

      if (pageData == null) break;

      final items = parseItems(pageData);
      if (items.isEmpty) break;

      allItems.addAll(items);

      // Get next continuation
      continuation = getContinuationToken(pageData) ?? getPlaylistContinuationToken(pageData);
      pagesFetched++;
    }

    return allItems;
  }
}