import 'package:audio_service/audio_service.dart';
import 'song_item.dart';

/// Helper to build and map audio_service MediaItems
class MediaItemBuilder {
  MediaItemBuilder._();

  static MediaItem fromSong(SongItem song) => song.toMediaItem();

  static SongItem toSong(MediaItem item) => SongItem.fromMediaItem(item);

  static List<MediaItem> fromSongs(List<SongItem> songs) {
    return songs.map(fromSong).toList();
  }

  static List<SongItem> toSongs(List<MediaItem> items) {
    return items.map(toSong).toList();
  }
}

