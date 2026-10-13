import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/playlist_item.dart';
import '../../services/cache_service.dart';
import '../../services/download_service.dart';
import '../../services/library_service.dart';
import '../../services/player_controller.dart';
import '../../utils/app_assets.dart';
import '../theme/theme_controller.dart';
import '../widgets/boxy_card.dart';
import '../widgets/song_tile.dart';

/// Categories supported in the unified Library
enum LibraryCategory {
  all,
  downloaded,
  cached,
  local,
  liked,
  playlists,
}

/// Unified Library page supporting All, Downloaded, Cached, Local, Liked, and Playlists
class LibraryView extends StatefulWidget {
  final LibraryCategory initialCategory;
  final String? playlistId;

  const LibraryView({
    super.key,
    this.initialCategory = LibraryCategory.all,
    this.playlistId,
  });

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  late LibraryCategory _selectedCategory;
  PlaylistItem? _viewingPlaylist;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    if (Get.isRegistered<LibraryService>()) {
      Get.find<LibraryService>().refreshAll();
      _resolveInitialPlaylist();
    }
  }

  void _resolveInitialPlaylist() {
    if (widget.playlistId != null) {
      final playlists = Get.find<LibraryService>().playlists;
      final pl = playlists.firstWhereOrNull((p) => p.id == widget.playlistId);
      if (pl != null) {
        _viewingPlaylist = pl;
      }
    }
  }

  @override
  void didUpdateWidget(covariant LibraryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategory != widget.initialCategory || oldWidget.playlistId != widget.playlistId) {
      setState(() {
        _selectedCategory = widget.initialCategory;
        if (widget.playlistId != null) {
          final playlists = Get.find<LibraryService>().playlists;
          _viewingPlaylist = playlists.firstWhereOrNull((p) => p.id == widget.playlistId);
        } else if (_selectedCategory != LibraryCategory.playlists) {
          _viewingPlaylist = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryService = Get.find<LibraryService>();
    final playerController = Get.find<PlayerController>();

    return Obx(() {
      if (_viewingPlaylist != null) {
        return _buildPlaylistDetail(libraryService, playerController);
      }

      switch (_selectedCategory) {
        case LibraryCategory.all:
          return _buildAllSongsTab(libraryService, playerController);
        case LibraryCategory.downloaded:
          return _buildDownloadedSongsTab(libraryService, playerController);
        case LibraryCategory.cached:
          return _buildCachedSongsTab(libraryService, playerController);
        case LibraryCategory.local:
          return _buildLocalSongsTab(libraryService, playerController);
        case LibraryCategory.liked:
          return _buildLikedSongsTab(libraryService, playerController);
        case LibraryCategory.playlists:
          return _buildPlaylistsTab(libraryService);
      }
    });
  }


  // 1. ALL SONGS TAB
  Widget _buildAllSongsTab(LibraryService libraryService, PlayerController playerController) {
    final songs = libraryService.allSongs;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALL SONGS (${songs.length})',
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Combined library of liked, cached, downloaded, and local tracks',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
            if (songs.isNotEmpty)
              BoxyButton(
                label: 'PLAY ALL',
                icon: Icons.play_arrow_rounded,
                isPrimary: true,
                onPressed: () => playerController.playSong(songs.first, queueContext: songs),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (songs.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Your library is empty.\nExplore songs or play music to populate your library.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ),
          )
        else
          ...songs.asMap().entries.map((e) {
            return SongTile(
              song: e.value,
              showIndex: true,
              index: e.key,
              onTap: () => playerController.playSong(e.value, queueContext: songs, index: e.key),
            );
          }),
      ],
    );
  }

  // 2. DOWNLOADED TAB
  Widget _buildDownloadedSongsTab(LibraryService libraryService, PlayerController playerController) {
    final downloaded = libraryService.downloadedSongs;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DOWNLOADED SONGS (${downloaded.length})',
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Saved tracks available for permanently offline playback',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
            if (downloaded.isNotEmpty)
              BoxyButton(
                label: 'PLAY ALL',
                icon: Icons.play_arrow_rounded,
                isPrimary: true,
                onPressed: () => playerController.playSong(downloaded.first, queueContext: downloaded),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (downloaded.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No downloaded songs yet.\nUse the 3-dot menu on any song to save offline.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ),
          )
        else
          ...downloaded.asMap().entries.map((e) {
            return SongTile(
              song: e.value,
              showIndex: true,
              index: e.key,
              onTap: () => playerController.playSong(e.value, queueContext: downloaded, index: e.key),
            );
          }),
      ],
    );
  }

  // 3. CACHED SONGS TAB
  Widget _buildCachedSongsTab(LibraryService libraryService, PlayerController playerController) {
    final cached = libraryService.cachedSongs;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CACHED OFFLINE TRACKS (${cached.length})',
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Auto-cached in the local vault for instant zero-buffer replays',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
            if (cached.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BoxyButton(
                    label: 'MOVE ALL TO DOWNLOADS',
                    icon: Icons.download_for_offline_rounded,
                    isPrimary: false,
                    onPressed: () async {
                      final downloadService = Get.isRegistered<DownloadService>() ? Get.find<DownloadService>() : null;
                      final cacheService = Get.find<CacheService>();
                      final count = downloadService != null
                          ? await downloadService.moveAllCachedToDownloads()
                          : await cacheService.moveAllCachedToDownloads();

                      Get.snackbar(
                        'Moved to Downloads',
                        'Transferred $count track${count == 1 ? '' : 's'} to permanent offline storage',
                        snackPosition: SnackPosition.BOTTOM,
                        duration: const Duration(seconds: 3),
                        backgroundColor: AppTheme.cardSurfaceElevated,
                        colorText: AppTheme.textPrimary,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  BoxyButton(
                    label: 'PLAY ALL OFFLINE',
                    icon: Icons.play_arrow_rounded,
                    isPrimary: true,
                    onPressed: () => playerController.playSong(cached.first, queueContext: cached),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (cached.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No cached songs.\nSongs you play will be cached automatically here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ),
          )
        else
          ...cached.asMap().entries.map((e) {
            return SongTile(
              song: e.value,
              showIndex: true,
              index: e.key,
              onTap: () => playerController.playSong(e.value, queueContext: cached, index: e.key),
            );
          }),
      ],
    );
  }

  // 4. LOCAL SONGS TAB
  Widget _buildLocalSongsTab(LibraryService libraryService, PlayerController playerController) {
    final local = libraryService.localSongs;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LOCAL FILES (${local.length})',
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Audio files scanned from your configured Music folder',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
            if (local.isNotEmpty)
              BoxyButton(
                label: 'PLAY ALL',
                icon: Icons.play_arrow_rounded,
                isPrimary: true,
                onPressed: () => playerController.playSong(local.first, queueContext: local),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (local.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No local audio files detected in your Music directory.\nYou can configure your Music path in Settings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ),
          )
        else
          ...local.asMap().entries.map((e) {
            return SongTile(
              song: e.value,
              showIndex: true,
              index: e.key,
              onTap: () => playerController.playSong(e.value, queueContext: local, index: e.key),
            );
          }),
      ],
    );
  }

  // 5. LIKED SONGS TAB
  Widget _buildLikedSongsTab(LibraryService libraryService, PlayerController playerController) {
    final liked = libraryService.likedSongs;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIKED SONGS (${liked.length})',
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Your favorite bards, tracks, and villu paatu recordings',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
            if (liked.isNotEmpty)
              BoxyButton(
                label: 'PLAY ALL',
                icon: Icons.play_arrow_rounded,
                isPrimary: true,
                onPressed: () => playerController.playSong(liked.first, queueContext: liked),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (liked.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No liked songs yet.\nHeart any song to save it here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ),
          )
        else
          ...liked.asMap().entries.map((e) {
            return SongTile(
              song: e.value,
              showIndex: true,
              index: e.key,
              onTap: () => playerController.playSong(e.value, queueContext: liked, index: e.key),
            );
          }),
      ],
    );
  }

  // 6. PLAYLISTS TAB
  Widget _buildPlaylistsTab(LibraryService libraryService) {
    final playlists = libraryService.playlists;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'YOUR PLAYLISTS (${playlists.length})',
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            BoxyButton(
              label: 'NEW PLAYLIST',
              icon: Icons.add_rounded,
              isPrimary: true,
              onPressed: () => _showCreatePlaylistDialog(libraryService),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (playlists.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No playlists yet.\nClick "NEW PLAYLIST" to create one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ),
          )
        else
          ...playlists.map((playlist) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: BoxyCard(
                padding: const EdgeInsets.all(12),
                borderRadius: AppTheme.radiusMedium,
                onTap: () {
                  setState(() => _viewingPlaylist = playlist);
                },
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 48,
                        height: 48,
                        color: const Color(0xFF252838),
                        child: playlist.thumbnailUrl != null
                            ? Image.network(
                                playlist.thumbnailUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Image.asset(AppAssets.defaultCover, fit: BoxFit.cover),
                              )
                            : Image.asset(AppAssets.defaultCover, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.title,
                            style: const TextStyle(
                              color: AppTheme.textWhite,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${playlist.songCount} songs',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.textMuted),
                      splashRadius: 18,
                      onPressed: () => libraryService.deletePlaylist(playlist.id),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // Playlist detail view
  Widget _buildPlaylistDetail(LibraryService libraryService, PlayerController playerController) {
    final playlist = _viewingPlaylist!;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.blueAccent),
              splashRadius: 18,
              onPressed: () => setState(() => _viewingPlaylist = null),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.title,
                    style: const TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${playlist.songCount} songs',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (playlist.songs.isNotEmpty)
              BoxyButton(
                label: 'PLAY ALL',
                icon: Icons.play_arrow_rounded,
                isPrimary: true,
                onPressed: () => playerController.playSong(
                  playlist.songs.first,
                  queueContext: playlist.songs,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (playlist.songs.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Playlist is empty.\nAdd songs using the 3-dot menu on any song.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ),
          )
        else
          ...playlist.songs.asMap().entries.map((e) {
            return SongTile(
              song: e.value,
              showIndex: true,
              index: e.key,
              onTap: () => playerController.playSong(
                e.value,
                queueContext: playlist.songs,
                index: e.key,
              ),
            );
          }),
      ],
    );
  }

  void _showCreatePlaylistDialog(LibraryService libraryService) {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.windowBg,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.radiusLarge,
            side: const BorderSide(color: AppTheme.borderHighlight),
          ),
          title: const Text(
            'CREATE NEW PLAYLIST',
            style: TextStyle(
              color: AppTheme.blueAccent,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          content: TextField(
            controller: titleController,
            autofocus: true,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Playlist Name',
              hintStyle: TextStyle(color: AppTheme.textMuted),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.borderSubtle),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.blueAccent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final name = titleController.text.trim();
                if (name.isNotEmpty) {
                  await libraryService.createPlaylist(name);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                }
              },
              child: const Text('CREATE', style: TextStyle(color: AppTheme.blueAccent)),
            ),
          ],
        );
      },
    );
  }
}
