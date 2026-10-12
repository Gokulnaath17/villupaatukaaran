import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../models/song_item.dart';
import '../../services/cache_service.dart';
import '../../services/discover_controller.dart';
import '../../services/library_service.dart';
import '../../services/player_controller.dart';
import '../../services/settings_controller.dart';
import '../../utils/app_assets.dart';
import '../theme/theme_controller.dart';
import '../widgets/player_dock_bar.dart';
import '../widgets/queue_drawer.dart';
import '../widgets/song_tile.dart';
import '../widgets/tamil_bell_loader.dart';
import 'discover_view.dart';
import 'library_view.dart';
import 'settings_view.dart';

/// Modern Desktop Music Player Window (inspired by mod.png)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Navigation key: 'home', 'library_all', 'library_downloaded', 'library_cached', 'library_local', 'library_liked', 'playlists_all', 'playlist_<id>', 'settings', 'search'
  String _activeNavKey = 'home';
  String? _selectedPlaylistId;
  bool _isLibraryExpanded = true;
  bool _isPlaylistsExpanded = true;
  bool _isQueueOpen = false;

  // Active Spotlight Artist
  String _selectedArtistKey = 'subbu';
  final TextEditingController _searchController = TextEditingController();

  final Map<String, Map<String, String>> _artistsMetadata = {
    'subbu': {
      'name': 'Subbu Arumugam',
      'badge': 'PADMA SHRI',
      'subtitle': 'Legendary Tamil Villu Paatu Bard • 40+ Years of Folk Ballads',
      'query': 'Subbu Arumugam Villu Paatu',
    },
    'raaja': {
      'name': 'Ilaiyaraaja',
      'badge': 'ISAI GNANI',
      'subtitle': 'Maestro of Symphonic & Rural Tamil Melodies • 1,000+ Soundtracks',
      'query': 'Ilaiyaraaja Tamil Hits',
    },
    'rahman': {
      'name': 'AR Rahman',
      'badge': 'OSCAR & GRAMMY',
      'subtitle': 'Isai Puyal • Pioneer of Modern Tamil World Music & Folk Integrations',
      'query': 'AR Rahman Tamil Classics',
    },
    'anirudh': {
      'name': 'Anirudh Ravichander',
      'badge': 'ROCKSTAR',
      'subtitle': 'Contemporary Hitmaker • High-Energy Kuthu & Cinematic Anthems',
      'query': 'Anirudh Tamil Hits',
    },
  };

  void _toggleQueue() {
    setState(() {
      _isQueueOpen = !_isQueueOpen;
    });
  }

  void _switchArtist(String key) {
    setState(() {
      _selectedArtistKey = key;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.windowBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth >= 760;

          if (isWideScreen) {
            return _buildDesktopWindow();
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }

  /// Edge-to-Edge Desktop Window
  Widget _buildDesktopWindow() {
    return Column(
      children: [
        // Main Body (Sidebar + Content Viewport + Slide-out Queue)
        Expanded(
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Sidebar: Pinned directly to the left edge of the OS window
                  _buildLeftSidebar(),

                  // Center Viewport Content: Fills all remaining space
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

  /// Left Sidebar with Hierarchical Dropdown Navigation (starts directly with Home, Library, Playlists)
  Widget _buildLeftSidebar() {
    final libraryService = Get.find<LibraryService>();
    final cacheService = Get.find<CacheService>();

    return Container(
      width: 230,
      decoration: const BoxDecoration(
        color: AppTheme.sidebarBg,
        border: Border(right: BorderSide(color: AppTheme.borderSubtle, width: 1.0)),
      ),
      padding: const EdgeInsets.only(top: 20, left: 14, right: 14, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Absolutely nothing at the top - starts directly with the navigation hierarchy!

          // 1. HOME
          _buildParentNavItem(
            label: 'Home',
            icon: Icons.home_rounded,
            isActive: _activeNavKey == 'home',
            onTap: () {
              setState(() {
                _activeNavKey = 'home';
                _selectedPlaylistId = null;
              });
            },
          ),
          const SizedBox(height: 6),

          // 2. LIBRARY (Hierarchical Dropdown)
          Obx(() {
            return _buildHierarchicalDropdown(
              title: 'Library',
              icon: Icons.library_music_rounded,
              isExpanded: _isLibraryExpanded,
              onToggle: () {
                setState(() => _isLibraryExpanded = !_isLibraryExpanded);
              },
              children: [
                _buildChildNavItem(
                  label: 'All Songs',
                  icon: Icons.grid_view_rounded,
                  navKey: 'library_all',
                  badge: '${libraryService.allSongs.length}',
                ),
                _buildChildNavItem(
                  label: 'Downloaded',
                  icon: Icons.download_done_rounded,
                  navKey: 'library_downloaded',
                  badge: '${libraryService.downloadedSongs.length}',
                ),
                _buildChildNavItem(
                  label: 'Cached',
                  icon: Icons.bolt_rounded,
                  navKey: 'library_cached',
                  badge: '${cacheService.cachedSongsCount.value}',
                ),
                _buildChildNavItem(
                  label: 'Local Files',
                  icon: Icons.folder_rounded,
                  navKey: 'library_local',
                  badge: '${libraryService.localSongs.length}',
                ),
                _buildChildNavItem(
                  label: 'Liked Songs',
                  icon: Icons.favorite_rounded,
                  navKey: 'library_liked',
                  badge: '${libraryService.likedSongs.length}',
                  accentColor: AppTheme.trafficRed,
                ),
              ],
            );
          }),
          const SizedBox(height: 6),

          // 3. PLAYLISTS (Hierarchical Dropdown)
          Obx(() {
            final playlists = libraryService.playlists;

            return _buildHierarchicalDropdown(
              title: 'Playlists',
              icon: Icons.playlist_play_rounded,
              isExpanded: _isPlaylistsExpanded,
              onToggle: () {
                setState(() => _isPlaylistsExpanded = !_isPlaylistsExpanded);
              },
              onAdd: () => _showCreatePlaylistDialog(context, libraryService),
              children: [
                _buildChildNavItem(
                  label: 'All Playlists',
                  icon: Icons.dashboard_rounded,
                  navKey: 'playlists_all',
                  badge: '${playlists.length}',
                ),
                ...playlists.map((pl) {
                  return _buildChildNavItem(
                    label: pl.title,
                    icon: Icons.queue_music_rounded,
                    navKey: 'playlist_${pl.id}',
                    badge: '${pl.songCount}',
                    onCustomTap: () {
                      setState(() {
                        _activeNavKey = 'playlist_${pl.id}';
                        _selectedPlaylistId = pl.id;
                      });
                    },
                  );
                }),
              ],
            );
          }),

          const Spacer(),

          // 4. SETTINGS
          _buildParentNavItem(
            label: 'Settings',
            icon: Icons.settings_rounded,
            isActive: _activeNavKey == 'settings',
            onTap: () {
              setState(() {
                _activeNavKey = 'settings';
                _selectedPlaylistId = null;
              });
            },
          ),
          const SizedBox(height: 12),

          // Bottom Offline Cache Card
          Obx(() {
            final cachedCount = cacheService.cachedSongsCount.value;
            final settings = Get.find<SettingsController>();
            final maxLimit = settings.cacheSizeLimit.value;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showCacheVaultDialog(context),
                borderRadius: AppTheme.radiusMedium,
                hoverColor: Colors.white.withOpacity(0.04),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF191B26),
                    borderRadius: AppTheme.radiusMedium,
                    border: Border.all(color: AppTheme.borderSubtle, width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.sd_storage_rounded, size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Offline Cache',
                              style: TextStyle(
                                color: AppTheme.textWhite,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.trafficGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$cachedCount/$maxLimit Tracks • Ready',
                                  style: const TextStyle(
                                    color: AppTheme.trafficGreen,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.textMuted),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildParentNavItem({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.radiusSmall,
        hoverColor: Colors.white.withOpacity(0.04),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8.5),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.blueAccent.withOpacity(0.14) : Colors.transparent,
            borderRadius: AppTheme.radiusSmall,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? AppTheme.blueAccent : AppTheme.textWhite,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? AppTheme.blueAccent : AppTheme.textWhite,
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHierarchicalDropdown({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    VoidCallback? onAdd,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Parent Header Row
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggle,
            borderRadius: AppTheme.radiusSmall,
            hoverColor: Colors.white.withOpacity(0.04),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8.5),
              child: Row(
                children: [
                  Icon(icon, size: 17, color: AppTheme.textWhite),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (onAdd != null)
                    InkWell(
                      onTap: onAdd,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.add_rounded, size: 16, color: AppTheme.blueAccent),
                      ),
                    ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                    size: 18,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Sub-content with tree guide line
        if (isExpanded)
          Container(
            margin: const EdgeInsets.only(left: 17, top: 2, bottom: 4),
            padding: const EdgeInsets.only(left: 10),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppTheme.borderSubtle, width: 1.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
      ],
    );
  }

  Widget _buildChildNavItem({
    required String label,
    required IconData icon,
    required String navKey,
    String? badge,
    Color? accentColor,
    VoidCallback? onCustomTap,
  }) {
    final isActive = _activeNavKey == navKey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (onCustomTap != null) {
              onCustomTap();
            } else {
              setState(() {
                _activeNavKey = navKey;
                _selectedPlaylistId = null;
              });
            }
          },
          borderRadius: AppTheme.radiusSmall,
          hoverColor: Colors.white.withOpacity(0.04),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6.5),
            decoration: BoxDecoration(
              color: isActive ? AppTheme.blueAccent.withOpacity(0.12) : Colors.transparent,
              borderRadius: AppTheme.radiusSmall,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isActive
                      ? (accentColor ?? AppTheme.blueAccent)
                      : AppTheme.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActive ? AppTheme.textWhite : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badge != null && badge != '0')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.blueAccent.withOpacity(0.25)
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: isActive ? AppTheme.blueAccent : AppTheme.textMuted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, LibraryService libraryService) {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.windowBg,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.radiusLarge,
            side: const BorderSide(color: AppTheme.borderHighlight),
          ),
          title: const Text(
            'CREATE NEW PLAYLIST',
            style: TextStyle(
              color: AppTheme.blueAccent,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          content: TextField(
            controller: titleController,
            autofocus: true,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Playlist Name',
              hintStyle: TextStyle(color: AppTheme.textMuted),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.borderSubtle),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.blueAccent),
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
                    setState(() {
                      _activeNavKey = 'playlist_${newPl.id}';
                      _selectedPlaylistId = newPl.id;
                      _isPlaylistsExpanded = true;
                    });
                  }
                }
              },
              child: const Text('CREATE', style: TextStyle(color: AppTheme.blueAccent)),
            ),
          ],
        );
      },
    );
  }

  /// Sleek Desktop Viewport Top Bar (Breadcrumb + Search Bar + Queue Toggle)
  Widget _buildViewportTopBar() {
    String breadcrumb = 'HOME';
    if (_activeNavKey == 'library_all') {
      breadcrumb = 'LIBRARY  /  ALL SONGS';
    } else if (_activeNavKey == 'library_downloaded') {
      breadcrumb = 'LIBRARY  /  DOWNLOADED';
    } else if (_activeNavKey == 'library_cached') {
      breadcrumb = 'LIBRARY  /  CACHED TRACKS';
    } else if (_activeNavKey == 'library_local') {
      breadcrumb = 'LIBRARY  /  LOCAL FILES';
    } else if (_activeNavKey == 'library_liked') {
      breadcrumb = 'LIBRARY  /  LIKED SONGS';
    } else if (_activeNavKey == 'playlists_all') {
      breadcrumb = 'PLAYLISTS  /  ALL';
    } else if (_activeNavKey.startsWith('playlist_')) {
      breadcrumb = 'PLAYLISTS  /  DETAIL';
    } else if (_activeNavKey == 'settings') {
      breadcrumb = 'SETTINGS';
    } else if (_activeNavKey == 'search') {
      breadcrumb = 'SEARCH RESULTS';
    }

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppTheme.windowBg,
        border: Border(bottom: BorderSide(color: AppTheme.borderSubtle, width: 1)),
      ),
      child: Row(
        children: [
          // Breadcrumb text
          Text(
            breadcrumb,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),

          // Search Field
          Container(
            width: 250,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF181A25),
              borderRadius: AppTheme.radiusSmall,
              border: Border.all(color: AppTheme.borderSubtle, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 15, color: AppTheme.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AppTheme.textWhite, fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Search songs, bards...',
                      hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (query) {
                      if (query.trim().isNotEmpty) {
                        Get.find<DiscoverController>().search(query.trim());
                        setState(() => _activeNavKey = 'search');
                      }
                    },
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      Get.find<DiscoverController>().clearSearch();
                      setState(() => _activeNavKey = 'home');
                    },
                    child: const Icon(Icons.close_rounded, size: 14, color: AppTheme.textMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Queue button
          IconButton(
            icon: Icon(
              Icons.queue_music_rounded,
              color: _isQueueOpen ? AppTheme.blueAccent : AppTheme.textSecondary,
              size: 20,
            ),
            splashRadius: 18,
            onPressed: _toggleQueue,
          ),
        ],
      ),
    );
  }

  /// Main Viewport Content (Top Bar + View Routing)
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
    if (_activeNavKey == 'search') {
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
    return _buildHeroSpotlightAndGrids();
  }

  /// The Full mod.png Layout: Hero Banner + 5-Album Carousel + Lower Split
  Widget _buildHeroSpotlightAndGrids() {
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

      final artist = _artistsMetadata[_selectedArtistKey] ?? _artistsMetadata['subbu']!;
      final songs = discoverController.topSongs;

      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        children: [
          // ================= HERO ARTIST SPOTLIGHT BANNER =================
          _buildHeroBanner(artist),
          const SizedBox(height: 28),

          // ================= 5-ALBUM CAROUSEL ROW =================
          _buildAlbumCarouselRow(),
          const SizedBox(height: 32),

          // ================= LOWER TWO-COLUMN SPLIT =================
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Popular Songs
              Expanded(
                flex: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Popular Tracks',
                          style: TextStyle(
                            color: AppTheme.textWhite,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${songs.length} tracks',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // List of Popular Tracks
                    if (songs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No songs loaded. Try searching or switching spotlight.',
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
                            showIndex: false,
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
                ),
              ),
              const SizedBox(width: 28),

              // Right Column: 2x2 Photographic Curated Playlists
              Expanded(
                flex: 11,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Curated Playlists',
                      style: TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPlaylists2x2Grid(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      );
    });
  }

  /// Hero Spotlight Banner with Cutout Silhouette, Badges, and Action Buttons
  Widget _buildHeroBanner(Map<String, String> artist) {
    return SizedBox(
      height: 210,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Back button
          Positioned(
            top: 0,
            left: 0,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _switchArtist('subbu'),
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.borderSubtle, width: 1),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white),
                ),
              ),
            ),
          ),

          // Cutout Silhouette of Bard with Villu Bow
          Positioned(
            left: 50,
            bottom: -10,
            child: SizedBox(
              width: 190,
              height: 210,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Ambient Blue/Amber glow behind silhouette
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.blueAccent.withOpacity(0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // Logo / Bard Cutout Image
                  Image.asset(
                    AppAssets.logo,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person_pin_rounded,
                      size: 110,
                      color: AppTheme.blueAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Artist Details and Controls (Title, Subtitle, Shuffle & Play buttons)
          Positioned(
            left: 260,
            right: 0,
            bottom: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            artist['name'] ?? '',
                            style: const TextStyle(
                              color: AppTheme.textWhite,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.blueAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: AppTheme.blueAccent.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              artist['badge'] ?? '',
                              style: const TextStyle(
                                color: AppTheme.blueLight,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        artist['subtitle'] ?? '',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Quick Spotlight Pills
                      Row(
                        children: [
                          const Text(
                            'Quick spotlight: ',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          ),
                          _buildArtistPill('subbu', 'Subbu Arumugam'),
                          const SizedBox(width: 6),
                          _buildArtistPill('raaja', 'Ilaiyaraaja'),
                          const SizedBox(width: 6),
                          _buildArtistPill('rahman', 'AR Rahman'),
                          const SizedBox(width: 6),
                          _buildArtistPill('anirudh', 'Anirudh'),
                        ],
                      ),
                    ],
                  ),
                ),

                // Shuffle & Play Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _shuffleArtist,
                        borderRadius: BorderRadius.circular(100),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.06),
                            border: Border.all(color: AppTheme.borderSubtle, width: 1),
                          ),
                          child: const Icon(
                            Icons.shuffle_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _playArtistTop,
                        borderRadius: BorderRadius.circular(100),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.blueGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.blueGlow,
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 26,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
            color: isSelected ? AppTheme.blueAccent.withOpacity(0.18) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isSelected ? AppTheme.blueAccent.withOpacity(0.5) : AppTheme.borderSubtle,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// 5-Album Carousel Row (matching mod.png colors & layout with transparent thumbnail images)
  Widget _buildAlbumCarouselRow() {
    return Row(
      children: [
        Expanded(
          child: _buildAlbumCard(
            title: 'Villisai Paamalai',
            year: '1982',
            svgAsset: AppAssets.cardThumb1,
            color: AppTheme.albumYellow,
            query: 'Subbu Arumugam Villisai',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildAlbumCard(
            title: 'Gaana Ulagam',
            year: '2024',
            svgAsset: AppAssets.cardThumb2,
            color: AppTheme.albumCyan,
            query: 'Chennai Gaana Songs',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildAlbumCard(
            title: 'Raaja Kaatril',
            year: '1989',
            svgAsset: AppAssets.cardThumb3,
            color: AppTheme.albumLavender,
            query: 'Ilaiyaraaja 80s Hits',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildAlbumCard(
            title: 'Thalapathi Beats',
            year: '2023',
            svgAsset: AppAssets.cardThumb4,
            color: AppTheme.albumPink,
            query: 'Anirudh Hits',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildAlbumCard(
            title: 'Gramaathu Isai',
            year: '2021',
            svgAsset: AppAssets.cardThumb5,
            color: AppTheme.albumMint,
            query: 'Tamil Village Folk Songs',
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumCard({
    required String title,
    required String year,
    required String svgAsset,
    required Color color,
    required String query,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Get.find<DiscoverController>().search(query);
          setState(() => _activeNavKey = 'search');
        },
        borderRadius: AppTheme.radiusLarge,
        hoverColor: Colors.white.withOpacity(0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: AppTheme.radiusLarge,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SvgPicture.asset(
                    svgAsset,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              year,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 2x2 Photographic Playlists Grid
  Widget _buildPlaylists2x2Grid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildPlaylistCard(
                title: 'Folk Heritage',
                subtitle: 'பாரம்பரியம்',
                imageUrl:
                    'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=80',
                query: 'Tamil Traditional Folk Songs',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPlaylistCard(
                title: 'Gaana & Kuthu',
                subtitle: 'கானா குத்து',
                imageUrl:
                    'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=500&auto=format&fit=crop&q=80',
                query: 'Tamil Gaana Kuthu Songs',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildPlaylistCard(
                title: 'Midnight Melodies',
                subtitle: 'இரவு ராகங்கள்',
                imageUrl:
                    'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=80',
                query: 'Tamil Midnight Melodies Acoustic',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPlaylistCard(
                title: 'Temple & Stories',
                subtitle: 'கோயில் வில்லிசை',
                imageUrl:
                    'https://images.unsplash.com/photo-1544717305-2782549b5136?w=500&auto=format&fit=crop&q=80',
                query: 'Villu Paatu Temple Stories',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaylistCard({
    required String title,
    required String subtitle,
    required String imageUrl,
    required String query,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Get.find<DiscoverController>().search(query);
          setState(() => _activeNavKey = 'search');
        },
        borderRadius: AppTheme.radiusLarge,
        child: Container(
          height: 94,
          decoration: BoxDecoration(
            borderRadius: AppTheme.radiusLarge,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: AppTheme.radiusLarge,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E2235)),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.85),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 6),
                          ],
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Dialog detailing Cache & Storage
  void _showCacheVaultDialog(BuildContext context) {
    final cacheService = Get.find<CacheService>();
    final settings = Get.find<SettingsController>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.windowBg,
        title: const Text(
          'Offline Cache Vault',
          style: TextStyle(color: AppTheme.blueAccent, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tracks in Cache: ${cacheService.cachedSongsCount.value} / ${settings.cacheSizeLimit.value}',
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'All played tracks are auto-cached for offline instant playback without network buffering.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppTheme.blueAccent)),
          ),
        ],
      ),
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
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  gradient: AppTheme.blueGradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.music_note_rounded, size: 15, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text(
                'Villupaatukaaran',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.queue_music_rounded, color: Colors.white),
                onPressed: _toggleQueue,
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _buildMainViewport(),
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
