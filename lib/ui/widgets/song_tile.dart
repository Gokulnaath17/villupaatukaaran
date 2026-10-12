import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/song_item.dart';
import '../../services/library_service.dart';
import '../../services/player_controller.dart';
import '../../utils/app_assets.dart';
import '../theme/theme_controller.dart';

/// Minimalist boxy song row with action menu
class SongTile extends StatelessWidget {
  final SongItem song;
  final VoidCallback? onTap;
  final bool showIndex;
  final int? index;

  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.showIndex = false,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();

    return Obx(() {
      final isCurrent = playerController.currentSong.value?.videoId == song.videoId;
      final isLiked = playerController.isLiked(song.videoId);

      return InkWell(
        onTap: onTap ?? () => playerController.playSong(song),
        borderRadius: BorderRadius.zero,
        splashColor: AppTheme.yellowAccent.withOpacity(0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isCurrent ? AppTheme.yellowAccent.withOpacity(0.06) : Colors.transparent,
            border: Border(
              bottom: const BorderSide(color: Color(0xFF1C1C1C), width: 1.0),
              left: isCurrent
                  ? const BorderSide(color: AppTheme.yellowAccent, width: 3.0)
                  : BorderSide.none,
            ),
          ),
          child: Row(
            children: [
              if (showIndex && index != null) ...[
                SizedBox(
                  width: 24,
                  child: Text(
                    '${index! + 1}',
                    style: TextStyle(
                      color: isCurrent ? AppTheme.yellowAccent : AppTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Square Album Art Thumbnail
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.cardSurface,
                  border: Border.all(
                    color: isCurrent ? AppTheme.yellowAccent : AppTheme.border,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.zero,
                ),
                child: song.thumbnailUrl != null && song.thumbnailUrl!.isNotEmpty
                    ? Image.network(
                        song.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                          AppAssets.defaultCover,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(
                        AppAssets.defaultCover,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: 12),

              // Title and Artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCurrent ? AppTheme.yellowAccent : AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Duration
              if (song.duration != null && song.duration!.isNotEmpty) ...[
                Text(
                  song.duration!,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
              ],

              // Like Shortcut Button
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: isLiked ? AppTheme.yellowAccent : AppTheme.textMuted,
                ),
                splashRadius: 18,
                onPressed: () => playerController.toggleLike(song),
              ),

              // 3-Dot Action Menu
              IconButton(
                icon: const Icon(
                  Icons.more_vert,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                splashRadius: 18,
                onPressed: () => _showSongActions(context, song),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// Action sheet with: Play Next, Add to Queue, Like, Add to Playlist, Download
  void _showSongActions(BuildContext context, SongItem song) {
    final playerController = Get.find<PlayerController>();
    final libraryService = Get.find<LibraryService>();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: AppTheme.border, width: 1),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.border)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.yellowAccent),
                      ),
                      child: song.thumbnailUrl != null
                          ? Image.network(
                              song.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Image.asset(AppAssets.defaultCover, fit: BoxFit.cover),
                            )
                          : Image.asset(AppAssets.defaultCover, fit: BoxFit.cover),
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
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Action: Play Next
              ListTile(
                dense: true,
                leading: const Icon(Icons.playlist_play, color: AppTheme.yellowAccent),
                title: const Text('Play Next', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  playerController.playNext(song);
                },
              ),

              // Action: Add to Queue
              ListTile(
                dense: true,
                leading: const Icon(Icons.queue_music, color: AppTheme.yellowAccent),
                title: const Text('Add to Queue', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  playerController.addToQueue(song);
                },
              ),

              // Action: Like / Favorite
              Obx(() {
                final isFav = playerController.isLiked(song.videoId);
                return ListTile(
                  dense: true,
                  leading: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: AppTheme.yellowAccent,
                  ),
                  title: Text(
                    isFav ? 'Remove from Liked' : 'Like Song',
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  onTap: () {
                    playerController.toggleLike(song);
                    Navigator.pop(ctx);
                  },
                );
              }),

              // Action: Add to Playlist
              ListTile(
                dense: true,
                leading: const Icon(Icons.playlist_add, color: AppTheme.yellowAccent),
                title: const Text('Add to Playlist', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddToPlaylistDialog(context, song, libraryService);
                },
              ),

              // Action: Download
              ListTile(
                dense: true,
                leading: const Icon(Icons.download, color: AppTheme.yellowAccent),
                title: const Text('Download for Offline', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  Get.snackbar(
                    'Downloading',
                    'Saving ${song.title} to offline storage',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Dialog to choose or create playlist
  void _showAddToPlaylistDialog(
      BuildContext context, SongItem song, LibraryService libraryService) {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppTheme.cardSurface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: AppTheme.border),
          ),
          title: const Text(
            'ADD TO PLAYLIST',
            style: TextStyle(
              color: AppTheme.yellowAccent,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Existing playlists list
                Obx(() {
                  final list = libraryService.playlists;
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No playlists created yet.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    );
                  }
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (ctx, i) {
                        final p = list[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.queue_music, color: AppTheme.yellowAccent, size: 18),
                          title: Text(p.title, style: const TextStyle(color: AppTheme.textPrimary)),
                          subtitle: Text('${p.songCount} songs',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                          onTap: () {
                            libraryService.addSongToPlaylist(p.id, song);
                            Navigator.pop(dialogCtx);
                            Get.snackbar(
                              'Added to Playlist',
                              'Added to "${p.title}"',
                              snackPosition: SnackPosition.BOTTOM,
                              duration: const Duration(seconds: 2),
                            );
                          },
                        );
                      },
                    ),
                  );
                }),
                const Divider(color: AppTheme.border),
                // Create New Playlist input
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'New Playlist Name',
                    hintStyle: TextStyle(color: AppTheme.textMuted),
                    isDense: true,
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.yellowAccent),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final name = titleController.text.trim();
                if (name.isNotEmpty) {
                  final newPl = await libraryService.createPlaylist(name);
                  await libraryService.addSongToPlaylist(newPl.id, song);
                  if (dialogCtx.mounted) {
                    Navigator.pop(dialogCtx);
                  }
                  Get.snackbar(
                    'Playlist Created',
                    'Created "$name" and added song',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2),
                  );
                }
              },
              child: const Text('CREATE & ADD', style: TextStyle(color: AppTheme.yellowAccent)),
            ),
          ],
        );
      },
    );
  }
}
