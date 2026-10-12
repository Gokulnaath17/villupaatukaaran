import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/playlist_item.dart';
import '../../services/library_service.dart';
import '../../services/player_controller.dart';
import '../../utils/app_assets.dart';
import '../theme/theme_controller.dart';
import '../widgets/boxy_card.dart';
import '../widgets/song_tile.dart';

/// Single unified Library page containing Playlists, Liked Songs, and Cached Tracks
class LibraryView extends StatefulWidget {
  const LibraryView({super.key});

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  int _selectedTab = 0; // 0: Playlists, 1: Liked, 2: Cached
  PlaylistItem? _viewingPlaylist;

  @override
  Widget build(BuildContext context) {
    final libraryService = Get.find<LibraryService>();
    final playerController = Get.find<PlayerController>();

    return Column(
      children: [
        // Sub-Navigation Tabs Header (Playlists, Liked, Cached)
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              _buildTabButton('PLAYLISTS', 0, Icons.queue_music),
              _buildTabButton('LIKED SONGS', 1, Icons.favorite),
              _buildTabButton('CACHED TRACKS', 2, Icons.offline_pin),
            ],
          ),
        ),

        // Main Tab Content Area
        Expanded(
          child: Obx(() {
            // If user clicked into a specific playlist detail
            if (_viewingPlaylist != null) {
              return _buildPlaylistDetail(libraryService, playerController);
            }

            switch (_selectedTab) {
              case 0:
                return _buildPlaylistsTab(libraryService);
              case 1:
                return _buildLikedSongsTab(libraryService, playerController);
              case 2:
                return _buildCachedSongsTab(libraryService, playerController);
              default:
                return const SizedBox.shrink();
            }
          }),
        ),
      ],
    );
  }

  Widget _buildTabButton(String label, int index, IconData icon) {
    final isSelected = _selectedTab == index && _viewingPlaylist == null;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = index;
            _viewingPlaylist = null;
          });
        },
        borderRadius: BorderRadius.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.yellowAccent.withOpacity(0.08) : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppTheme.yellowAccent : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppTheme.yellowAccent : AppTheme.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppTheme.yellowAccent : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Playlists Tab
  Widget _buildPlaylistsTab(LibraryService libraryService) {
    final playlists = libraryService.playlists;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Action Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'YOUR PLAYLISTS (${playlists.length})',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            BoxyButton(
              label: 'NEW PLAYLIST',
              icon: Icons.add,
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
              margin: const EdgeInsets.only(bottom: 8),
              child: BoxyCard(
                padding: const EdgeInsets.all(10),
                onTap: () {
                  setState(() => _viewingPlaylist = playlist);
                },
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.black,
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: playlist.thumbnailUrl != null
                          ? Image.network(
                              playlist.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Image.asset(AppAssets.defaultCover, fit: BoxFit.cover),
                            )
                          : Image.asset(AppAssets.defaultCover, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.title,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
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
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textMuted),
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

  // 2. Liked Songs Tab
  Widget _buildLikedSongsTab(LibraryService libraryService, PlayerController playerController) {
    final liked = libraryService.likedSongs;

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LIKED SONGS (${liked.length})',
                style: const TextStyle(
                  color: AppTheme.yellowAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              if (liked.isNotEmpty)
                BoxyButton(
                  label: 'PLAY ALL',
                  icon: Icons.play_arrow,
                  isPrimary: true,
                  onPressed: () => playerController.playSong(liked.first, queueContext: liked),
                ),
            ],
          ),
        ),
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

  // 3. Cached Tracks Tab
  Widget _buildCachedSongsTab(LibraryService libraryService, PlayerController playerController) {
    final cached = libraryService.cachedSongs;

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CACHED OFFLINE TRACKS (${cached.length})',
                    style: const TextStyle(
                      color: AppTheme.yellowAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Instant offline playback with 0 buffering',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
              if (cached.isNotEmpty)
                BoxyButton(
                  label: 'PLAY ALL OFFLINE',
                  icon: Icons.play_arrow,
                  isPrimary: true,
                  onPressed: () => playerController.playSong(cached.first, queueContext: cached),
                ),
            ],
          ),
        ),
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

  // Playlist detail view
  Widget _buildPlaylistDetail(LibraryService libraryService, PlayerController playerController) {
    final playlist = _viewingPlaylist!;

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.yellowAccent),
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
                        color: AppTheme.textPrimary,
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
                  icon: Icons.play_arrow,
                  isPrimary: true,
                  onPressed: () => playerController.playSong(
                    playlist.songs.first,
                    queueContext: playlist.songs,
                  ),
                ),
            ],
          ),
        ),
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
          backgroundColor: AppTheme.cardSurface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: AppTheme.border),
          ),
          title: const Text(
            'CREATE NEW PLAYLIST',
            style: TextStyle(
              color: AppTheme.yellowAccent,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
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
                borderSide: BorderSide(color: AppTheme.border),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.yellowAccent),
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
              child: const Text('CREATE', style: TextStyle(color: AppTheme.yellowAccent)),
            ),
          ],
        );
      },
    );
  }
}
