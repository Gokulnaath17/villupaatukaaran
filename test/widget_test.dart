import 'package:flutter_test/flutter_test.dart';
import 'package:villupaatukaaran/models/song_item.dart';
import 'package:villupaatukaaran/models/playlist_item.dart';
import 'package:villupaatukaaran/services/nav_parser.dart';
import 'package:villupaatukaaran/services/utils.dart';

void main() {
  group('SongItem & PlaylistItem Unit Tests', () {
    test('SongItem JSON serialization and deserialization roundtrip', () {
      const song = SongItem(
        videoId: 'test_vid_123',
        title: 'Villu Paatu Intro',
        artist: 'Traditional Bard',
        album: 'Folk Heritage',
        duration: '3:35',
        durationSeconds: 215,
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );

      final json = song.toJson();
      final restored = SongItem.fromJson(json);

      expect(restored.videoId, 'test_vid_123');
      expect(restored.title, 'Villu Paatu Intro');
      expect(restored.artist, 'Traditional Bard');
      expect(restored.album, 'Folk Heritage');
      expect(restored.duration, '3:35');
      expect(restored.durationSeconds, 215);
      expect(restored.thumbnailUrl, 'https://example.com/thumb.jpg');
    });

    test('SongItem MediaItem mapping roundtrip', () {
      const song = SongItem(
        videoId: 'vid_456',
        title: 'Southern Strings',
        artist: 'Urumi Melam',
        album: 'Live Session',
        duration: '3:00',
        durationSeconds: 180,
      );

      final mediaItem = song.toMediaItem();
      expect(mediaItem.id, 'vid_456');
      expect(mediaItem.title, 'Southern Strings');
      expect(mediaItem.artist, 'Urumi Melam');
      expect(mediaItem.duration?.inSeconds, 180);

      final fromMedia = SongItem.fromMediaItem(mediaItem);
      expect(fromMedia.videoId, 'vid_456');
      expect(fromMedia.title, 'Southern Strings');
      expect(fromMedia.artist, 'Urumi Melam');
      expect(fromMedia.durationSeconds, 180);
    });

    test('PlaylistItem JSON roundtrip', () {
      final playlist = PlaylistItem(
        id: 'pl_001',
        title: 'Top Tamil Folk',
        songCount: 15,
        isCustom: true,
      );

      final json = playlist.toJson();
      final restored = PlaylistItem.fromJson(json);

      expect(restored.id, 'pl_001');
      expect(restored.title, 'Top Tamil Folk');
      expect(restored.songCount, 15);
      expect(restored.isCustom, true);
    });
  });

  group('Nav Parser Unit Tests', () {
    test('Safe traversal with valid and missing keys', () {
      final sampleData = {
        'contents': {
          'sectionListRenderer': {
            'contents': [
              {
                'title': {'runs': [{'text': 'Quick Picks'}]}
              }
            ]
          }
        }
      };

      final nav = Nav.of(sampleData);
      expect(
        nav.string(['contents', 'sectionListRenderer', 'contents', 0, 'title', 'runs', 0, 'text']),
        'Quick Picks',
      );
      expect(nav.string(['contents', 'nonExistent', 'path']), isNull);
      expect(nav.stringOrEmpty(['contents', 'missing']), '');
    });

    test('Nav listNav and integer parsing', () {
      final sample = {
        'items': [
          {'id': '1', 'count': 42},
          {'id': '2', 'count': '99'},
        ]
      };

      final nav = Nav.of(sample);
      final items = nav.listNav(['items']);
      expect(items.length, 2);
      expect(items[0].integer(['count']), 42);
      expect(items[1].integer(['count']), 99);
    });
  });

  group('Utils Unit Tests', () {
    test('parseDuration formats duration strings accurately', () {
      expect(Utils.parseDuration('3:45'), 225);
      expect(Utils.parseDuration('1:02:15'), 3735);
      expect(Utils.parseDuration(''), 0);
      expect(Utils.parseDuration(null), 0);
    });

    test('formatDuration formats seconds accurately', () {
      expect(Utils.formatDuration(225), '3:45');
      expect(Utils.formatDuration(3735), '1:02:15');
      expect(Utils.formatDuration(0), '0:00');
    });

    test('validatePlaylistId removes VL prefix', () {
      expect(Utils.validatePlaylistId('VLPL12345'), 'PL12345');
      expect(Utils.validatePlaylistId('PL12345'), 'PL12345');
    });

    test('sha256 generates deterministic hash', () {
      final hash1 = Utils.sha256('villupaatukaaran');
      final hash2 = Utils.sha256('villupaatukaaran');
      expect(hash1, hash2);
      expect(hash1.length, 64);
    });
  });
}
