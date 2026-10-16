import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

import '../../services/download_service.dart';
import '../../services/player_controller.dart';
import '../../utils/app_assets.dart';
import '../theme/theme_controller.dart';

/// Full-screen mobile Now Playing modal sheet designed for Android
class MobileNowPlayingSheet extends StatefulWidget {
  final VoidCallback? onOpenQueue;

  const MobileNowPlayingSheet({
    super.key,
    this.onOpenQueue,
  });

  static Future<void> show(BuildContext context, {VoidCallback? onOpenQueue}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MobileNowPlayingSheet(onOpenQueue: onOpenQueue),
    );
  }

  @override
  State<MobileNowPlayingSheet> createState() => _MobileNowPlayingSheetState();
}

class _MobileNowPlayingSheetState extends State<MobileNowPlayingSheet> {
  double? _draggedProgress;

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlayerController>();
    final downloadService = Get.isRegistered<DownloadService>() ? Get.find<DownloadService>() : null;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      height: screenHeight * 0.94,
      decoration: const BoxDecoration(
        color: AppTheme.canvasBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppTheme.borderSubtle, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Obx(() {
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
          final curSec = _draggedProgress ??
              (hasDuration ? pos.inSeconds.toDouble().clamp(0.0, maxSec) : 0.0);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              children: [
                // Top Grabber & Dismiss Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Collapse',
                    ),
                    Column(
                      children: [
                        const Text(
                          'NOW PLAYING',
                          style: TextStyle(
                            color: AppTheme.redLight,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song?.album != null && song!.album!.isNotEmpty ? song.album! : 'Villupaatukaaran',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 22),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onOpenQueue?.call();
                      },
                      tooltip: 'Queue',
                    ),
                  ],
                ),

                const Spacer(),

                // Center Album Artwork
                Center(
                  child: Hero(
                    tag: 'now_playing_art',
                    child: Container(
                      width: screenWidth * 0.76,
                      height: screenWidth * 0.76,
                      constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: isPlaying ? AppTheme.redAccent.withOpacity(0.35) : Colors.black.withOpacity(0.5),
                            blurRadius: isPlaying ? 35 : 20,
                            spreadRadius: isPlaying ? 4 : 0,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: isPlaying ? AppTheme.redAccent.withOpacity(0.6) : AppTheme.borderSubtle,
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: song?.thumbnailUrl != null && song!.thumbnailUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: song.highResThumbnail ?? song.thumbnailUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Image.asset(
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
                ),

                const Spacer(),

                // Song Title & Artist + Favorite Action
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
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            song?.artist ?? 'Select a track to start playback',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isLiked ? AppTheme.redAccent : AppTheme.textQuiet,
                        size: 26,
                      ),
                      onPressed: () {
                        if (song != null) controller.toggleLike(song);
                      },
                      tooltip: isLiked ? 'Unlike' : 'Like',
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Scrubber Slider & Timestamps
                Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3.5,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: AppTheme.redAccent,
                        inactiveTrackColor: Colors.white.withOpacity(0.12),
                        thumbColor: Colors.white,
                        overlayColor: AppTheme.redAccent.withOpacity(0.2),
                      ),
                      child: Slider(
                        value: curSec.clamp(0.0, maxSec),
                        min: 0.0,
                        max: maxSec,
                        onChanged: hasDuration
                            ? (val) => setState(() => _draggedProgress = val)
                            : null,
                        onChangeEnd: hasDuration
                            ? (val) {
                                controller.seek(Duration(seconds: val.toInt()));
                                setState(() => _draggedProgress = null);
                              }
                            : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(Duration(seconds: curSec.toInt())),
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            hasDuration ? _formatDuration(dur) : '--:--',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Primary Playback Controls Row (Shuffle, Previous, Play/Pause, Next, Repeat)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.shuffle_rounded,
                        size: 24,
                        color: isShuffle ? AppTheme.redLight : AppTheme.textQuiet,
                      ),
                      onPressed: controller.toggleShuffle,
                      tooltip: isShuffle ? 'Shuffle On' : 'Shuffle Off',
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, size: 34, color: Colors.white),
                      onPressed: controller.skipToPrevious,
                      tooltip: 'Previous',
                    ),
                    // Large Play / Pause button
                    GestureDetector(
                      onTap: controller.togglePlayPause,
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          gradient: AppTheme.redGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.redAccent.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: isBuffering
                              ? const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Icon(
                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  size: 38,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, size: 34, color: Colors.white),
                      onPressed: controller.skipToNext,
                      tooltip: 'Next',
                    ),
                    IconButton(
                      icon: Icon(
                        loop == LoopMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        size: 24,
                        color: loop != LoopMode.off ? AppTheme.redLight : AppTheme.textQuiet,
                      ),
                      onPressed: controller.cycleLoopMode,
                      tooltip: 'Loop Mode: ${loop.name}',
                    ),
                  ],
                ),

                const Spacer(),

                // Bottom Utility Actions (Download, Queue, Share)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (downloadService != null && song != null)
                      Obx(() {
                        final isDownloaded = downloadService.isSongDownloaded(song.videoId);
                        final isDownloading = downloadService.isSongDownloading(song.videoId);

                        return TextButton.icon(
                          onPressed: isDownloading
                              ? null
                              : () => downloadService.downloadSong(song),
                          icon: Icon(
                            isDownloaded
                                ? Icons.download_done_rounded
                                : isDownloading
                                    ? Icons.downloading_rounded
                                    : Icons.download_rounded,
                            size: 18,
                            color: isDownloaded ? AppTheme.redLight : AppTheme.textSecondary,
                          ),
                          label: Text(
                            isDownloaded ? 'Downloaded' : isDownloading ? 'Downloading…' : 'Download',
                            style: TextStyle(
                              color: isDownloaded ? AppTheme.redLight : AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        }),
      ),
    );
  }
}
