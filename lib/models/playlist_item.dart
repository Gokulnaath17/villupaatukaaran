import 'song_item.dart';

/// Representation of a playlist or album container
class PlaylistItem {
  final String id;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final int songCount;
  final List<SongItem> songs;
  final bool isCustom;

  const PlaylistItem({
    required this.id,
    required this.title,
    this.description,
    this.thumbnailUrl,
    this.songCount = 0,
    this.songs = const [],
    this.isCustom = true,
  });

  PlaylistItem copyWith({
    String? id,
    String? title,
    String? description,
    String? thumbnailUrl,
    int? songCount,
    List<SongItem>? songs,
    bool? isCustom,
  }) {
    return PlaylistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      songCount: songCount ?? this.songCount,
      songs: songs ?? this.songs,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'songCount': songCount,
      'songs': songs.map((s) => s.toJson()).toList(),
      'isCustom': isCustom,
    };
  }

  factory PlaylistItem.fromJson(Map<dynamic, dynamic> json) {
    return PlaylistItem(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? 'Untitled Playlist') as String,
      description: json['description']?.toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      songCount: (json['songCount'] as int?) ??
          (json['songs'] is List ? (json['songs'] as List).length : 0),
      songs: json['songs'] is List
          ? (json['songs'] as List)
              .map((s) => SongItem.fromJson(s as Map<dynamic, dynamic>))
              .toList()
          : [],
      isCustom: json['isCustom'] == true,
    );
  }
}

