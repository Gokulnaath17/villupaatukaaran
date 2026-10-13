import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/player_controller.dart';
import '../../utils/app_assets.dart';
import '../theme/theme_controller.dart';

/// Translucent slide-out Queue Drawer with smart pre-caching indicator
class QueueDrawer extends StatelessWidget {
  final VoidCallback onClose;

  const QueueDrawer({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlayerController>();

    return Obx(() {
      final queue = controller.queue;
      final currentSong = controller.currentSong.value;

      final screenWidth = MediaQuery.of(context).size.width;
      final drawerWidth = screenWidth < 400 ? (screenWidth * 0.9).clamp(280.0, 360.0) : 360.0;

      return Container(
        width: drawerWidth,
        decoration: BoxDecoration(
          color: const Color(0xF211131B), // 95% translucent dark drawer
          border: const Border(
            left: BorderSide(color: AppTheme.borderSubtle, width: 1.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
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
                      Text(
                        'UP NEXT QUEUE (${queue.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Seamless gapless transitions enabled',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
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
            const SizedBox(height: 16),

            // Smart Preloading Banner (addresses user issue #7)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.blueAccent.withOpacity(0.08),
                borderRadius: AppTheme.radiusSmall,
                border: Border.all(
                  color: AppTheme.blueAccent.withOpacity(0.25),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, size: 18, color: AppTheme.blueAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 11, color: AppTheme.blueLight, height: 1.3),
                        children: [
                          TextSpan(
                            text: 'Smart Preloading Active: ',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: 'Next track is pre-buffered to eliminate playback delay.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Queue List
            Expanded(
              child: queue.isEmpty
                  ? const Center(
                      child: Text(
                        'Queue is empty.\nAdd tracks using the "+" button.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      itemCount: queue.length,
                      itemBuilder: (ctx, i) {
                        final track = queue[i];
                        final isCurrent = track.videoId == currentSong?.videoId;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => controller.skipToQueueIndex(i),
                              borderRadius: AppTheme.radiusSmall,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isCurrent ? AppTheme.cardActive : Colors.transparent,
                                  borderRadius: AppTheme.radiusSmall,
                                  border: Border.all(
                                    color: isCurrent
                                        ? AppTheme.blueAccent.withOpacity(0.3)
                                        : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        color: const Color(0xFF252838),
                                        child: track.thumbnailUrl != null
                                            ? Image.network(
                                                track.thumbnailUrl!,
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
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            track.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isCurrent
                                                  ? AppTheme.textWhite
                                                  : AppTheme.textPrimary,
                                              fontSize: 12.5,
                                              fontWeight:
                                                  isCurrent ? FontWeight.w700 : FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isCurrent
                                                ? '${track.artist} • Playing Now'
                                                : track.artist,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isCurrent
                                                  ? AppTheme.blueLight
                                                  : AppTheme.textMuted,
                                              fontSize: 11,
                                              fontWeight:
                                                  isCurrent ? FontWeight.w600 : FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (track.duration != null)
                                      Text(
                                        track.duration!,
                                        style: const TextStyle(
                                          color: AppTheme.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 16),
                                      color: AppTheme.textMuted,
                                      splashRadius: 14,
                                      tooltip: 'Remove',
                                      onPressed: () => controller.removeFromQueue(i),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Queue Actions (Clear Queue)
            if (queue.isNotEmpty) ...[
              const Divider(color: AppTheme.borderSubtle),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: controller.clearQueue,
                    icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: AppTheme.textMuted),
                    label: const Text(
                      'Clear Queue',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: controller.toggleShuffle,
                    icon: Icon(
                      Icons.shuffle_rounded,
                      size: 16,
                      color: controller.isShuffle.value ? AppTheme.blueAccent : AppTheme.textMuted,
                    ),
                    label: Text(
                      controller.isShuffle.value ? 'Shuffle On' : 'Shuffle',
                      style: TextStyle(
                        color: controller.isShuffle.value ? AppTheme.blueAccent : AppTheme.textMuted,
                        fontSize: 12,
                      ),
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
