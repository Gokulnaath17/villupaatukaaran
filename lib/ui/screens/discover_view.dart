import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/discover_controller.dart';
import '../../services/player_controller.dart';
import '../theme/theme_controller.dart';
import '../widgets/boxy_card.dart';
import '../widgets/song_tile.dart';
import '../widgets/tamil_bell_loader.dart';

/// Discover page: Top Songs, Quick Picks, and Search Results
class DiscoverView extends StatelessWidget {
  const DiscoverView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DiscoverController>();
    final playerController = Get.find<PlayerController>();

    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: TamilBellLoader(
            size: 64,
            message: 'Tuning Villu Bow...',
            showGlow: true,
          ),
        );
      }

      // If user is searching and has results
      if (controller.isSearching.value) {
        final results = controller.searchResults;
        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textMuted),
                const SizedBox(height: 12),
                Text(
                  'No results found for "${controller.activeQuery.value}"',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: results.length + 1,
          itemBuilder: (ctx, i) {
            if (i == 0) {
              return Container(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SEARCH RESULTS (${results.length})',
                      style: const TextStyle(
                        color: AppTheme.blueLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    BoxyButton(
                      label: 'PLAY ALL',
                      icon: Icons.play_arrow_rounded,
                      isPrimary: true,
                      onPressed: () => playerController.playSong(results.first, queueContext: results),
                    ),
                  ],
                ),
              );
            }
            final song = results[i - 1];
            return SongTile(
              song: song,
              showIndex: true,
              index: i - 1,
              onTap: () => playerController.playSong(song, queueContext: results, index: i - 1),
            );
          },
        );
      }

      // Normal Discover Feed: Top Songs & Quick Picks
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Section 1: Top Songs Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.local_fire_department_rounded, color: AppTheme.blueAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'TOP SONGS & FOLK CLASSICS',
                    style: TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (controller.topSongs.isNotEmpty)
                BoxyButton(
                  label: 'PLAY ALL',
                  icon: Icons.play_arrow_rounded,
                  isPrimary: true,
                  onPressed: () => playerController.playSong(
                    controller.topSongs.first,
                    queueContext: controller.topSongs,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Top Songs List
          ...controller.topSongs.asMap().entries.map((entry) {
            return SongTile(
              song: entry.value,
              showIndex: true,
              index: entry.key,
              onTap: () => playerController.playSong(
                entry.value,
                queueContext: controller.topSongs,
                index: entry.key,
              ),
            );
          }),

          const SizedBox(height: 28),

          // Section 2: Quick Picks Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: AppTheme.blueAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'QUICK PICKS FOR YOU',
                    style: TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (controller.quickPicks.isNotEmpty)
                BoxyButton(
                  label: 'PLAY ALL',
                  icon: Icons.play_arrow_rounded,
                  isPrimary: false,
                  onPressed: () => playerController.playSong(
                    controller.quickPicks.first,
                    queueContext: controller.quickPicks,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Quick Picks List
          ...controller.quickPicks.asMap().entries.map((entry) {
            return SongTile(
              song: entry.value,
              showIndex: true,
              index: entry.key,
              onTap: () => playerController.playSong(
                entry.value,
                queueContext: controller.quickPicks,
                index: entry.key,
              ),
            );
          }),
        ],
      );
    });
  }
}
