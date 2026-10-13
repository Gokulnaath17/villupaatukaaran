import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../models/song_item.dart';
import '../../services/cache_service.dart';
import '../../services/discover_controller.dart';
import '../../services/download_service.dart';
import '../../services/library_service.dart';
import '../../services/player_controller.dart';
import '../../utils/app_assets.dart';
import '../theme/theme_controller.dart';
import '../widgets/download_queue_drawer.dart';
import '../widgets/player_dock_bar.dart';
import '../widgets/queue_drawer.dart';
import '../widgets/song_tile.dart';
import '../widgets/tamil_bell_loader.dart';
import 'discover_view.dart';
import 'library_view.dart';
import 'settings_view.dart';

/// Redesigned Villupaatukaaran Main Desktop Shell & Content Viewport
/// Styled directly after villupaatukaaran-redesign.html
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Navigation key: 'home', 'discover', 'library_all', 'library_downloaded', 'library_cached', 'library_local', 'library_liked', 'playlists_all', 'playlist_<id>', 'settings', 'search'
  String _activeNavKey = 'home';
  String? _selectedPlaylistId;
  bool _isQueueOpen = false;
  bool _isDownloadsOpen = false;

  // History stack for topbar back/forward buttons
  final List<String> _navHistory = ['home'];
  int _navHistoryIndex = 0;

  // Search input & focus
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Active Spotlight Category / Artist
  String _selectedArtistKey = 'trending';

  final Map<String, Map<String, String>> _artistsMetadata = {
    'trending': {
      'name': 'Trending Tamil Hits',
      'badge': "TODAY'S TOP HITS",
      'subtitle': "From timeless melodies to today's sounds — a little something for every kind of listener.",
      'query': 'Top Tamil Songs',
    },
    'anirudh': {
      'name': 'Anirudh Ravichander',
      'badge': 'ROCKSTAR',
      'subtitle': 'Contemporary Hitmaker • High-Energy Kuthu & Cinematic Anthems',
      'query': 'Anirudh Tamil Hits',
    },
    'rahman': {
      'name': 'A.R. Rahman',
      'badge': 'OSCAR & GRAMMY',
      'subtitle': 'Isai Puyal • Pioneer of Modern Tamil World Music & Classical Integrations',
      'query': 'AR Rahman Tamil Classics',
    },
    'raaja': {
      'name': 'Ilaiyaraaja',
      'badge': 'ISAI GNANI',
      'subtitle': 'Maestro of Symphonic & Rural Tamil Melodies • 1,000+ Soundtracks',
      'query': 'Ilaiyaraaja Tamil Hits',
    },
    'yuvan': {
      'name': 'Yuvan Shankar Raja',
      'badge': 'U1 DRUGS',
      'subtitle': 'Youth Icon • Soulful Melodies, Lo-fi Grooves & Iconic Soundtracks',
      'query': 'Yuvan Shankar Raja Hits',
    },
  };

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _navigateTo(String navKey, {String? playlistId}) {
    if (_activeNavKey == navKey && _selectedPlaylistId == playlistId) return;

    setState(() {
      _activeNavKey = navKey;
      _selectedPlaylistId = playlistId;

      // Truncate forward history if navigating from middle
      if (_navHistoryIndex < _navHistory.length - 1) {
        _navHistory.removeRange(_navHistoryIndex + 1, _navHistory.length);
      }
      _navHistory.add(navKey);
      _navHistoryIndex = _navHistory.length - 1;
    });
  }

  void _navigateBack() {
    if (_navHistoryIndex > 0) {
      setState(() {
        _navHistoryIndex--;
        _activeNavKey = _navHistory[_navHistoryIndex];
        if (!_activeNavKey.startsWith('playlist_')) {
          _selectedPlaylistId = null;
        }
      });
    }
  }

  void _navigateForward() {
    if (_navHistoryIndex < _navHistory.length - 1) {
      setState(() {
        _navHistoryIndex++;
        _activeNavKey = _navHistory[_navHistoryIndex];
        if (!_activeNavKey.startsWith('playlist_')) {
          _selectedPlaylistId = null;
        }
      });
    }
  }

  void _toggleQueue() {
    setState(() {
      _isQueueOpen = !_isQueueOpen;
      if (_isQueueOpen) _isDownloadsOpen = false;
    });
  }

  void _toggleDownloads() {
    setState(() {
      _isDownloadsOpen = !_isDownloadsOpen;
      if (_isDownloadsOpen) _isQueueOpen = false;
    });
  }

  void _switchArtist(String key) {
    setState(() {
      _selectedArtistKey = key;
    });
    if (key == 'trending') {
      Get.find<DiscoverController>().loadHomeFeed();
      return;
    }
    final query = _artistsMetadata[key]?['query'];
    if (query != null) {
      Get.find<DiscoverController>().search(query);
    }
  }

  void _playArtistTop() {
    final discoverController = Get.find<DiscoverController>();
    final playerController = Get.find<PlayerController>();
    final songs = discoverController.topSongs;
    if (songs.isNotEmpty) {
      playerController.playSong(songs.first, queueContext: songs);
    }
  }

  void _shuffleArtist() {
    final discoverController = Get.find<DiscoverController>();
    final playerController = Get.find<PlayerController>();
    final songs = List<SongItem>.from(discoverController.topSongs)..shuffle();
    if (songs.isNotEmpty) {
      playerController.playSong(songs.first, queueContext: songs);
    }
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          _searchFocusNode.requestFocus();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppTheme.canvasBg,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen = constraints.maxWidth >= 600;

              if (isWideScreen) {
                return _buildDesktopWindow(constraints.maxWidth);
              } else {
                return _buildMobileLayout();
              }
            },
          ),
        ),
      ),
    );
  }

  /// Edge-to-Edge Desktop Window
  Widget _buildDesktopWindow(double totalWidth) {
    final isCompactSidebar = totalWidth < 850;

    return Column(
      children: [
        // Main Body (Sidebar + Content Viewport + Slide-out Drawers)
        Expanded(
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Sidebar
                  _buildLeftSidebar(isCompact: isCompactSidebar),

                  // Center Viewport Content
                  Expanded(
                    child: _buildMainViewport(),
                  ),
                ],
              ),

              // Slide-out Queue Drawer
              if (_isQueueOpen)
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: QueueDrawer(onClose: _toggleQueue),
                ),

              // Slide-out Download Queue Drawer
              if (_isDownloadsOpen)
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: DownloadQueueDrawer(onClose: _toggleDownloads),
                ),
            ],
          ),
        ),

        // Persistent Attached Bottom Player Dock Bar
        PlayerDockBar(
          onToggleQueue: _toggleQueue,
          isQueueOpen: _isQueueOpen,
        ),
      ],
    );
  }

  /// Left Sidebar with refined typography and Tamil Villupaatukaaran branding
  Widget _buildLeftSidebar({required bool isCompact}) {
    final libraryService = Get.find<LibraryService>();

    return Container(
      width: isCompact ? 68 : 224,
      decoration: const BoxDecoration(
        color: AppTheme.sidebarBg,
        border: Border(right: BorderSide(color: AppTheme.borderSubtle, width: 1.0)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 14,
        vertical: 20,
      ),
      child: Column(
        crossAxisAlignment: isCompact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          // 1. BRAND BLOCK
          _buildBrandBlock(isCompact),
          const SizedBox(height: 18),

          // Scrollable Nav Sections
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: isCompact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  // SECTION: LISTEN
                  if (!isCompact) _buildNavSectionHeader('LISTEN'),
                  _buildNavItem(
                    label: 'Home',
                    icon: Icons.home_rounded,
                    isActive: _activeNavKey == 'home',
                    isCompact: isCompact,
                    onTap: () => _navigateTo('home'),
                  ),
                  const SizedBox(height: 2),
                  _buildNavItem(
                    label: 'Discover',
                    icon: Icons.explore_rounded,
                    isActive: _activeNavKey == 'discover',
                    isCompact: isCompact,
                    onTap: () => _navigateTo('discover'),
                  ),

                  const SizedBox(height: 16),
                  if (!isCompact) const Divider(color: AppTheme.borderSubtle, height: 1),
                  const SizedBox(height: 14),

                  // SECTION: YOUR LIBRARY
                  if (!isCompact) _buildNavSectionHeader('YOUR LIBRARY'),
                  Obx(() => _buildNavItem(
                        label: 'All Songs',
                        icon: Icons.grid_view_rounded,
                        isActive: _activeNavKey == 'library_all',
                        isCompact: isCompact,
                        badge: '${libraryService.allSongs.length}',
                        onTap: () => _navigateTo('library_all'),
                      )),
                  const SizedBox(height: 2),
                  Obx(() => _buildNavItem(
                        label: 'Liked Songs',
                        icon: Icons.favorite_rounded,
                        isActive: _activeNavKey == 'library_liked',
                        isCompact: isCompact,
                        badge: '${libraryService.likedSongs.length}',
                        accentColor: AppTheme.redAccent,
                        onTap: () => _navigateTo('library_liked'),
                      )),
                  const SizedBox(height: 2),
                  Obx(() => _buildNavItem(
                        label: 'Downloaded',
                        icon: Icons.download_done_rounded,
                        isActive: _activeNavKey == 'library_downloaded',
                        isCompact: isCompact,
                        badge: '${libraryService.downloadedSongs.length}',
                        onTap: () => _navigateTo('library_downloaded'),
                      )),
                  const SizedBox(height: 2),
                  Obx(() {
                    final cacheCount = Get.find<CacheService>().cachedSongsCount.value;
                    return _buildNavItem(
                      label: 'Cached',
                      icon: Icons.bolt_rounded,
                      isActive: _activeNavKey == 'library_cached',
                      isCompact: isCompact,
                      badge: cacheCount > 0 ? '$cacheCount' : null,
                      onTap: () => _navigateTo('library_cached'),
                    );
                  }),
                  const SizedBox(height: 2),
                  Obx(() => _buildNavItem(
                        label: 'Local Files',
                        icon: Icons.folder_rounded,
                        isActive: _activeNavKey == 'library_local',
                        isCompact: isCompact,
                        badge: '${libraryService.localSongs.length}',
                        onTap: () => _navigateTo('library_local'),
                      )),

                  const SizedBox(height: 16),
                  if (!isCompact) const Divider(color: AppTheme.borderSubtle, height: 1),
                  const SizedBox(height: 14),

                  // SECTION: PLAYLISTS
                  if (!isCompact)
                    Padding(
                      padding: const EdgeInsets.only(left: 10, right: 4, bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'PLAYLISTS',
                            style: TextStyle(
                              color: AppTheme.textQuiet,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.3,
                            ),
                          ),
                          InkWell(
                            onTap: () => _showCreatePlaylistDialog(context, libraryService),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Text(
                                '+',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Obx(() {
                    final playlists = libraryService.playlists;
                    if (playlists.isEmpty) {
                      if (isCompact) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Text(
                          'No playlists yet',
                          style: TextStyle(color: AppTheme.textMuted.withOpacity(0.7), fontSize: 11),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: playlists.map((pl) {
                        final isPlActive = _activeNavKey == 'playlist_${pl.id}';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.5),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _navigateTo('playlist_${pl.id}', playlistId: pl.id),
                              borderRadius: AppTheme.radiusSmall,
                              hoverColor: Colors.white.withOpacity(0.04),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isCompact ? 6 : 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isPlActive ? AppTheme.redAccentSoft : Colors.transparent,
                                  borderRadius: AppTheme.radiusSmall,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      isCompact ? MainAxisAlignment.center : MainAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [Color(0xFF7553A8), Color(0xFFDF8391)],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          '♫',
                                          style: TextStyle(color: Colors.white, fontSize: 11),
                                        ),
                                      ),
                                    ),
                                    if (!isCompact) ...[
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          pl.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isPlActive ? AppTheme.textPrimary : AppTheme.textSecondary,
                                            fontSize: 12,
                                            fontWeight: isPlActive ? FontWeight.w700 : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // SETTINGS ITEM
          _buildNavItem(
            label: 'Settings',
            icon: Icons.settings_rounded,
            isActive: _activeNavKey == 'settings',
            isCompact: isCompact,
            onTap: () => _navigateTo('settings'),
          ),

          // OFFLINE LIBRARY STATUS CARD
          if (!isCompact) ...[
            const SizedBox(height: 10),
            Obx(() {
              final dlCount = libraryService.downloadedSongs.length;
              final cacheCount = Get.find<CacheService>().cachedSongsCount.value;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleDownloads,
                  borderRadius: AppTheme.radiusSmall,
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: AppTheme.cardSurface,
                      borderRadius: AppTheme.radiusSmall,
                      border: Border.all(color: AppTheme.borderSubtle, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Icon(
                                Icons.download_rounded,
                                size: 16,
                                color: AppTheme.redLight,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Offline library',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    dlCount > 0
                                        ? '$dlCount tracks saved'
                                        : (cacheCount > 0 ? '$cacheCount tracks cached' : 'Ready for offline'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 9.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Sleek horizontal progress line
                        Container(
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: dlCount > 0 ? (dlCount / 50.0).clamp(0.1, 1.0) : 0.25,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.redAccent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// Brand block with Tamil letter 'Va' mark
  Widget _buildBrandBlock(bool isCompact) {
    return InkWell(
      onTap: () => _navigateTo('home'),
      borderRadius: AppTheme.radiusSmall,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 0 : 6, vertical: 4),
        child: Row(
          mainAxisAlignment: isCompact ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            // Brand Mark: Gradient rounded box with Tamil "வ"
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF6A78), Color(0xFFDF183D)],
                ),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF32949).withOpacity(0.24),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'வ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (!isCompact) ...[
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Villupaatukaaran',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'MUSIC, WITH ROOTS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textQuiet,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNavSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textQuiet,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required String label,
    required IconData icon,
    required bool isActive,
    required bool isCompact,
    String? badge,
    Color? accentColor,
    required VoidCallback onTap,
  }) {
    final effectiveColor = isActive
        ? (accentColor ?? AppTheme.redLight)
        : AppTheme.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.radiusSmall,
        hoverColor: Colors.white.withOpacity(0.04),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 8 : 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.redAccentSoft : Colors.transparent,
            borderRadius: AppTheme.radiusSmall,
          ),
          child: Row(
            mainAxisAlignment: isCompact ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(icon, size: 17, color: effectiveColor),
              if (!isCompact) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontSize: 12.5,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badge != null && badge != '0')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.redAccent.withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: isActive ? AppTheme.redLight : AppTheme.textQuiet,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Top Navigation Bar (History buttons, Search input with Ctrl+K shortcut, Downloads, Queue, Avatar)
  Widget _buildViewportTopBar() {
    final downloadService = Get.isRegistered<DownloadService>() ? Get.find<DownloadService>() : null;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: AppTheme.canvasBg,
        border: Border(bottom: BorderSide(color: AppTheme.borderSubtle, width: 1.0)),
      ),
      child: Row(
        children: [
          // History Navigation Buttons (< and >)
          Row(
            children: [
              _buildCircleButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Back',
                isEnabled: _navHistoryIndex > 0,
                onTap: _navigateBack,
              ),
              const SizedBox(width: 8),
              _buildCircleButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Forward',
                isEnabled: _navHistoryIndex < _navHistory.length - 1,
                onTap: _navigateForward,
              ),
            ],
          ),

          const Spacer(),

          // Search Field with Shortcut Pill
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320, minWidth: 160),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.cardSurface,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppTheme.borderSubtle, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 11),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 16, color: AppTheme.textQuiet),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'Songs, artists, albums…',
                        hintStyle: TextStyle(color: AppTheme.textQuiet, fontSize: 12),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (query) {
                        if (query.trim().isNotEmpty) {
                          Get.find<DiscoverController>().search(query.trim());
                          _navigateTo('search');
                        }
                      },
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        Get.find<DiscoverController>().clearSearch();
                        _navigateTo('home');
                      },
                      child: const Icon(Icons.close_rounded, size: 14, color: AppTheme.textQuiet),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Ctrl K',
                        style: TextStyle(
                          color: AppTheme.textQuiet,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Top Action Buttons
          Row(
            children: [
              // Download Queue Toggle
              if (downloadService != null)
                Obx(() {
                  final activeCount = downloadService.activeDownloadsCount.value;
                  return IconButton(
                    icon: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.download_rounded,
                          size: 19,
                          color: _isDownloadsOpen || activeCount > 0 ? AppTheme.redAccent : AppTheme.textSecondary,
                        ),
                        if (activeCount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppTheme.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    splashRadius: 16,
                    tooltip: 'Download Queue',
                    onPressed: _toggleDownloads,
                  );
                }),

              // Up Next Queue Toggle
              IconButton(
                icon: Icon(
                  Icons.queue_music_rounded,
                  size: 19,
                  color: _isQueueOpen ? AppTheme.redAccent : AppTheme.textSecondary,
                ),
                splashRadius: 16,
                tooltip: 'Up Next Queue',
                onPressed: _toggleQueue,
              ),

              const SizedBox(width: 6),

              // Profile / Bard Avatar Badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE1A783), Color(0xFF85506B)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF38383E), width: 1.5),
                ),
                child: const Center(
                  child: Text(
                    'வ',
                    style: TextStyle(
                      color: Color(0xFF201B20),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required String tooltip,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFF19191C),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.borderSubtle, width: 1),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isEnabled ? AppTheme.textSecondary : AppTheme.textQuiet.withOpacity(0.4),
          ),
        ),
      ),
    );
  }

  /// Main Viewport Content Routing
  Widget _buildMainViewport() {
    return Column(
      children: [
        _buildViewportTopBar(),
        Expanded(
          child: _buildActiveContentView(),
        ),
      ],
    );
  }

  Widget _buildActiveContentView() {
    if (_activeNavKey == 'settings') {
      return const SettingsView();
    }
    if (_activeNavKey == 'discover' || _activeNavKey == 'search') {
      return const DiscoverView();
    }
    if (_activeNavKey == 'library_all') {
      return const LibraryView(initialCategory: LibraryCategory.all);
    }
    if (_activeNavKey == 'library_downloaded') {
      return const LibraryView(initialCategory: LibraryCategory.downloaded);
    }
    if (_activeNavKey == 'library_cached') {
      return const LibraryView(initialCategory: LibraryCategory.cached);
    }
    if (_activeNavKey == 'library_local') {
      return const LibraryView(initialCategory: LibraryCategory.local);
    }
    if (_activeNavKey == 'library_liked') {
      return const LibraryView(initialCategory: LibraryCategory.liked);
    }
    if (_activeNavKey == 'playlists_all') {
      return const LibraryView(initialCategory: LibraryCategory.playlists);
    }
    if (_activeNavKey.startsWith('playlist_')) {
      return LibraryView(
        initialCategory: LibraryCategory.playlists,
        playlistId: _selectedPlaylistId,
      );
    }

    // Default: 'home'
    return _buildHomeView();
  }

  /// The Full Redesigned Home Viewport (Greeting, Hero Banner, 5-Album Carousel, Lower Split)
  Widget _buildHomeView() {
    final discoverController = Get.find<DiscoverController>();

    return Obx(() {
      if (discoverController.isLoading.value) {
        return const Center(
          child: TamilBellLoader(
            size: 64,
            message: 'Tuning Villu Bow...',
            showGlow: true,
          ),
        );
      }

      final artist = _artistsMetadata[_selectedArtistKey] ?? _artistsMetadata['trending']!;
      final songs = discoverController.topSongs;

      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 24),
        children: [
          // Eyebrow & Dynamic Greeting
          const Text(
            'YOUR SOUND, YOUR ROOTS',
            style: TextStyle(
              color: AppTheme.redLight,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 25,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
              children: [
                TextSpan(text: _getTimeGreeting()),
                const TextSpan(
                  text: '.',
                  style: TextStyle(color: AppTheme.redAccent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ================= HERO FEATURED BANNER =================
          _buildHeroBanner(artist),
          const SizedBox(height: 28),

          // ================= 5-ALBUM CAROUSEL ("Pick up where you left off") =================
          _buildAlbumsSection(),
          const SizedBox(height: 28),

          // ================= LOWER SPLIT (Popular Tracks + Made for your mood) =================
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 880;

              final popularColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Popular right now',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Tracks making the rounds.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => _navigateTo('discover'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          'View all  ↗',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Track list
                  if (songs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No tracks loaded. Try switching spotlight or searching.',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: songs.length > 5 ? 5 : songs.length,
                      itemBuilder: (ctx, i) {
                        return SongTile(
                          song: songs[i],
                          showIndex: true,
                          index: i,
                          onTap: () {
                            Get.find<PlayerController>().playSong(
                              songs[i],
                              queueContext: songs,
                              index: i,
                            );
                          },
                        );
                      },
                    ),
                ],
              );

              final moodColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Made for your mood',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'A sound for every moment.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => _navigateTo('discover'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          'Explore  ↗',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildMoodMix2x2Grid(),
                ],
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    popularColumn,
                    const SizedBox(height: 28),
                    moodColumn,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 12, child: popularColumn),
                  const SizedBox(width: 28),
                  Expanded(flex: 11, child: moodColumn),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      );
    });
  }

  /// Hero Banner directly reproducing CSS from villupaatukaaran-redesign.html
  Widget _buildHeroBanner(Map<String, String> artist) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppTheme.radiusLarge,
        border: Border.all(color: AppTheme.borderSubtle, width: 1),
        gradient: const LinearGradient(
          begin: Alignment(-0.8, -0.6),
          end: Alignment(0.9, 0.8),
          colors: [
            Color(0xFF331F2D),
            Color(0xFF251C2A),
            Color(0xFF191821),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: AppTheme.radiusLarge,
        child: Stack(
          children: [
            // Background Vinyl Record / Radial Rings Geometry (Right Aligned)
            Positioned(
              right: -20,
              top: -30,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.redAccent.withOpacity(0.18),
                      blurRadius: 60,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 25,
              top: 15,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFF20191F),
                      Color(0xFF39303B),
                      Color(0xFF17151B),
                    ],
                  ),
                  border: Border.all(color: const Color(0xFF16151A), width: 5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 35,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xFFFFB4A2),
                          Color(0xFFD64E73),
                          Color(0xFF50264A),
                        ],
                      ),
                      border: Border.all(color: const Color(0xFF29222C), width: 4),
                    ),
                    child: const Center(
                      child: Text(
                        '♪',
                        style: TextStyle(
                          color: Color(0xFFF9D8CF),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Foreground Text Copy & Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'FEATURED MIX · ${artist['badge'] ?? 'TAMIL ESSENTIALS'}',
                    style: const TextStyle(
                      color: Color(0xFFFFB0BA),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    artist['name'] == 'Trending Tamil Hits' ? 'Every beat has\na story.' : artist['name']!,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.9,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Text(
                      artist['subtitle'] ?? '',
                      style: const TextStyle(
                        color: Color(0xFFD1C2CC),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Actions: Primary "Play mix" + Secondary "Shuffle"
                  Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _playArtistTop,
                          borderRadius: BorderRadius.circular(100),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                            decoration: BoxDecoration(
                              color: AppTheme.redAccent,
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.redAccent.withOpacity(0.3),
                                  blurRadius: 18,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Play mix',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _shuffleArtist,
                          borderRadius: BorderRadius.circular(100),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shuffle_rounded, size: 15, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Shuffle',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Quick Spotlight Pills
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Spotlight: ',
                        style: TextStyle(color: Color(0xFFD1C2CC), fontSize: 10.5),
                      ),
                      _buildArtistPill('trending', 'Top Hits'),
                      _buildArtistPill('anirudh', 'Anirudh'),
                      _buildArtistPill('rahman', 'A.R. Rahman'),
                      _buildArtistPill('raaja', 'Ilaiyaraaja'),
                      _buildArtistPill('yuvan', 'Yuvan'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistPill(String key, String label) {
    final isSelected = _selectedArtistKey == key;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _switchArtist(key),
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.redAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isSelected ? AppTheme.redAccent.withOpacity(0.5) : AppTheme.borderSubtle,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// 5-Album Carousel Row ("Pick up where you left off")
  Widget _buildAlbumsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pick up where you left off',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your recent listens, right here.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => _navigateTo('discover'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              child: const Text(
                'See all  ↗',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 5-Card Row
        Row(
          children: [
            Expanded(
              child: _buildAlbumCard(
                title: 'Leo',
                artist: 'Anirudh Ravichander',
                badge: 'FILM · 2023',
                coverTitle: 'LEO',
                imageAsset: AppAssets.albumLeo,
                imageUrl: AppAssets.albumLeoUrl,
                gradientColors: const [Color(0xFFC77753), Color(0xFF632F35), Color(0xFF191A29)],
                query: 'Leo Tamil Songs',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildAlbumCard(
                title: 'Jailer',
                artist: 'Anirudh Ravichander',
                badge: 'FILM · 2023',
                coverTitle: 'JAILER',
                imageAsset: AppAssets.albumJailer,
                imageUrl: AppAssets.albumJailerUrl,
                gradientColors: const [Color(0xFF2B443A), Color(0xFFB77A4D), Color(0xFF351B23)],
                query: 'Jailer Tamil Songs',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildAlbumCard(
                title: 'Ponniyin Selvan',
                artist: 'A. R. Rahman',
                badge: 'FILM · 2022',
                coverTitle: 'PONNIYIN SELVAN',
                imageAsset: AppAssets.albumPs1,
                imageUrl: AppAssets.albumPs1Url,
                gradientColors: const [Color(0xFF5E315E), Color(0xFFC47464), Color(0xFF211E36)],
                query: 'Ponniyin Selvan Songs',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildAlbumCard(
                title: 'Vikram',
                artist: 'Anirudh Ravichander',
                badge: 'FILM · 2022',
                coverTitle: 'VIKRAM',
                imageAsset: AppAssets.albumVikram,
                imageUrl: AppAssets.albumVikramUrl,
                gradientColors: const [Color(0xFF202C38), Color(0xFF8D3438), Color(0xFF15151B)],
                query: 'Vikram Tamil Songs',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildAlbumCard(
                title: 'Thalapathi',
                artist: 'Ilaiyaraaja',
                badge: 'CLASSIC · 1991',
                coverTitle: 'THALAPATHI',
                imageAsset: AppAssets.albumThalapathi,
                imageUrl: AppAssets.albumThalapathiUrl,
                gradientColors: const [Color(0xFF6A784C), Color(0xFFC1A36A), Color(0xFF29362B)],
                query: 'Thalapathi Tamil Songs',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlbumCard({
    required String title,
    required String artist,
    required String badge,
    required String coverTitle,
    required List<Color> gradientColors,
    required String query,
    String? imageAsset,
    String? imageUrl,
  }) {
    return _AlbumHoverCard(
      title: title,
      artist: artist,
      badge: badge,
      coverTitle: coverTitle,
      gradientColors: gradientColors,
      query: query,
      imageAsset: imageAsset,
      imageUrl: imageUrl,
      onTap: () {
        Get.find<DiscoverController>().search(query);
        _navigateTo('search');
      },
    );
  }

  /// 2x2 Grid for "Made for your mood"
  Widget _buildMoodMix2x2Grid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMoodCard(
                title: 'Folk Heritage',
                subtitle: 'Parambariyam · 28 tracks',
                iconText: '♬',
                gradient: const [Color(0xFFBF8A52), Color(0xFF536346)],
                query: 'Tamil Traditional Folk Songs',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMoodCard(
                title: 'Gaana & Kuthu',
                subtitle: 'Full volume · 34 tracks',
                iconText: '♫',
                gradient: const [Color(0xFFAB5865), Color(0xFF3E2C51)],
                query: 'Tamil Gaana Kuthu Songs',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMoodCard(
                title: 'Midnight Melodies',
                subtitle: 'Slow down · 22 tracks',
                iconText: '☾',
                gradient: const [Color(0xFF2B3E6F), Color(0xFF9D668F)],
                query: 'Tamil Midnight Melodies Acoustic',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMoodCard(
                title: 'Acoustic & Classical',
                subtitle: 'Just listen · 19 tracks',
                iconText: '❋',
                gradient: const [Color(0xFF8E7244), Color(0xFF3D5553)],
                query: 'Tamil Classical Acoustic Songs',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMoodCard({
    required String title,
    required String subtitle,
    required String iconText,
    required List<Color> gradient,
    required String query,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Get.find<DiscoverController>().search(query);
          _navigateTo('search');
        },
        borderRadius: AppTheme.radiusMedium,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.cardSurface,
            borderRadius: AppTheme.radiusMedium,
            border: Border.all(color: AppTheme.borderSubtle, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    iconText,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: AppTheme.redAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Create Playlist Dialog
  void _showCreatePlaylistDialog(BuildContext context, LibraryService libraryService) {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.radiusLarge,
            side: const BorderSide(color: AppTheme.borderHighlight),
          ),
          title: const Text(
            'CREATE NEW PLAYLIST',
            style: TextStyle(
              color: AppTheme.redAccent,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          content: TextField(
            controller: titleController,
            autofocus: true,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13.5),
            decoration: const InputDecoration(
              hintText: 'Playlist Name',
              hintStyle: TextStyle(color: AppTheme.textQuiet),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.borderSubtle),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.redAccent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final name = titleController.text.trim();
                if (name.isNotEmpty) {
                  final newPl = await libraryService.createPlaylist(name);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    _navigateTo('playlist_${newPl.id}', playlistId: newPl.id);
                  }
                }
              },
              child: const Text('CREATE', style: TextStyle(color: AppTheme.redAccent, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  /// Compact Mobile / Narrow Screen Layout
  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Mobile Top Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppTheme.sidebarBg,
            border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: AppTheme.redGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'வ',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Villupaatukaaran',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                onPressed: _toggleDownloads,
                tooltip: 'Download Queue',
              ),
              IconButton(
                icon: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 20),
                onPressed: _toggleQueue,
                tooltip: 'Play Queue',
              ),
            ],
          ),
        ),

        // Content (Viewport + Drawers)
        Expanded(
          child: Stack(
            children: [
              _buildMainViewport(),
              if (_isQueueOpen)
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: QueueDrawer(onClose: _toggleQueue),
                ),
              if (_isDownloadsOpen)
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: DownloadQueueDrawer(onClose: _toggleDownloads),
                ),
            ],
          ),
        ),

        // Attached Bottom Player Dock
        PlayerDockBar(
          onToggleQueue: _toggleQueue,
          isQueueOpen: _isQueueOpen,
        ),
      ],
    );
  }
}

/// Modern Glassmorphic Album Card with Artwork Thumbnail and Hover Play Action
class _AlbumHoverCard extends StatefulWidget {
  final String title;
  final String artist;
  final String badge;
  final String coverTitle;
  final List<Color> gradientColors;
  final String query;
  final String? imageAsset;
  final String? imageUrl;
  final VoidCallback onTap;

  const _AlbumHoverCard({
    required this.title,
    required this.artist,
    required this.badge,
    required this.coverTitle,
    required this.gradientColors,
    required this.query,
    this.imageAsset,
    this.imageUrl,
    required this.onTap,
  });

  @override
  State<_AlbumHoverCard> createState() => _AlbumHoverCardState();
}

class _AlbumHoverCardState extends State<_AlbumHoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                transform: _isHovered
                    ? (Matrix4.identity()..translate(0.0, -3.0))
                    : Matrix4.identity(),
                decoration: BoxDecoration(
                  borderRadius: AppTheme.radiusCard,
                  boxShadow: [
                    BoxShadow(
                      color: _isHovered
                          ? AppTheme.accentCoral.withOpacity(0.25)
                          : Colors.black.withOpacity(0.4),
                      blurRadius: _isHovered ? 18 : 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: AppTheme.radiusCard,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Base gradient background
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: widget.gradientColors,
                          ),
                        ),
                      ),

                      // Thumbnail Artwork (Local Asset with Network Fallback)
                      if (widget.imageAsset != null)
                        Image.asset(
                          widget.imageAsset!,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) {
                            if (widget.imageUrl != null) {
                              return CachedNetworkImage(
                                imageUrl: widget.imageUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const SizedBox.shrink(),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        )
                      else if (widget.imageUrl != null)
                        CachedNetworkImage(
                          imageUrl: widget.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),

                      // Vignette / Gradient Scrim for typography contrast
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.45),
                              Colors.transparent,
                              Colors.black.withOpacity(0.88),
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),

                      // Sleek Glassmorphic Badge (Top Right)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.5),
                          ),
                          child: Text(
                            widget.badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),

                      // Cover Title (Bottom Left)
                      Positioned(
                        left: 10,
                        right: 42,
                        bottom: 8,
                        child: Text(
                          widget.coverTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 8),
                            ],
                          ),
                        ),
                      ),

                      // Hover Play Button (Bottom Right)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _isHovered ? 1.0 : 0.0,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppTheme.accentCoral,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accentCoral.withOpacity(0.5),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.artist,
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
    );
  }
}

