import 'package:audio_service/audio_service.dart';

/// Representation of a song across the application
class SongItem {
  final String videoId;
  final String title;
  final String artist;
  final String? album;
  final String? duration;
  final int durationSeconds;
  final String? thumbnailUrl;
  final String? highResThumbnail;
  final String? url;
  final bool isCached;
  final bool isDownloaded;
  final bool isLiked;

  const SongItem({
    required this.videoId,
    required this.title,
    this.artist = 'Unknown Artist',
    this.album,
    this.duration,
    this.durationSeconds = 0,
    this.thumbnailUrl,
    this.highResThumbnail,
    this.url,
    this.isCached = false,
    this.isDownloaded = false,
    this.isLiked = false,
  });

  SongItem copyWith({
    String? videoId,
    String? title,
    String? artist,
    String? album,
    String? duration,
    int? durationSeconds,
    String? thumbnailUrl,
    String? highResThumbnail,
    String? url,
    bool? isCached,
    bool? isDownloaded,
    bool? isLiked,
  }) {
    return SongItem(
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      highResThumbnail: highResThumbnail ?? this.highResThumbnail,
      url: url ?? this.url,
      isCached: isCached ?? this.isCached,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isLiked: isLiked ?? this.isLiked,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'durationSeconds': durationSeconds,
      'thumbnailUrl': thumbnailUrl,
      'highResThumbnail': highResThumbnail,
      'url': url,
      'isCached': isCached,
      'isDownloaded': isDownloaded,
      'isLiked': isLiked,
    };
  }

  factory SongItem.fromJson(Map<dynamic, dynamic> json) {
    return SongItem(
      videoId: (json['videoId'] ?? json['id'] ?? '') as String,
      title: (json['title'] ?? 'Unknown') as String,
      artist: (json['artist'] ?? json['artists'] ?? 'Unknown Artist') is List
          ? ((json['artist'] ?? json['artists']) as List)
              .map((e) => e is Map ? (e['name'] ?? '') : e.toString())
              .join(', ')
          : (json['artist'] ?? 'Unknown Artist').toString(),
      album: json['album']?.toString(),
      duration: json['duration']?.toString(),
      durationSeconds: (json['durationSeconds'] ?? 0) is int
          ? json['durationSeconds'] as int
          : int.tryParse(json['durationSeconds']?.toString() ?? '0') ?? 0,
      thumbnailUrl: json['thumbnailUrl']?.toString() ??
          (json['thumbnail'] is Map ? json['thumbnail']['url']?.toString() : null),
      highResThumbnail: json['highResThumbnail']?.toString(),
      url: json['url']?.toString(),
      isCached: json['isCached'] == true,
      isDownloaded: json['isDownloaded'] == true,
      isLiked: json['isLiked'] == true,
    );
  }

  /// Create from Innertube parsed map
  factory SongItem.fromInnertube(Map<String, dynamic> map) {
    String artistName = 'Unknown Artist';
    if (map['artists'] is List && (map['artists'] as List).isNotEmpty) {
      artistName = (map['artists'] as List)
          .map((a) => a is Map ? (a['name'] ?? '') : a.toString())
          .where((s) => s.toString().isNotEmpty)
          .join(', ');
    } else if (map['subtitle'] != null) {
      artistName = map['subtitle'].toString();
    }

    String? thumbUrl;
    if (map['thumbnail'] is Map) {
      thumbUrl = map['thumbnail']['url']?.toString();
    } else if (map['thumbnails'] is List && (map['thumbnails'] as List).isNotEmpty) {
      thumbUrl = map['thumbnails'].last['url']?.toString();
    }

    final vidId = (map['videoId'] ?? map['id'] ?? '') as String;
    // Fallback high res thumbnail
    final highThumb = thumbUrl ?? 'https://i.ytimg.com/vi/$vidId/hqdefault.jpg';

    return SongItem(
      videoId: vidId,
      title: (map['title'] ?? 'Unknown Track').toString(),
      artist: artistName.isEmpty ? 'Unknown Artist' : artistName,
      album: map['album']?.toString(),
      duration: map['duration']?.toString(),
      durationSeconds: (map['durationSeconds'] as int?) ?? 0,
      thumbnailUrl: thumbUrl ?? highThumb,
      highResThumbnail: highThumb,
      url: map['url']?.toString(),
    );
  }

  /// Convert to audio_service MediaItem
  MediaItem toMediaItem() {
    return MediaItem(
      id: videoId,
      title: title,
      artist: artist,
      album: album,
      duration: Duration(seconds: durationSeconds),
      artUri: thumbnailUrl != null ? Uri.tryParse(thumbnailUrl!) : null,
      extras: {
        'highResThumbnail': highResThumbnail,
        'url': url,
        'isCached': isCached,
        'isDownloaded': isDownloaded,
        'isLiked': isLiked,
      },
    );
  }

  /// Convert from audio_service MediaItem
  factory SongItem.fromMediaItem(MediaItem item) {
    final extras = item.extras ?? {};
    return SongItem(
      videoId: item.id,
      title: item.title,
      artist: item.artist ?? 'Unknown Artist',
      album: item.album,
      durationSeconds: item.duration?.inSeconds ?? 0,
      duration: item.duration != null
          ? '${item.duration!.inMinutes}:${(item.duration!.inSeconds % 60).toString().padLeft(2, '0')}'
          : null,
      thumbnailUrl: item.artUri?.toString(),
      highResThumbnail: extras['highResThumbnail']?.toString(),
      url: extras['url']?.toString(),
      isCached: extras['isCached'] == true,
      isDownloaded: extras['isDownloaded'] == true,
      isLiked: extras['isLiked'] == true,
    );
  }
}

