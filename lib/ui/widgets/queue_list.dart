import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/player_controller.dart';
import '../theme/theme_controller.dart';

/// Live scrollable queue widget placed below the player card
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
          border: Border.all(color: AppTheme.border, width: 1),
          borderRadius: BorderRadius.zero,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Queue Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.queue_music, size: 16, color: AppTheme.yellowAccent),
                      const SizedBox(width: 8),
                      Text(
                        'UPCOMING QUEUE (${queue.length})',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  if (queue.isNotEmpty)
                    InkWell(
                      onTap: controller.clearQueue,
                      borderRadius: BorderRadius.zero,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          'CLEAR',
                          style: TextStyle(
                            color: AppTheme.yellowAccent,
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
                      itemCount: queue.length,
                      itemBuilder: (ctx, index) {
                        final song = queue[index];
                        final isNowPlaying = currentSong?.videoId == song.videoId;

                        return InkWell(
                          onTap: () => controller.skipToQueueIndex(index),
                          borderRadius: BorderRadius.zero,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isNowPlaying
                                  ? AppTheme.yellowAccent.withOpacity(0.08)
                                  : Colors.transparent,
                              border: Border(
                                bottom: const BorderSide(color: Color(0xFF1A1A1A)),
                                left: isNowPlaying
                                    ? const BorderSide(color: AppTheme.yellowAccent, width: 3)
                                    : BorderSide.none,
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  child: isNowPlaying
                                      ? const Icon(Icons.volume_up, size: 14, color: AppTheme.yellowAccent)
                                      : Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: AppTheme.textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
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
                                              ? AppTheme.yellowAccent
                                              : AppTheme.textPrimary,
                                          fontSize: 13,
                                          fontWeight: isNowPlaying ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        song.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppTheme.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (song.duration != null) ...[
                                  Text(
                                    song.duration!,
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                InkWell(
                                  onTap: () => controller.removeFromQueue(index),
                                  borderRadius: BorderRadius.zero,
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.close, size: 14, color: AppTheme.textMuted),
                                  ),
                                ),
                              ],
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

