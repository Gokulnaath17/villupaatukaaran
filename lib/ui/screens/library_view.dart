import 'dart:io';
import 'package:file_picker/file_picker.dart';
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
  bool _isReorderMode = false;

  Future<void> _pickAndAddFolder(LibraryService libraryService) async {
    final selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Music Folder to Grant Access',
    );
    if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
      await libraryService.addAdditionalFolder(selectedDirectory);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Granted access to: $selectedDirectory'),
            backgroundColor: const Color(0xE61C1C1E),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _removeFolder(LibraryService libraryService, String folder) async {
    await libraryService.removeAdditionalFolder(folder);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Revoked access to: $folder'),
          backgroundColor: const Color(0xE61C1C1E),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

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
    final folders = libraryService.localSongsByFolder;
    final additionalFolders = libraryService.additionalFolders;
    final cacheService = Get.find<CacheService>();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
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
                    'Scanned from Base Folder and granted music directories',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (local.isNotEmpty) ...[
                  BoxyButton(
                    label: 'PLAY ALL',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => playerController.playAllSongs(local, shuffle: false),
                  ),
                  BoxyButton(
                    label: 'SHUFFLE ALL',
                    icon: Icons.shuffle_rounded,
                    isPrimary: true,
                    onPressed: () => playerController.playAllSongs(local, shuffle: true),
                  ),
                  BoxyButton(
                    label: _isReorderMode ? 'DONE' : 'REORDER',
                    icon: _isReorderMode ? Icons.check_rounded : Icons.swap_vert_rounded,
                    onPressed: () {
                      setState(() {
                        _isReorderMode = !_isReorderMode;
                      });
                    },
                  ),
                ],
                BoxyButton(
                  label: '+ ADD FOLDER',
                  icon: Icons.create_new_folder_rounded,
                  onPressed: () => _pickAndAddFolder(libraryService),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Storage Sources Strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.cardSurface,
            borderRadius: AppTheme.radiusMedium,
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.folder_shared_rounded, size: 14, color: AppTheme.blueLight),
                  SizedBox(width: 6),
                  Text(
                    'STORAGE SOURCES',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Base directory chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.home_work_rounded, size: 13, color: AppTheme.blueLight),
                        const SizedBox(width: 6),
                        Text(
                          'Base: ${cacheService.baseDir.value}',
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  // Granted additional folders
                  for (final folder in additionalFolders)
                    Container(
                      padding: const EdgeInsets.only(left: 10, right: 4, top: 2, bottom: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.blueAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: AppTheme.blueAccent.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.folder_open_rounded, size: 13, color: AppTheme.blueLight),
                          const SizedBox(width: 6),
                          Text(
                            folder.split(Platform.pathSeparator).last,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 14, color: AppTheme.textMuted),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                            splashRadius: 12,
                            tooltip: 'Revoke folder access',
                            onPressed: () => _removeFolder(libraryService, folder),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        if (local.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Icon(Icons.folder_off_rounded, size: 48, color: AppTheme.textMuted),
                  const SizedBox(height: 12),
                  const Text(
                    'No local audio files detected in your Base Folder.\nAdd music to your Base Folder or grant access to another folder.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  BoxyButton(
                    label: '+ GRANT FOLDER ACCESS',
                    icon: Icons.create_new_folder_rounded,
                    isPrimary: true,
                    onPressed: () => _pickAndAddFolder(libraryService),
                  ),
                ],
              ),
            ),
          )
        else if (_isReorderMode) ...[
          const SizedBox(height: 16),
          // Reorder hint & quick sort bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.blueAccent.withOpacity(0.08),
              borderRadius: AppTheme.radiusMedium,
              border: Border.all(color: AppTheme.blueAccent.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.drag_indicator_rounded, color: AppTheme.blueLight, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Drag items using the handle to rearrange your custom playback order.',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    InkWell(
                      onTap: () => libraryService.sortLocalSongs('title'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('A-Z Title', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ),
                    ),
                    InkWell(
                      onTap: () => libraryService.sortLocalSongs('artist'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Artist', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ),
                    ),
                    InkWell(
                      onTap: () => libraryService.sortLocalSongs('folder'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Folder', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: local.length,
            onReorder: (oldIndex, newIndex) => libraryService.reorderLocalSongs(oldIndex, newIndex),
            itemBuilder: (context, index) {
              final song = local[index];
              return Container(
                key: ValueKey(song.url ?? song.videoId),
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.cardSurface,
                  borderRadius: AppTheme.radiusMedium,
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 38,
                        height: 38,
                        color: const Color(0xFF252838),
                        child: Image.asset(AppAssets.defaultCover, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                              ),
                              if (song.album != null && song.album!.isNotEmpty) ...[
                                const Text(' • ', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                Text(
                                  song.album!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppTheme.blueLight, fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Icon(Icons.drag_handle_rounded, color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ] else ...[
          const SizedBox(height: 16),
          for (final folderEntry in folders.entries) ...[
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.cardSurface,
                borderRadius: AppTheme.radiusMedium,
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_rounded, color: AppTheme.blueLight, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          folderEntry.key,
                          style: const TextStyle(
                            color: AppTheme.textWhite,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${folderEntry.value.length} track${folderEntry.value.length == 1 ? '' : 's'}',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.blueAccent, size: 28),
                    tooltip: 'Play all in folder',
                    splashRadius: 20,
                    onPressed: () => playerController.playAllSongs(folderEntry.value, shuffle: false),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.shuffle_rounded, color: AppTheme.textSecondary, size: 20),
                    tooltip: 'Shuffle folder',
                    splashRadius: 20,
                    onPressed: () => playerController.playAllSongs(folderEntry.value, shuffle: true),
                  ),
                ],
              ),
            ),
            ...folderEntry.value.asMap().entries.map((e) {
              return SongTile(
                song: e.value,
                showIndex: true,
                index: e.key,
                onTap: () => playerController.playSong(
                  e.value,
                  queueContext: folderEntry.value,
                  index: e.key,
                ),
              );
            }),
          ],
        ],
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
