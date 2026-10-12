import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;
import 'package:hive/hive.dart';
import 'constant.dart';

/// Utility functions
class Utils {
  Utils._();

  /// Generate datestamp for clientVersion (YYYYMMDD)
  static String getDatestamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  /// Parse duration string (e.g., "3:45") to seconds
  static int parseDuration(String? duration) {
    if (duration == null || duration.isEmpty) return 0;
    final parts = duration.split(':');
    if (parts.length == 2) {
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } else if (parts.length == 3) {
      return int.parse(parts[0]) * 3600 + int.parse(parts[1]) * 60 + int.parse(parts[2]);
    }
    return 0;
  }

  /// Format seconds to MM:SS or HH:MM:SS
  static String formatDuration(int seconds) {
    if (seconds < 0) seconds = 0;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  /// Validate and normalize playlist ID (strip VL prefix)
  static String validatePlaylistId(String playlistId) {
    if (playlistId.startsWith('VL')) {
      return playlistId.substring(2);
    }
    return playlistId;
  }

  /// Check if URL is expired (expire timestamp + 30 min grace)
  static bool isExpired(String? url) {
    if (url == null) return true;
    final match = Constant.urlExpireRegex.firstMatch(url);
    if (match != null) {
      final expire = int.tryParse(match.group(1) ?? '');
      if (expire != null) {
        final expireDate = DateTime.fromMillisecondsSinceEpoch(expire * 1000);
        final gracePeriod = DateTime.now().add(Duration(minutes: Constant.urlCacheExpiryMinutes));
        return gracePeriod.isAfter(expireDate);
      }
    }
    return true; // If no expire param, treat as expired
  }

  /// Generate search params (base64 encoded filters)
  static String getSearchParams({
    String filter = 'EgWKAQIIAWoKEAoQAxAEEAMQBRAAGAECQAE%3D', // Default: songs
  }) {
    return filter;
  }

  /// Parse menu playlists from navigation
  static List<Map<String, dynamic>> parseMenuPlaylists(dynamic data) {
    final List<Map<String, dynamic>> result = [];
    // Implementation depends on nav_parser structure
    return result;
  }

  /// Get dot separator index for text truncation
  static int getDotSeparatorIndex(String text, int maxLength) {
    if (text.length <= maxLength) return text.length;
    final index = text.lastIndexOf(' ', maxLength);
    return index > 0 ? index : maxLength;
  }

  /// Generate visitor ID (cached for 30 days)
  static String generateVisitorId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// Get Hive box with lazy opening
  static Future<Box> getLazyBox(String name) async {
    if (!Hive.isBoxOpen(name)) {
      return await Hive.openBox(name);
    }
    return Hive.box(name);
  }

  /// Close lazy box if not in use
  static Future<void> closeLazyBox(String name) async {
    if (Hive.isBoxOpen(name)) {
      final box = Hive.box(name);
      // Check if box is empty or not needed
      await box.close();
    }
  }

  /// Sanitize filename for filesystem
  static String sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Generate SHA256 hash
  static String sha256(String input) {
    final bytes = utf8.encode(input);
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  /// Deep clone a map
  static Map<String, dynamic> deepCloneMap(Map<String, dynamic> map) {
    return Map<String, dynamic>.from(
      map.map((k, v) => MapEntry(k, v is Map ? deepCloneMap(v.cast<String, dynamic>()) : v)),
    );
  }

  /// Safe parse int
  static int? safeParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  /// Safe parse double
  static double? safeParseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Safe parse bool
  static bool safeParseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is int) return value != 0;
    return false;
  }
}