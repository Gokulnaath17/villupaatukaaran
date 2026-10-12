import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/player_controller.dart';
import '../theme/theme_controller.dart';

/// Live scrollable queue widget with rounded geometry and electric blue accent
class QueueList extends StatelessWidget {
  const QueueList({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlayerController>();

    return Obx(() {
      final queue = controller.queue;
      final currentSong = controller.currentSong.value;

      return Container(
        decoration: BoxDecoration(
          color: AppTheme.cardSurface,
          border: Border.all(color: AppTheme.borderSubtle, width: 1),
          borderRadius: AppTheme.radiusLarge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Queue Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.queue_music_rounded, size: 16, color: AppTheme.blueAccent),
                      const SizedBox(width: 8),
                      Text(
                        'UPCOMING QUEUE (${queue.length})',
                        style: const TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  if (queue.isNotEmpty)
                    InkWell(
                      onTap: controller.clearQueue,
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          'CLEAR',
                          style: TextStyle(
                            color: AppTheme.blueLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Queue List Items
            Expanded(
              child: queue.isEmpty
                  ? const Center(
                      child: Text(
                        'Queue is empty.\nPlay any song to begin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: queue.length,
                      itemBuilder: (ctx, index) {
                        final song = queue[index];
                        final isNowPlaying = currentSong?.videoId == song.videoId;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => controller.skipToQueueIndex(index),
                            borderRadius: AppTheme.radiusSmall,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: isNowPlaying ? AppTheme.cardActive : Colors.transparent,
                                borderRadius: AppTheme.radiusSmall,
                                border: Border.all(
                                  color: isNowPlaying
                                      ? AppTheme.blueAccent.withOpacity(0.3)
                                      : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isNowPlaying
                                        ? Icons.volume_up_rounded
                                        : Icons.drag_indicator_rounded,
                                    size: 16,
                                    color: isNowPlaying ? AppTheme.blueAccent : AppTheme.textMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isNowPlaying
                                                ? AppTheme.textWhite
                                                : AppTheme.textPrimary,
                                            fontSize: 12,
                                            fontWeight: isNowPlaying
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          song.artist,
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
                                  if (song.duration != null)
                                    Text(
                                      song.duration!,
                                      style: const TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 14),
                                    color: AppTheme.textMuted,
                                    splashRadius: 14,
                                    onPressed: () => controller.removeFromQueue(index),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    });
  }
}
