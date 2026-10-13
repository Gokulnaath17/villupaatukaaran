import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/cache_service.dart';
import '../../services/download_service.dart';
import '../../services/player_controller.dart';
import '../../utils/app_assets.dart';
import '../theme/theme_controller.dart';

/// Translucent slide-out Download Queue Drawer with real-time progress bars & task controls
class DownloadQueueDrawer extends StatelessWidget {
  final VoidCallback onClose;

  const DownloadQueueDrawer({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final downloadService = Get.find<DownloadService>();
    final cacheService = Get.find<CacheService>();
    final playerController = Get.find<PlayerController>();

    return Obx(() {
      final queue = downloadService.downloadQueue;
      final activeCount = downloadService.activeDownloadsCount.value;
      final hasCompleted = queue.any((t) =>
          t.status.value == DownloadStatus.completed ||
          t.status.value == DownloadStatus.cancelled);

      final drawerWidth = MediaQuery.of(context).size.width.clamp(280.0, 380.0);

      return Container(
        width: drawerWidth,
        decoration: BoxDecoration(
          color: const Color(0xF211131B), // 95% translucent dark graphite slate
          border: const Border(
            left: BorderSide(color: AppTheme.borderSubtle, width: 1.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 32,
              offset: const Offset(-10, 0),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.downloading_rounded, size: 18, color: AppTheme.blueAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'DOWNLOAD QUEUE (${queue.length})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textWhite,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activeCount > 0 ? '$activeCount downloading now' : 'All downloads up to date',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: activeCount > 0 ? AppTheme.blueAccent : AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: activeCount > 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecondary),
                  splashRadius: 18,
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Base Directory Info Banner
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.cardSurface,
                borderRadius: AppTheme.radiusSmall,
                border: Border.all(color: AppTheme.borderSubtle, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_special_rounded, size: 16, color: AppTheme.blueLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cacheService.downloadsDir.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 10.5, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Action toolbar: Clear completed / Count
            if (hasCompleted)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '${queue.where((t) => t.status.value == DownloadStatus.completed).length} COMPLETED',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: downloadService.clearCompleted,
                      icon: const Icon(Icons.delete_sweep_rounded, size: 14, color: AppTheme.textSecondary),
                      label: const Text(
                        'CLEAR FINISHED',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // Downloads List or Empty State
            Expanded(
              child: queue.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.cardSurface,
                              border: Border.all(color: AppTheme.borderSubtle),
                            ),
                            child: const Icon(
                              Icons.download_done_rounded,
                              size: 28,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No Active Downloads',
                            style: TextStyle(
                              color: AppTheme.textWhite,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Use the 3-dot menu on any song to save it for permanent offline listening.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: queue.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final task = queue[index];
                        return _buildTaskTile(task, downloadService, playerController);
                      },
                    ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTaskTile(
    DownloadTask task,
    DownloadService downloadService,
    PlayerController playerController,
  ) {
    return Obx(() {
      final status = task.status.value;
      final progress = task.progress.value;

      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.cardSurface,
          borderRadius: AppTheme.radiusSmall,
          border: Border.all(
            color: status == DownloadStatus.downloading
                ? AppTheme.blueAccent.withOpacity(0.35)
                : AppTheme.borderSubtle,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 38,
                    height: 38,
                    color: const Color(0xFF1E2130),
                    child: task.song.thumbnailUrl != null && task.song.thumbnailUrl!.isNotEmpty
                        ? Image.network(
                            task.song.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Image.asset(AppAssets.defaultAlbumArt, fit: BoxFit.cover),
                          )
                        : Image.asset(AppAssets.defaultAlbumArt, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 10),

                // Title & Artist
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        task.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Trailing Action Button
                if (status == DownloadStatus.downloading || status == DownloadStatus.pending)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
                    splashRadius: 14,
                    tooltip: 'Cancel',
                    onPressed: () => downloadService.cancelDownload(task.videoId),
                  )
                else if (status == DownloadStatus.completed)
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill_rounded, size: 22, color: AppTheme.blueAccent),
                    splashRadius: 16,
                    tooltip: 'Play Offline',
                    onPressed: () => playerController.playSong(task.song),
                  )
                else if (status == DownloadStatus.failed || status == DownloadStatus.cancelled)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 18, color: AppTheme.blueLight),
                    splashRadius: 16,
                    tooltip: 'Retry',
                    onPressed: () => downloadService.retryDownload(task.videoId),
                  ),
              ],
            ),

            // Progress Bar & Stats
            if (status == DownloadStatus.downloading) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  backgroundColor: AppTheme.borderSubtle,
                  color: AppTheme.blueAccent,
                  minHeight: 3,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    task.progressPercentage,
                    style: const TextStyle(
                      color: AppTheme.blueAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (task.sizeStatusText.isNotEmpty)
                    Text(
                      task.sizeStatusText,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ] else if (status == DownloadStatus.pending) ...[
              const SizedBox(height: 6),
              const Text(
                'Waiting in queue...',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
              ),
            ] else if (status == DownloadStatus.completed) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 12, color: AppTheme.trafficGreen),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Saved to Offline Storage',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppTheme.trafficGreen, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ] else if (status == DownloadStatus.failed) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 12, color: Color(0xFFFF4D4D)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      task.errorMessage.value ?? 'Download failed',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFFF4D4D), fontSize: 10),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }
}

