import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audio_service/audio_service.dart';

import 'services/audio_handler.dart';
import 'services/cache_service.dart';
import 'services/constant.dart';
import 'services/discover_controller.dart';
import 'services/library_service.dart';
import 'services/music_service.dart';
import 'services/player_controller.dart';
import 'services/settings_controller.dart';
import 'services/stream_service.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/theme_controller.dart';
import 'utils/linux_audio_init.dart';

/// Application Entry Point
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop audio engine init
  LinuxAudioInit.ensureInitialized();

  // Initialize Hive storage boxes
  await initHive();

  // Register core network & storage services
  final musicService = await MusicService().init();
  Get.put<MusicService>(musicService, permanent: true);

  final streamService = await StreamService().init();
  Get.put<StreamService>(streamService, permanent: true);

  final cacheService = await CacheService().init();
  Get.put<CacheService>(cacheService, permanent: true);

  final libraryService = await LibraryService().init();
  Get.put<LibraryService>(libraryService, permanent: true);

  // Initialize AudioService & MyAudioHandler
  final audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.harmonymusic.audio',
      androidNotificationChannelName: 'Villupaatukaran Audio',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );
  Get.put<MyAudioHandler>(audioHandler, permanent: true);

  // Initialize UI & State controllers
  Get.put<SettingsController>(SettingsController(), permanent: true);
  Get.put<PlayerController>(PlayerController(), permanent: true);
  Get.put<DiscoverController>(DiscoverController(), permanent: true);

  // Lifecycle observer for session saving
  WidgetsBinding.instance.addObserver(AppLifecycleHandler());

  // System UI overlay
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const VillupaatukaranApp());
}

/// Initialize Hive storage boxes
Future<void> initHive() async {
  await Hive.initFlutter();

  // Eager startup boxes
  await Hive.openBox(Constant.boxSongsCache);
  await Hive.openBox(Constant.boxSongDownloads);
  await Hive.openBox(Constant.boxSongsUrlCache);
  await Hive.openBox(Constant.boxAppPrefs);
  await Hive.openBox(Constant.boxLibraryPlaylists);
  await Hive.openBox(Constant.boxLibFav);
  await Hive.openBox(Constant.boxLibRP);
  await Hive.openBox(Constant.boxHomeScreenData);
  await Hive.openBox(Constant.boxPrevSessionData);
}

/// Lifecycle handler for session persistence
class AppLifecycleHandler extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached || state == AppLifecycleState.paused) {
      if (Get.isRegistered<PlayerController>()) {
        Get.find<PlayerController>().saveSession();
      }
    }
  }
}

/// Root Application Widget
class VillupaatukaranApp extends StatelessWidget {
  const VillupaatukaranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Villupaatukaran',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
      navigatorKey: Get.key,
      navigatorObservers: [GetObserver()],
    );
  }
}