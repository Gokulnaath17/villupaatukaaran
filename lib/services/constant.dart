import 'dart:io';

/// Application constants
class Constant {
  Constant._();

  // App info
  static const String appName = 'Harmony Music';
  static const String packageName = 'com.harmonymusic.villupaatukaaran';

  // Platform detection
  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
  static bool get isWindows => Platform.isWindows;
  static bool get isLinux => Platform.isLinux;
  static bool get isMacOS => Platform.isMacOS;
  static bool get isDesktop => isWindows || isLinux || isMacOS;
  static bool get isMobile => isAndroid || isIOS;

  // Innertube API
  static const String innertubeBaseUrl = 'https://music.youtube.com/youtubei/v1/';
  static const String innertubeApiKey = 'AIzaSyC9XL3j2qh4qh4qh4qh4qh4qh4qh4qh4qh4'; // Placeholder
  static const String innertubeClientName = 'WEB_REMIX';
  static const String innertubeClientVersion = '1.20241201.01.00'; // Date-based version
  static const String innertubeUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36';
  static const String mobileAudioUserAgent =
      'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';
  static String get audioUserAgent =>
      isMobile ? mobileAudioUserAgent : innertubeUserAgent;
  static const String innertubeOrigin = 'https://music.youtube.com';
  static const String innertubeCookie = 'CONSENT=YES+1';

  // Hive box names
  static const String boxSongsCache = 'SongsCache';
  static const String boxSongDownloads = 'SongDownloads';
  static const String boxSongsUrlCache = 'SongsUrlCache';
  static const String boxAppPrefs = 'AppPrefs';
  static const String boxLibraryPlaylists = 'LibraryPlaylists';
  static const String boxLibraryAlbums = 'LibraryAlbums';
  static const String boxLibraryArtists = 'LibraryArtists';
  static const String boxLibFav = 'LIBFAV';
  static const String boxLibRP = 'LIBRP'; // Recently Played (cap 30)
  static const String boxSearchQuery = 'searchQuery';
  static const String boxHomeScreenData = 'homeScreenData';
  static const String boxPrevSessionData = 'prevSessionData';
  static const String boxBlacklistedPlaylist = 'blacklistedPlaylist';
  static const String boxLyrics = 'lyrics';

  // AppPrefs keys
  static const String prefThemeModeType = 'themeModeType';
  static const String prefCacheSongs = 'cacheSongs';
  static const String prefSkipSilenceEnabled = 'skipSilenceEnabled';
  static const String prefStreamingQuality = 'streamingQuality';
  static const String prefThemePrimaryColor = 'themePrimaryColor';
  static const String prefDiscoverContentType = 'discoverContentType';
  static const String prefNewVersionVisibility = 'newVersionVisibility';
  static const String prefCacheHomeScreenData = 'cacheHomeScreenData';
  static const String prefRestorePlaybackSession = 'restorePlaybackSession';
  static const String prefKeepScreenAwake = 'keepScreenAwake';
  static const String prefLoudnessNormalization = 'loudnessNormalization';
  static const String prefCurrentAppLanguageCode = 'currentAppLanguageCode';
  static const String prefDownloadFormat = 'downloadFormat';
  static const String prefDownloadQuality = 'downloadQuality';
  static const String prefPipedInstance = 'pipedInstance';
  static const String prefPipedToken = 'pipedToken';
  static const String prefBackgroundPlayback = 'backgroundPlayback';
  static const String prefShowLyrics = 'showLyrics';
  static const String prefBaseStorageDir = 'baseStorageDir';
  static const String prefCloseAction = 'closeAction';
  static const String prefInitialSetupDone = 'initialSetupDone';

  // Auto-update preferences
  static const String prefAutoUpdateCheck   = 'autoUpdateCheck';
  static const String prefAutoUpdateInstall = 'autoUpdateInstall';
  static const String prefLastUpdateCheck   = 'lastUpdateCheck';
  static const String prefSkippedVersion    = 'skippedUpdateVersion';

  // GitHub release source
  static const String githubOwner      = 'gokulnaath17';
  static const String githubRepo       = 'villupaatukaaran';
  static const String updateAssetName  = 'villupaatukaaran-linux-x64.tar.gz';

  // Window close action types
  static const String closeActionAsk = 'ask';
  static const String closeActionBackground = 'background';
  static const String closeActionExit = 'exit';

  // Streaming quality
  static const int qualityLow = 0;
  static const int qualityHigh = 1;

  // Theme mode
  static const int themeModeSystem = 0;
  static const int themeModeLight = 1;
  static const int themeModeDark = 2;
  static const int themeModeDynamic = 3;

  // Discover content type
  static const String discoverQuickPicks = 'QP';
  static const String discoverMoods = 'MOODS';
  static const String discoverCharts = 'CHARTS';

  // Playlist/Album/Artist types
  static const String playlingFromAlbum = 'ALBUM';
  static const String playlingFromPlaylist = 'PLAYLIST';
  static const String playlingFromSelection = 'SELECTION';
  static const String playlingFromArtist = 'ARTIST';

  // Download formats
  static const String downloadFormatOpus = 'opus';
  static const String downloadFormatM4A = 'm4a';

  // Cache
  static const int urlCacheExpiryMinutes = 30;
  static const int homeScreenCacheHours = 8;

  // Limits
  static const int libRPCap = 30;
  static const int searchQueryCap = 10;
  static const int maxPlaylistSongs = 5000;

  // Directories
  static const String baseDirName = 'Villupaatukaaran';
  static const String dataDirName = 'data';
  static const String tempCacheDirName = 'cache';
  static const String downloadDirName = 'downloads';

  // Notification
  static const String notificationChannelId = 'com.harmonymusic.audio';
  static const String notificationChannelName = 'Harmony Music Notification';

  // Intents/Actions
  static const String actionPlayByIndex = 'playByIndex';
  static const String actionSetSourceNPlay = 'setSourceNPlay';
  static const String actionPlayPlaylist = 'playPlaylist';
  static const String actionStartRadio = 'startRadio';
  static const String actionEnqueue = 'enqueue';
  static const String actionPlayNext = 'playNext';
  static const String actionRemoveFromQueue = 'removeFromQueue';
  static const String actionClearQueue = 'clearQueue';
  static const String actionShuffleQueue = 'shuffleQueue';
  static const String actionReorderQueue = 'reorderQueue';

  // Custom actions
  static const String customActionPlayByIndex = 'playByIndex';
  static const String customActionSetSourceNPlay = 'setSourceNPlay';
  static const String customActionGetLyrics = 'getLyrics';
  static const String customActionShowLyrics = 'showLyrics';
  static const String customActionSleepTimer = 'sleepTimer';
  static const String customActionToggleSkipSilence = 'toggleSkipSilence';
  static const String customActionToggleLoudnessNormalization = 'toggleLoudnessNormalization';
  static const String customActionOpenEqualizer = 'openEqualizer';
  static const String customActionSaveSession = 'saveSession';

  // Error codes
  static const String error404 = '404';
  static const String errorNetwork = 'network_error';
  static const String errorPlayback = 'playback_error';

  // Regex patterns
  static final RegExp playlistIdRegex = RegExp(r'^(VL|PL|RD|OLAK5uy_)');
  static final RegExp videoIdRegex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
  static final RegExp urlExpireRegex = RegExp(r'expire=(\d+)');

  // Default values
  static const int defaultVolume = 100;
  static const double defaultPlaybackSpeed = 1.0;
  static const int sleepTimerCheckIntervalMs = 1000;
}