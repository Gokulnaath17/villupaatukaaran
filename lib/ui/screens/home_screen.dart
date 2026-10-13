import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/song_item.dart';
import '../../services/cache_service.dart';
import '../../services/discover_controller.dart';
import '../../services/download_service.dart';
import '../../services/library_service.dart';
import '../../services/player_controller.dart';
import '../../services/settings_controller.dart';
import '../theme/theme_controller.dart';
import '../widgets/download_queue_drawer.dart';
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
  bool _isDownloadsOpen = false;

  // Active Spotlight Category / Artist
  String _selectedArtistKey = 'trending';
  final TextEditingController _searchController = TextEditingController();

  final Map<String, Map<String, String>> _artistsMetadata = {
    'trending': {
      'name': 'Trending Tamil Hits',
      'badge': "TODAY'S TOP HITS",
      'subtitle': 'The hottest Tamil chartbusters, viral sound waves & cinematic masterpieces',
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
          // Scrollable Navigation Hierarchy
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

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
          const SizedBox(height: 10),

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
                                Expanded(
                                  child: Text(
                                    '$cachedCount/$maxLimit Tracks • Ready',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppTheme.trafficGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppTheme.windowBg,
        border: Border(bottom: BorderSide(color: AppTheme.borderSubtle, width: 1)),
      ),
      child: Row(
        children: [
          // Breadcrumb text (flexibly truncated)
          Flexible(
            child: Text(
              breadcrumb,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Download Status Pill / Drawer Toggle (Aligned to Left)
          Builder(builder: (_) {
            final downloadService = Get.isRegistered<DownloadService>() ? Get.find<DownloadService>() : null;
            if (downloadService == null) return const SizedBox.shrink();

            return Obx(() {
              final activeCount = downloadService.activeDownloadsCount.value;
              final isDownloading = activeCount > 0;

              if (isDownloading) {
                return InkWell(
                  onTap: _toggleDownloads,
                  borderRadius: AppTheme.radiusSmall,
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.blueAccent.withOpacity(0.15),
                      borderRadius: AppTheme.radiusSmall,
                      border: Border.all(color: AppTheme.blueAccent.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.blueAccent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$activeCount DOWNLOADING',
                          style: const TextStyle(
                            color: AppTheme.blueAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return IconButton(
                icon: Icon(
                  Icons.download_done_rounded,
                  color: _isDownloadsOpen ? AppTheme.blueAccent : AppTheme.textSecondary,
                  size: 20,
                ),
                splashRadius: 18,
                tooltip: 'Download Queue',
                onPressed: _toggleDownloads,
              );
            });
          }),
          const SizedBox(width: 4),

          // Up Next Queue button (Aligned to Left)
          IconButton(
            icon: Icon(
              Icons.queue_music_rounded,
              color: _isQueueOpen ? AppTheme.blueAccent : AppTheme.textSecondary,
              size: 20,
            ),
            splashRadius: 18,
            tooltip: 'Up Next Queue',
            onPressed: _toggleQueue,
          ),

          const Spacer(),

          // Search Field
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240, minWidth: 100),
            child: SizedBox(
              width: 200,
              height: 34,
              child: Container(
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
            ),
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

      final artist = _artistsMetadata[_selectedArtistKey] ?? _artistsMetadata['trending']!;
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

          // ================= LOWER SPLIT (RESPONSIVE) =================
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 880;

              final popularColumn = Column(
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
              );

              final curatedColumn = Column(
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
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    popularColumn,
                    const SizedBox(height: 28),
                    curatedColumn,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 12, child: popularColumn),
                  const SizedBox(width: 28),
                  Expanded(flex: 11, child: curatedColumn),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      );
    });
  }

  /// Hero Spotlight Banner with Cutout Silhouette, Badges, and Action Buttons
  /// Hero Spotlight Banner with Modern Music Graphic, Badges, and Action Buttons
  Widget _buildHeroBanner(Map<String, String> artist) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bannerWidth = constraints.maxWidth;
        final isCompact = bannerWidth < 760;

        return SizedBox(
          height: isCompact ? 230 : 210,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Back button (if currently viewing a specific artist)
              if (_selectedArtistKey != 'trending')
                Positioned(
                  top: 0,
                  left: 0,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _switchArtist('trending'),
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

              // Glowing Vinyl / Modern Music Art Graphic
              Positioned(
                left: isCompact ? 10 : 30,
                bottom: -6,
                child: SizedBox(
                  width: isCompact ? 130 : 170,
                  height: isCompact ? 150 : 190,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ambient glow
                      Container(
                        width: isCompact ? 110 : 140,
                        height: isCompact ? 110 : 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.redAccent.withOpacity(0.28),
                              AppTheme.blueAccent.withOpacity(0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      // Modern 3D Vinyl Disc
                      Container(
                        width: isCompact ? 110 : 140,
                        height: isCompact ? 110 : 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2C2D35), Color(0xFF15161E)],
                          ),
                          border: Border.all(color: Colors.white.withOpacity(0.15), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.6),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: isCompact ? 44 : 54,
                            height: isCompact ? 44 : 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.blueGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.blueAccent.withOpacity(0.5),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Artist Details and Controls (Title, Subtitle, Shuffle & Play buttons)
              Positioned(
                left: isCompact ? 155 : 220,
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
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                artist['name'] ?? '',
                                style: TextStyle(
                                  color: AppTheme.textWhite,
                                  fontSize: isCompact ? 22 : 30,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Quick Spotlight Pills (Wrap-based for zero overflow)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'Spotlight: ',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
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
                    const SizedBox(width: 12),

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
                        const SizedBox(width: 10),
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
      },
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

  /// 5-Album Carousel Row with high-res music thumbnails
  Widget _buildAlbumCarouselRow() {
    return Row(
      children: [
        Expanded(
          child: _buildAlbumCard(
            title: 'Leo',
            artistOrYear: 'Anirudh • 2023',
            imageUrl: 'https://i.ytimg.com/vi/szvt1vD0Uug/hqdefault.jpg',
            query: 'Leo Tamil Songs',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildAlbumCard(
            title: 'Jailer',
            artistOrYear: 'Anirudh • 2023',
            imageUrl: 'https://i.ytimg.com/vi/Y5BeWdODPqo/hqdefault.jpg',
            query: 'Jailer Tamil Songs',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildAlbumCard(
            title: 'Ponniyin Selvan',
            artistOrYear: 'A.R. Rahman • 2022',
            imageUrl: 'https://i.ytimg.com/vi/Q_O03B_3U2s/hqdefault.jpg',
            query: 'Ponniyin Selvan Songs',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildAlbumCard(
            title: 'Vikram',
            artistOrYear: 'Anirudh • 2022',
            imageUrl: 'https://i.ytimg.com/vi/1F3hm6MfR1k/hqdefault.jpg',
            query: 'Vikram Tamil Songs',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildAlbumCard(
            title: 'Thalapathi',
            artistOrYear: 'Ilaiyaraaja • 1991',
            imageUrl: 'https://i.ytimg.com/vi/g31iL_y045g/hqdefault.jpg',
            query: 'Thalapathi Tamil Songs',
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumCard({
    required String title,
    required String artistOrYear,
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
        hoverColor: Colors.white.withOpacity(0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: AppTheme.radiusLarge,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: AppTheme.radiusLarge,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: const Color(0xFF222533)),
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF1C1E2A),
                          child: const Center(
                            child: Icon(Icons.album_rounded, size: 36, color: AppTheme.blueAccent),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.35),
                            ],
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
              artistOrYear,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                title: 'Acoustic & Classical',
                subtitle: 'இன்னிசை ராகங்கள்',
                imageUrl:
                    'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&auto=format&fit=crop&q=80',
                query: 'Tamil Classical Acoustic Songs',
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
                  right: 12,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                icon: const Icon(Icons.downloading_rounded, color: Colors.white, size: 20),
                onPressed: _toggleDownloads,
                tooltip: 'Download Queue',
              ),
              IconButton(
                icon: const Icon(Icons.queue_music_rounded, color: Colors.white),
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
