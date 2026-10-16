import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/player_controller.dart';
import '../../utils/app_assets.dart';
import '../theme/theme_controller.dart';

/// Persistent attached bottom player dock bar (redesigned from villupaatukaaran-redesign.html)
class PlayerDockBar extends StatelessWidget {
  final VoidCallback onToggleQueue;
  final bool isQueueOpen;
  final VoidCallback? onOpenFullPlayer;

  const PlayerDockBar({
    super.key,
    required this.onToggleQueue,
    this.isQueueOpen = false,
    this.onOpenFullPlayer,
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
          final isCompact = totalWidth < 960;
          final isNarrow = totalWidth < 780;
          final isMobile = totalWidth < 600;

          return Container(
            height: isMobile ? 64 : 82,
            padding: EdgeInsets.symmetric(horizontal: isNarrow ? 10 : 24),
            decoration: const BoxDecoration(
              color: AppTheme.dockBg,
              border: Border(top: BorderSide(color: AppTheme.borderSubtle, width: 1.0)),
            ),
            child: isMobile
                ? _buildMobilePlayer(context, song, isPlaying, isLiked, seekRatio, controller)
                : _buildDesktopPlayer(
                    song,
                    isPlaying,
                    isLiked,
                    pos,
                    dur,
                    hasDuration,
                    maxSec,
                    seekRatio,
                    isShuffle,
                    loop,
                    queueCount,
                    isCompact,
                    isNarrow,
                    controller,
                  ),
          );
        },
      );
    });
  }

  /// Compact single-row mobile layout (<600px) with tap-to-expand and progress bar
  Widget _buildMobilePlayer(
    BuildContext context,
    dynamic song,
    bool isPlaying,
    bool isLiked,
    double seekRatio,
    PlayerController controller,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpenFullPlayer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thin sleek progress indicator along top of miniplayer
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: seekRatio.clamp(0.0, 1.0),
              minHeight: 2.2,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.redAccent),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                // Art thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 44,
                    height: 44,
                    color: const Color(0xFF1F1F24),
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
                // Title & Artist
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song?.title ?? 'No Track Playing',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song?.artist ?? 'Tap to select music',
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
                // Like / Favorite Button
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 20,
                    color: isLiked ? AppTheme.redAccent : AppTheme.textQuiet,
                  ),
                  onPressed: () {
                    if (song != null) controller.toggleLike(song);
                  },
                ),
                // Play / Pause Circle
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: controller.togglePlayPause,
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 22,
                        color: const Color(0xFF18181A),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Next Track Button
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.skip_next_rounded,
                    size: 24,
                    color: Colors.white,
                  ),
                  onPressed: controller.skipToNext,
                  tooltip: 'Next Track',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Full 3-part layout (Left: Now Playing, Center: Controls & Scrubber, Right: Volume & Queue)
  Widget _buildDesktopPlayer(
    dynamic song,
    bool isPlaying,
    bool isLiked,
    Duration pos,
    Duration dur,
    bool hasDuration,
    double maxSec,
    double seekRatio,
    bool isShuffle,
    LoopMode loop,
    int queueCount,
    bool isCompact,
    bool isNarrow,
    PlayerController controller,
  ) {
    return Row(
      children: [
        // ================= LEFT GROUP: NOW PLAYING =================
        ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: 150,
            maxWidth: isNarrow ? 190 : 250,
          ),
          child: Row(
            children: [
              // Clickable Art (Opens Queue)
              InkWell(
                onTap: onToggleQueue,
                borderRadius: BorderRadius.circular(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 44,
                    height: 44,
                    color: const Color(0xFF1F1F24),
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
              ),
              const SizedBox(width: 10),
              // Song Info
              Expanded(
                child: InkWell(
                  onTap: onToggleQueue,
                  borderRadius: BorderRadius.circular(6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song?.title ?? 'No Track Playing',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song?.artist ?? 'Select a song',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Like Toggle Button
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 17,
                  color: isLiked ? AppTheme.redAccent : AppTheme.textQuiet,
                ),
                splashRadius: 15,
                tooltip: isLiked ? 'Liked' : 'Like',
                onPressed: () {
                  if (song != null) controller.toggleLike(song);
                },
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // ================= CENTER GROUP: CONTROLS & SCRUBBER =================
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Transport Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Shuffle
                  IconButton(
                    icon: Icon(
                      Icons.shuffle_rounded,
                      size: 16,
                      color: isShuffle ? AppTheme.redAccent : AppTheme.textQuiet,
                    ),
                    splashRadius: 14,
                    tooltip: isShuffle ? 'Shuffle: On' : 'Shuffle: Off',
                    onPressed: controller.toggleShuffle,
                  ),
                  const SizedBox(width: 6),
                  // Previous
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded, size: 20),
                    color: AppTheme.textSecondary,
                    splashRadius: 16,
                    tooltip: 'Previous',
                    onPressed: controller.skipToPrevious,
                  ),
                  const SizedBox(width: 6),
                  // Main Play / Pause Button (White Circle)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: controller.togglePlayPause,
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 18,
                            color: const Color(0xFF18181A),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Next
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, size: 20),
                    color: AppTheme.textSecondary,
                    splashRadius: 16,
                    tooltip: 'Next',
                    onPressed: controller.skipToNext,
                  ),
                  const SizedBox(width: 6),
                  // Repeat
                  IconButton(
                    icon: Icon(
                      loop == LoopMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      size: 16,
                      color: loop != LoopMode.off ? AppTheme.redAccent : AppTheme.textQuiet,
                    ),
                    splashRadius: 14,
                    tooltip: loop == LoopMode.off
                        ? 'Repeat: Off'
                        : (loop == LoopMode.one ? 'Repeat: One Track' : 'Repeat: All Tracks'),
                    onPressed: controller.cycleLoopMode,
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Continuous Scrubber Rail
              Row(
                children: [
                  // Elapsed time
                  SizedBox(
                    width: 30,
                    child: Text(
                      _formatDuration(pos),
                      style: const TextStyle(
                        color: AppTheme.textQuiet,
                        fontSize: 9.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Scrubber Bar
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
                            height: 18,
                            child: Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                // Background rail
                                Container(
                                  width: trackWidth,
                                  height: 3.5,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2C2D35),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                ),
                                // Active Fill
                                Container(
                                  width: trackWidth * seekRatio,
                                  height: 3.5,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8E7EB),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                ),
                                // White Dot Thumb
                                Positioned(
                                  left: (trackWidth * seekRatio - 4.0).clamp(0.0, trackWidth - 8.0),
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.8),
                                          blurRadius: 4,
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
                  const SizedBox(width: 8),
                  // Total Duration
                  SizedBox(
                    width: 30,
                    child: Text(
                      _formatDuration(dur),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppTheme.textQuiet,
                        fontSize: 9.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // ================= RIGHT GROUP: VOLUME & QUEUE =================
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Volume Controls
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
                  IconButton(
                    icon: Icon(
                      volIcon,
                      size: 18,
                      color: isMuted ? AppTheme.textQuiet : AppTheme.textSecondary,
                    ),
                    splashRadius: 14,
                    tooltip: isMuted ? 'Unmute' : 'Mute',
                    onPressed: controller.toggleMute,
                  ),
                  if (!isCompact) ...[
                    SizedBox(
                      width: 70,
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
                                height: 20,
                                child: Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    Container(
                                      width: sliderWidth,
                                      height: 3.5,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2C2D35),
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                    ),
                                    Container(
                                      width: sliderWidth * vol,
                                      height: 3.5,
                                      decoration: BoxDecoration(
                                        color: isMuted ? AppTheme.textQuiet : const Color(0xFFD7D6DB),
                                        borderRadius: BorderRadius.circular(100),
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
                    const SizedBox(width: 10),
                  ],
                ],
              );
            }),

            // Queue Toggle Button (Pill style matching .queue-btn from mockup)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggleQueue,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isQueueOpen ? AppTheme.redAccent.withOpacity(0.18) : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isQueueOpen ? AppTheme.redAccent.withOpacity(0.5) : AppTheme.borderSubtle,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.queue_music_rounded,
                        size: 14,
                        color: isQueueOpen ? AppTheme.redAccent : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Queue ${queueCount > 0 ? '($queueCount)' : ''}'.trim(),
                        style: TextStyle(
                          color: isQueueOpen ? AppTheme.redAccent : AppTheme.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
