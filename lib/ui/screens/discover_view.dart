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

  Widget _buildSearchBar(DiscoverController controller) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 20, color: AppTheme.redLight),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller.searchInputController,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Search Tamil songs, artists, albums…',
                hintStyle: TextStyle(color: AppTheme.textQuiet, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (query) {
                if (query.trim().isNotEmpty) {
                  controller.search(query.trim());
                }
              },
            ),
          ),
          Obx(() {
            if (controller.isSearching.value || controller.searchInputController.text.isNotEmpty) {
              return GestureDetector(
                onTap: () {
                  controller.clearSearch();
                },
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.close_rounded, size: 18, color: AppTheme.textQuiet),
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DiscoverController>();
    final playerController = Get.find<PlayerController>();

    return Column(
      children: [
        // Modern Unified Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: _buildSearchBar(controller),
        ),

        Expanded(
          child: Obx(() {
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: results.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    return Container(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'SEARCH RESULTS (${results.length})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.redLight,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // Section 1: Top Songs Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.local_fire_department_rounded, color: AppTheme.redAccent, size: 20),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'TOP SONGS & FOLK CLASSICS',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textWhite,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded, color: AppTheme.redAccent, size: 20),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'QUICK PICKS FOR YOU',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textWhite,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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
          }),
        ),
      ],
    );
  }
}
