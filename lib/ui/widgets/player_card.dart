import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

import '../../services/player_controller.dart';
import '../../utils/app_assets.dart';
import '../theme/theme_controller.dart';
import 'tamil_bell_loader.dart';

/// Modern now-playing card with rounded corners and electric blue accents
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
            color: isPlaying ? AppTheme.redAccent.withOpacity(0.5) : AppTheme.borderSubtle,
            width: 1.0,
          ),
          boxShadow: isPlaying
              ? [
                  BoxShadow(
                    color: AppTheme.redGlow,
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : null,
          borderRadius: AppTheme.radiusLarge,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Section: Album Artwork with rounded corners
            AspectRatio(
              aspectRatio: 1.0,
              child: ClipRRect(
                borderRadius: AppTheme.radiusMedium,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF191B26),
                    border: Border.all(
                      color: isPlaying ? AppTheme.redAccent : AppTheme.borderSubtle,
                      width: 1.0,
                    ),
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
                              color: AppTheme.redAccent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PLAYING',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ),

                      // Buffering indicator
                      if (isBuffering)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: TamilBellLoader(size: 40, showGlow: false),
                          ),
                        ),
                    ],
                  ),
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
                          color: AppTheme.textWhite,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        song?.artist ?? 'Select a song to play',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.redLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? const Color(0xFFFF3366) : AppTheme.textMuted,
                    size: 20,
                  ),
                  splashRadius: 18,
                  onPressed: () {
                    if (song != null) controller.toggleLike(song);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Progress Slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.redAccent,
                inactiveTrackColor: const Color(0xFF2E3347),
                thumbColor: Colors.white,
                trackHeight: 3.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              ),
              child: Slider(
                value: curSec,
                min: 0.0,
                max: maxSec,
                onChanged: (val) {
                  controller.seek(Duration(seconds: val.toInt()));
                },
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
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontFamily: 'monospace'),
                  ),
                  Text(
                    _formatDuration(dur),
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Playback Controls Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Shuffle
                IconButton(
                  icon: Icon(
                    Icons.shuffle_rounded,
                    color: isShuffle ? AppTheme.redAccent : AppTheme.textMuted,
                    size: 19,
                  ),
                  splashRadius: 18,
                  onPressed: controller.toggleShuffle,
                ),

                // Previous
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded, size: 24, color: AppTheme.textWhite),
                  splashRadius: 20,
                  onPressed: controller.skipToPrevious,
                ),

                // Play / Pause Circle Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: controller.togglePlayPause,
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        gradient: AppTheme.redGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.redGlow,
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),

                // Next
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded, size: 24, color: AppTheme.textWhite),
                  splashRadius: 20,
                  onPressed: controller.skipToNext,
                ),

                // Loop Mode
                IconButton(
                  icon: Icon(
                    loop == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                    color: loop != LoopMode.off ? AppTheme.redAccent : AppTheme.textMuted,
                    size: 19,
                  ),
                  splashRadius: 18,
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
