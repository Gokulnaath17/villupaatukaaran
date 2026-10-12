import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/player_controller.dart';
import '../../utils/app_assets.dart';
import '../theme/theme_controller.dart';
import '../widgets/player_card.dart';
import '../widgets/queue_list.dart';
import '../widgets/search_bar_widget.dart';
import 'discover_view.dart';
import 'library_view.dart';
import 'settings_view.dart';

/// Main container with sticky top bar, dual-pane layout, and sticky right-side player & queue
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0; // 0: Discover, 1: Library, 2: Settings

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkCanvas,
      body: Stack(
        children: [
          // Ambient Wallpaper Layer (derived from base image)
          Positioned.fill(
            child: Image.asset(
              AppAssets.backgroundLandscape,
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.22),
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

          // Deep AMOLED Vignette Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.75),
                    AppTheme.darkCanvas.withOpacity(0.92),
                    Colors.black.withOpacity(0.98),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Sticky Top Bar (Brand + Search + Tabs)
                _buildStickyTopBar(),

                // Main Content Area (Responsive Split-view)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWideScreen = constraints.maxWidth >= 820;

                      if (isWideScreen) {
                        return _buildWideDualPaneLayout();
                      } else {
                        return _buildNarrowLayout();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sticky Top Bar with Brand, Search, and Boxy Tabs
  Widget _buildStickyTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.darkCanvas,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1.0)),
      ),
      child: Row(
        children: [
          // Brand Logo & Title
          InkWell(
            onTap: () => setState(() => _currentNavIndex = 0),
            borderRadius: BorderRadius.zero,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.yellowAccent, width: 1.0),
                  ),
                  child: Image.asset(AppAssets.appIcon, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
                const Text(
                  'VILLUPAATUKARAN',
                  style: TextStyle(
                    color: AppTheme.yellowAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Search Bar
          const Expanded(
            child: SearchBarWidget(),
          ),
          const SizedBox(width: 16),

          // Boxy Navigation Tabs
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildNavTab('DISCOVER', 0, Icons.explore),
              const SizedBox(width: 4),
              _buildNavTab('LIBRARY', 1, Icons.library_music),
              const SizedBox(width: 4),
              _buildNavTab('SETTINGS', 2, Icons.settings),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavTab(String label, int index, IconData icon) {
    final isSelected = _currentNavIndex == index;

    return InkWell(
      onTap: () => setState(() => _currentNavIndex = index),
      borderRadius: BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.yellowAccent : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppTheme.yellowAccent : AppTheme.border,
            width: 1.0,
          ),
          borderRadius: BorderRadius.zero,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppTheme.black : AppTheme.textPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.black : AppTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dual-pane Desktop / Wide Layout: Left (Main feed) + Right (Sticky Player & Queue)
  Widget _buildWideDualPaneLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Pane: Discover, Library, or Settings (scrolls smoothly)
        Expanded(
          flex: 6,
          child: _getActiveScreen(),
        ),

        // Vertical Divider Line
        const VerticalDivider(width: 1, thickness: 1, color: AppTheme.border),

        // Right Pane: Sticky Player Card with Queue below it
        const SizedBox(
          width: 380,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sticky Player Card
                PlayerCard(),
                SizedBox(height: 12),

                // Live Queue below Player Card (scrolls inside this pane without overflowing)
                Expanded(
                  child: QueueList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Single-pane Mobile / Compact Layout with Bottom Mini-Player
  Widget _buildNarrowLayout() {
    final playerController = Get.find<PlayerController>();

    return Column(
      children: [
        Expanded(
          child: _getActiveScreen(),
        ),

        // Bottom Mini Player Bar
        Obx(() {
          final song = playerController.currentSong.value;
          if (song == null) return const SizedBox.shrink();

          final isPlaying = playerController.isPlaying.value;

          return Container(
            height: 60,
            decoration: const BoxDecoration(
              color: AppTheme.cardSurfaceElevated,
              border: Border(top: BorderSide(color: AppTheme.yellowAccent, width: 1.5)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: song.thumbnailUrl != null
                      ? Image.network(
                          song.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Image.asset(AppAssets.defaultCover, fit: BoxFit.cover),
                        )
                      : Image.asset(AppAssets.defaultCover, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.yellowLight,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: AppTheme.yellowAccent,
                  ),
                  onPressed: playerController.togglePlayPause,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, color: AppTheme.textPrimary),
                  onPressed: playerController.skipToNext,
                ),
                IconButton(
                  icon: const Icon(Icons.queue_music, color: AppTheme.textSecondary),
                  onPressed: () => _showMobileQueueSheet(context),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showMobileQueueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkCanvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: AppTheme.border),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.85,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                PlayerCard(),
                SizedBox(height: 12),
                Expanded(child: QueueList()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _getActiveScreen() {
    switch (_currentNavIndex) {
      case 0:
        return const DiscoverView();
      case 1:
        return const LibraryView();
      case 2:
        return const SettingsView();
      default:
        return const DiscoverView();
    }
  }
}

