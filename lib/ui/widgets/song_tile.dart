import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/song_item.dart';
import '../../services/download_service.dart';
import '../../services/library_service.dart';
import '../../services/player_controller.dart';
import '../../utils/app_assets.dart';
import '../theme/theme_controller.dart';

/// Modern translucent song row card with active playback highlight & quick actions
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
      final isPlaying = isCurrent && playerController.isPlaying.value;
      final isLiked = playerController.isLiked(song.videoId);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap ?? () => playerController.playSong(song),
            borderRadius: AppTheme.radiusMedium,
            hoverColor: Colors.white.withOpacity(0.04),
            splashColor: AppTheme.redAccent.withOpacity(0.12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: isCurrent ? AppTheme.cardSurfaceElevated : Colors.transparent,
                borderRadius: AppTheme.radiusSmall,
                border: Border.all(
                  color: isCurrent ? AppTheme.redAccent.withOpacity(0.35) : Colors.transparent,
                  width: 1.0,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tileWidth = constraints.maxWidth;
                  final isCompact = tileWidth < 460;
                  final isVeryCompact = tileWidth < 340;

                  return Row(
                    children: [
                      if (showIndex && index != null && !isVeryCompact) ...[
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${index! + 1 < 10 ? '0' : ''}${index! + 1}',
                            style: TextStyle(
                              color: isCurrent ? AppTheme.redAccent : AppTheme.textQuiet,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Rounded Album Art Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: isVeryCompact ? 36 : 40,
                          height: isVeryCompact ? 36 : 40,
                          color: const Color(0xFF1F1F24),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (song.thumbnailUrl != null && song.thumbnailUrl!.isNotEmpty)
                                Image.network(
                                  song.thumbnailUrl!,
                                  fit: BoxFit.cover,
                                  width: isVeryCompact ? 36 : 40,
                                  height: isVeryCompact ? 36 : 40,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    AppAssets.defaultCover,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                Image.asset(
                                  AppAssets.defaultCover,
                                  fit: BoxFit.cover,
                                ),

                              // Equalizer overlay if currently playing
                              if (isPlaying)
                                Container(
                                  color: Colors.black.withOpacity(0.55),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      _buildEqBar(10),
                                      const SizedBox(width: 2),
                                      _buildEqBar(16),
                                      const SizedBox(width: 2),
                                      _buildEqBar(8),
                                    ],
                                  ),
                                ),
                            ],
                          ),
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
                                color: isCurrent ? Colors.white : AppTheme.textPrimary,
                                fontSize: 12.5,
                                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Duration
                      if (!isVeryCompact && song.duration != null && song.duration!.isNotEmpty) ...[
                        Text(
                          song.duration!,
                          style: const TextStyle(
                            color: AppTheme.textQuiet,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Quick "+" Add to Queue Button (hidden on compact widths)
                      if (!isCompact)
                        IconButton(
                          icon: const Icon(Icons.add_rounded, size: 17),
                          color: AppTheme.textMuted,
                          hoverColor: Colors.white.withOpacity(0.08),
                          splashRadius: 15,
                          tooltip: 'Add to Queue',
                          onPressed: () {
                            playerController.addToQueue(song);
                            Get.snackbar(
                              'Added to Queue',
                              '${song.title} added to queue',
                              snackPosition: SnackPosition.BOTTOM,
                              duration: const Duration(seconds: 1),
                              backgroundColor: AppTheme.cardSurfaceElevated,
                              colorText: AppTheme.textPrimary,
                            );
                          },
                        ),

                      // Download Status Indicator (Progress ring or completed badge)
                      Builder(builder: (_) {
                        final downloadService = Get.isRegistered<DownloadService>() ? Get.find<DownloadService>() : null;
                        if (downloadService == null) return const SizedBox.shrink();

                        return Obx(() {
                          final task = downloadService.getTask(song.videoId);
                          final isDownloading = task != null && task.status.value == DownloadStatus.downloading;
                          final isDownloaded = downloadService.isSongDownloaded(song.videoId) || song.isDownloaded;

                          if (isDownloading) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  value: task.progress.value > 0 ? task.progress.value : null,
                                  strokeWidth: 2,
                                  color: AppTheme.redAccent,
                                  backgroundColor: AppTheme.borderSubtle,
                                ),
                              ),
                            );
                          }

                          if (isDownloaded) {
                            return const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: AppTheme.redLight,
                              ),
                            );
                          }

                          return const SizedBox.shrink();
                        });
                      }),

                      // Like Shortcut Button (hidden on compact widths)
                      if (!isCompact)
                        IconButton(
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: isLiked ? AppTheme.redAccent : AppTheme.textMuted,
                          ),
                          splashRadius: 15,
                          tooltip: isLiked ? 'Liked' : 'Like',
                          onPressed: () => playerController.toggleLike(song),
                        ),

                      // 3-Dot Action Menu
                      IconButton(
                        icon: const Icon(
                          Icons.more_horiz_rounded,
                          size: 18,
                          color: AppTheme.textMuted,
                        ),
                        splashRadius: 15,
                        onPressed: () => _showSongActions(context, song),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildEqBar(double height) {
    return Container(
      width: 2.5,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.redAccent,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  /// Action sheet with: Play Next, Add to Queue, Like, Add to Playlist, Download
  void _showSongActions(BuildContext context, SongItem song) {
    final playerController = Get.find<PlayerController>();
    final libraryService = Get.find<LibraryService>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppTheme.borderSubtle, width: 1),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 46,
                        height: 46,
                        color: const Color(0xFF252838),
                        child: song.thumbnailUrl != null
                            ? Image.network(
                                song.thumbnailUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Image.asset(AppAssets.defaultCover, fit: BoxFit.cover),
                              )
                            : Image.asset(AppAssets.defaultCover, fit: BoxFit.cover),
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
                leading: const Icon(Icons.playlist_play, color: AppTheme.redAccent),
                title: const Text('Play Next', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  playerController.playNext(song);
                },
              ),

              // Action: Add to Queue
              ListTile(
                dense: true,
                leading: const Icon(Icons.queue_music, color: AppTheme.redAccent),
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
                    color: isFav ? AppTheme.redAccent : AppTheme.redAccent,
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
                leading: const Icon(Icons.playlist_add, color: AppTheme.redAccent),
                title: const Text('Add to Playlist', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddToPlaylistDialog(context, song, libraryService);
                },
              ),

              // Action: Download for offline
              Builder(builder: (_) {
                final downloadService = Get.isRegistered<DownloadService>() ? Get.find<DownloadService>() : null;
                if (downloadService == null) return const SizedBox.shrink();

                return Obx(() {
                  final task = downloadService.getTask(song.videoId);
                  final isDownloading = task != null && task.status.value == DownloadStatus.downloading;
                  final isDownloaded = downloadService.isSongDownloaded(song.videoId) || song.isDownloaded;

                  if (isDownloading) {
                    return ListTile(
                      dense: true,
                      leading: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          value: task.progress.value > 0 ? task.progress.value : null,
                          strokeWidth: 2.2,
                          color: AppTheme.redAccent,
                        ),
                      ),
                      title: Text(
                        'Downloading... ${task.progressPercentage}',
                        style: const TextStyle(color: AppTheme.redAccent, fontWeight: FontWeight.w600),
                      ),
                      subtitle: task.sizeStatusText.isNotEmpty
                          ? Text(task.sizeStatusText, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11))
                          : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 16, color: AppTheme.textMuted),
                        onPressed: () => downloadService.cancelDownload(song.videoId),
                      ),
                    );
                  }

                  if (isDownloaded) {
                    return const ListTile(
                      dense: true,
                      leading: Icon(Icons.offline_pin_rounded, color: AppTheme.redLight),
                      title: Text('Downloaded Offline', style: TextStyle(color: AppTheme.redLight)),
                      subtitle: Text('Saved locally in base storage', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    );
                  }

                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.download_rounded, color: AppTheme.redAccent),
                    title: const Text('Download for Offline', style: TextStyle(color: AppTheme.textPrimary)),
                    subtitle: const Text('Save permanently to downloads folder', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    onTap: () {
                      Navigator.pop(ctx);
                      downloadService.downloadSong(song);
                    },
                  );
                });
              }),
              const SizedBox(height: 8),
            ],
          ),
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
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.radiusLarge,
            side: const BorderSide(color: AppTheme.borderHighlight),
          ),
          title: const Text(
            'ADD TO PLAYLIST',
            style: TextStyle(
              color: AppTheme.redAccent,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                          leading: const Icon(Icons.queue_music, color: AppTheme.redAccent, size: 18),
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
                              backgroundColor: AppTheme.cardSurfaceElevated,
                              colorText: AppTheme.textPrimary,
                            );
                          },
                        );
                      },
                    ),
                  );
                }),
                const Divider(color: AppTheme.borderSubtle),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'New Playlist Name',
                    hintStyle: TextStyle(color: AppTheme.textMuted),
                    isDense: true,
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.borderSubtle),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.redAccent),
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
                    backgroundColor: AppTheme.cardSurfaceElevated,
                    colorText: AppTheme.textPrimary,
                  );
                }
              },
              child: const Text('CREATE & ADD', style: TextStyle(color: AppTheme.redAccent)),
            ),
          ],
        );
      },
    );
  }
}
