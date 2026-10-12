import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

import '../../services/player_controller.dart';
import '../../utils/app_assets.dart';
import '../theme/theme_controller.dart';
import 'tamil_bell_loader.dart';

/// Boxy, minimalist now-playing card for the right pane
class PlayerCard extends StatelessWidget {
  const PlayerCard({super.key});

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlayerController>();

    return Obx(() {
      final song = controller.currentSong.value;
      final isPlaying = controller.isPlaying.value;
      final isBuffering = controller.isBuffering.value;
      final pos = controller.position.value;
      final dur = controller.duration.value;
      final isShuffle = controller.isShuffle.value;
      final loop = controller.loopMode.value;
      final isLiked = song != null ? controller.isLiked(song.videoId) : false;

      final hasDuration = dur.inSeconds > 0;
      final maxSec = hasDuration ? dur.inSeconds.toDouble() : 1.0;
      final curSec = hasDuration ? pos.inSeconds.toDouble().clamp(0.0, maxSec) : 0.0;

      return Container(
        decoration: BoxDecoration(
          color: AppTheme.cardSurface,
          border: Border.all(
            color: isPlaying ? AppTheme.yellowAccent : AppTheme.border,
            width: isPlaying ? 1.5 : 1.0,
          ),
          boxShadow: isPlaying
              ? [
                  BoxShadow(
                    color: AppTheme.yellowAccent.withOpacity(0.14),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ]
              : null,
          borderRadius: BorderRadius.zero,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Section: Album Artwork with sharp golden border
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.black,
                  border: Border.all(
                    color: isPlaying ? AppTheme.yellowAccent : AppTheme.border,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.zero,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (song?.thumbnailUrl != null && song!.thumbnailUrl!.isNotEmpty)
                      Image.network(
                        song.highResThumbnail ?? song.thumbnailUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
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

                    // Live Playing Badge
                    if (isPlaying && !isBuffering)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.85),
                            border: Border.all(color: AppTheme.yellowAccent, width: 1),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.graphic_eq, color: AppTheme.yellowAccent, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'PLAYING',
                                style: TextStyle(
                                  color: AppTheme.yellowAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Tamil Bell Loader indicator when buffering
                    if (isBuffering)
                      Container(
                        color: Colors.black.withOpacity(0.6),
                        child: const TamilBellLoader(size: 48, showGlow: true),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Track Title & Favorite Button
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song?.title ?? 'No Track Playing',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song?.artist ?? 'Select a song to play',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.yellowLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (song != null)
                  IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? AppTheme.yellowAccent : AppTheme.textMuted,
                      size: 22,
                    ),
                    onPressed: () => controller.toggleLike(song),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress Slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                activeTrackColor: AppTheme.yellowAccent,
                inactiveTrackColor: AppTheme.border,
                thumbColor: AppTheme.yellowAccent,
              ),
              child: Slider(
                value: curSec,
                min: 0.0,
                max: maxSec,
                onChanged: hasDuration
                    ? (val) {
                        controller.seek(Duration(seconds: val.toInt()));
                      }
                    : null,
              ),
            ),

            // Timestamps
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(pos),
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                  Text(
                    hasDuration ? _formatDuration(dur) : '--:--',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Transport Control Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Shuffle Button
                IconButton(
                  icon: Icon(
                    Icons.shuffle,
                    color: isShuffle ? AppTheme.yellowAccent : AppTheme.textMuted,
                    size: 20,
                  ),
                  splashRadius: 20,
                  onPressed: controller.toggleShuffle,
                ),

                // Previous
                IconButton(
                  icon: const Icon(Icons.skip_previous, color: AppTheme.textPrimary, size: 26),
                  splashRadius: 22,
                  onPressed: controller.skipToPrevious,
                ),

                // Play / Pause Boxy Button
                InkWell(
                  onTap: controller.togglePlayPause,
                  borderRadius: BorderRadius.zero,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.yellowAccent,
                      border: Border.all(color: AppTheme.yellowLight, width: 1),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: AppTheme.black,
                      size: 28,
                    ),
                  ),
                ),

                // Next
                IconButton(
                  icon: const Icon(Icons.skip_next, color: AppTheme.textPrimary, size: 26),
                  splashRadius: 22,
                  onPressed: controller.skipToNext,
                ),

                // Repeat / Loop Button
                IconButton(
                  icon: Icon(
                    loop == LoopMode.one
                        ? Icons.repeat_one
                        : (loop == LoopMode.all ? Icons.repeat : Icons.repeat),
                    color: loop != LoopMode.off ? AppTheme.yellowAccent : AppTheme.textMuted,
                    size: 20,
                  ),
                  splashRadius: 20,
                  onPressed: controller.cycleLoopMode,
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

