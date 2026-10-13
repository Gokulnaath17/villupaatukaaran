import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/player_controller.dart';
import '../../utils/app_assets.dart';
import '../theme/theme_controller.dart';

/// Persistent attached bottom player dock bar (inspired by mod.png)
class PlayerDockBar extends StatelessWidget {
  final VoidCallback onToggleQueue;
  final bool isQueueOpen;

  const PlayerDockBar({
    super.key,
    required this.onToggleQueue,
    this.isQueueOpen = false,
  });

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
      final pos = controller.position.value;
      final dur = controller.duration.value;
      final queueCount = controller.queue.length;
      final isShuffle = controller.isShuffle.value;
      final loop = controller.loopMode.value;

      final hasDuration = dur.inSeconds > 0;
      final maxSec = hasDuration ? dur.inSeconds.toDouble() : 1.0;
      final curSec = hasDuration ? pos.inSeconds.toDouble().clamp(0.0, maxSec) : 0.0;
      final seekRatio = hasDuration ? (curSec / maxSec) : 0.0;

      final isLiked = song != null ? controller.isLiked(song.videoId) : false;

      return LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final isCompact = totalWidth < 900;
          final isUltraCompact = totalWidth < 720;

          return Container(
            height: 74,
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 24),
            decoration: const BoxDecoration(
              color: AppTheme.dockBg,
              border: Border(top: BorderSide(color: AppTheme.borderSubtle, width: 1.0)),
            ),
            child: Row(
              children: [
                // Left Group: Avatar & Song Details (Click to open Queue Drawer)
                InkWell(
                  onTap: onToggleQueue,
                  borderRadius: AppTheme.radiusMedium,
                  child: Container(
                    width: isUltraCompact ? 140 : (isCompact ? 180 : 240),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: isUltraCompact ? 38 : 44,
                            height: isUltraCompact ? 38 : 44,
                            color: const Color(0xFF252838),
                            child: song?.thumbnailUrl != null && song!.thumbnailUrl!.isNotEmpty
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
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song?.title ?? 'No Track Playing',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.textWhite,
                                  fontSize: isUltraCompact ? 12 : 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      song?.artist ?? 'Select a song',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: isUltraCompact ? 10.5 : 11.5,
                                      ),
                                    ),
                                  ),
                                  if (song != null && !isCompact) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppTheme.trafficGreen.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: AppTheme.trafficGreen.withOpacity(0.35),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Text(
                                        'Cached ✓',
                                        style: TextStyle(
                                          color: AppTheme.trafficGreen,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Center Group: Transport Controls + Sleek Scrubber Line
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 20),
                    child: Row(
                      children: [
                        // Transport Buttons (Shuffle, |◀, ▶/||, ▶|, Repeat)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isUltraCompact)
                              IconButton(
                                icon: Icon(
                                  Icons.shuffle_rounded,
                                  size: 18,
                                  color: isShuffle ? AppTheme.redAccent : AppTheme.textMuted,
                                ),
                                splashRadius: 16,
                                tooltip: isShuffle ? 'Shuffle: On' : 'Shuffle: Off',
                                onPressed: controller.toggleShuffle,
                              ),
                            IconButton(
                              icon: const Icon(Icons.skip_previous_rounded, size: 22),
                              color: AppTheme.textWhite.withOpacity(0.85),
                              splashRadius: 18,
                              tooltip: 'Previous',
                              onPressed: controller.skipToPrevious,
                            ),
                            IconButton(
                              icon: Icon(
                                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                size: 26,
                              ),
                              color: AppTheme.textWhite,
                              splashRadius: 20,
                              tooltip: isPlaying ? 'Pause' : 'Play',
                              onPressed: controller.togglePlayPause,
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_next_rounded, size: 22),
                              color: AppTheme.textWhite.withOpacity(0.85),
                              splashRadius: 18,
                              tooltip: 'Next',
                              onPressed: controller.skipToNext,
                            ),
                            if (!isUltraCompact)
                              IconButton(
                                icon: Icon(
                                  loop == LoopMode.one
                                      ? Icons.repeat_one_rounded
                                      : Icons.repeat_rounded,
                                  size: 18,
                                  color: loop != LoopMode.off ? AppTheme.redAccent : AppTheme.textMuted,
                                ),
                                splashRadius: 16,
                                tooltip: loop == LoopMode.off
                                    ? 'Repeat: Off'
                                    : (loop == LoopMode.one ? 'Repeat: One Track' : 'Repeat: All Tracks'),
                                onPressed: controller.cycleLoopMode,
                              ),
                          ],
                        ),
                        SizedBox(width: isCompact ? 6 : 12),

                        // Live Time Elapsed
                        SizedBox(
                          width: 36,
                          child: Text(
                            _formatDuration(pos),
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Continuous Scrubber Line with White Dot Thumb (matching mod.png)
                        Expanded(
                          child: LayoutBuilder(
                            builder: (ctx, constraints) {
                              final trackWidth = constraints.maxWidth;

                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onHorizontalDragUpdate: (details) {
                                  if (!hasDuration) return;
                                  final localX = details.localPosition.dx.clamp(0.0, trackWidth);
                                  final ratio = localX / trackWidth;
                                  final targetSec = ratio * maxSec;
                                  controller.seek(Duration(seconds: targetSec.toInt()));
                                },
                                onTapDown: (details) {
                                  if (!hasDuration) return;
                                  final localX = details.localPosition.dx.clamp(0.0, trackWidth);
                                  final ratio = localX / trackWidth;
                                  final targetSec = ratio * maxSec;
                                  controller.seek(Duration(seconds: targetSec.toInt()));
                                },
                                child: SizedBox(
                                  height: 30, // expanded tap target
                                  child: Stack(
                                    alignment: Alignment.centerLeft,
                                    children: [
                                      // Rail Background
                                      Container(
                                        width: trackWidth,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2E3347),
                                          borderRadius: BorderRadius.circular(100),
                                        ),
                                      ),
                                      // Active White Fill
                                      Container(
                                        width: trackWidth * seekRatio,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(100),
                                        ),
                                      ),
                                      // White Dot Thumb
                                      Positioned(
                                        left: (trackWidth * seekRatio - 4.5).clamp(0.0, trackWidth - 9.0),
                                        child: Container(
                                          width: 9,
                                          height: 9,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.white.withOpacity(0.9),
                                                blurRadius: 6,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Total Duration
                        SizedBox(
                          width: 36,
                          child: Text(
                            _formatDuration(dur),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Group: Favorite, Volume, Queue Toggle
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Favorite Heart Button
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 19,
                        color: isLiked ? const Color(0xFFFF3366) : AppTheme.textSecondary,
                      ),
                      splashRadius: 18,
                      tooltip: isLiked ? 'Liked' : 'Like',
                      onPressed: () {
                        if (song != null) controller.toggleLike(song);
                      },
                    ),
                    const SizedBox(width: 4),

                    // Interactive Volume Slider Group
                    Obx(() {
                      final vol = controller.volume.value.clamp(0.0, 1.0);
                      final isMuted = vol <= 0.001;

                      IconData volIcon;
                      if (isMuted) {
                        volIcon = Icons.volume_off_rounded;
                      } else if (vol < 0.5) {
                        volIcon = Icons.volume_down_rounded;
                      } else {
                        volIcon = Icons.volume_up_rounded;
                      }

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Mute / Unmute Button
                          IconButton(
                            icon: Icon(
                              volIcon,
                              size: 19,
                              color: isMuted ? AppTheme.textMuted : AppTheme.textSecondary,
                            ),
                            splashRadius: 16,
                            tooltip: isMuted ? 'Unmute' : 'Mute',
                            onPressed: controller.toggleMute,
                          ),
                          // Volume Slider Rail with White Thumb (hidden on compact widths)
                          if (!isCompact) ...[
                            SizedBox(
                              width: 75,
                              child: LayoutBuilder(
                                builder: (ctx, constraints) {
                                  final sliderWidth = constraints.maxWidth;
                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onHorizontalDragUpdate: (details) {
                                      final localX = details.localPosition.dx.clamp(0.0, sliderWidth);
                                      controller.setVolume(localX / sliderWidth);
                                    },
                                    onTapDown: (details) {
                                      final localX = details.localPosition.dx.clamp(0.0, sliderWidth);
                                      controller.setVolume(localX / sliderWidth);
                                    },
                                    child: Tooltip(
                                      message: 'Volume: ${(vol * 100).round()}%',
                                      child: SizedBox(
                                        height: 30, // expanded tap target
                                        child: Stack(
                                          alignment: Alignment.centerLeft,
                                          children: [
                                            // Background track
                                            Container(
                                              width: sliderWidth,
                                              height: 3,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF2E3347),
                                                borderRadius: BorderRadius.circular(100),
                                              ),
                                            ),
                                            // Active Fill
                                            Container(
                                              width: sliderWidth * vol,
                                              height: 3,
                                              decoration: BoxDecoration(
                                                color: isMuted ? AppTheme.textMuted : Colors.white,
                                                borderRadius: BorderRadius.circular(100),
                                              ),
                                            ),
                                            // White Thumb
                                            Positioned(
                                              left: (sliderWidth * vol - 4.0).clamp(0.0, sliderWidth - 8.0),
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: isMuted ? AppTheme.textMuted : Colors.white,
                                                  shape: BoxShape.circle,
                                                  boxShadow: isMuted
                                                      ? null
                                                      : [
                                                          BoxShadow(
                                                            color: Colors.white.withOpacity(0.8),
                                                            blurRadius: 4,
                                                            spreadRadius: 1,
                                                          ),
                                                        ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      );
                    }),

                    // QUEUE (N) Toggle Pill Button
                    InkWell(
                      onTap: onToggleQueue,
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isUltraCompact ? 8 : 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isQueueOpen
                              ? AppTheme.blueAccent.withOpacity(0.2)
                              : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: isQueueOpen ? AppTheme.blueAccent : AppTheme.borderSubtle,
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          isUltraCompact ? 'Q($queueCount)' : 'QUEUE ($queueCount)',
                          style: TextStyle(
                            color: isQueueOpen ? AppTheme.blueAccent : AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    });
  }
}

