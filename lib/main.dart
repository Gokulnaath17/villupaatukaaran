import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audio_service/audio_service.dart';

import 'services/audio_handler.dart';
import 'services/backup_service.dart';
import 'services/cache_service.dart';
import 'services/constant.dart';
import 'services/discover_controller.dart';
import 'services/download_service.dart';
import 'services/library_service.dart';
import 'services/music_service.dart';
import 'services/player_controller.dart';
import 'services/settings_controller.dart';
import 'services/storage_service.dart';
import 'services/stream_service.dart';
import 'services/tray_and_window_service.dart';
import 'services/update_service.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/theme_controller.dart';
import 'utils/linux_audio_init.dart';

/// Application Entry Point
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop single-instance check: if another instance is running, signal it to show and exit immediately
  if (Constant.isDesktop) {
    final isPrimary = await TrayAndWindowService.ensureSingleInstance();
    if (!isPrimary) {
      exit(0);
    }
  }

  // Desktop audio engine init
  LinuxAudioInit.ensureInitialized();

  // Initialize unified storage engine
  final storageService = await StorageService().init();
  Get.put<StorageService>(storageService, permanent: true);

  // Initialize Hive storage boxes inside single vault folder's data/ subfolder
  await initHive(storageService.dataDir.value);

  // Register backup & restore engine
  Get.put<BackupService>(BackupService(), permanent: true);

  // Register core network & storage services
  final musicService = await MusicService().init();
  Get.put<MusicService>(musicService, permanent: true);

  final cacheService = await CacheService().init();
  Get.put<CacheService>(cacheService, permanent: true);

  final streamService = await StreamService().init();
  Get.put<StreamService>(streamService, permanent: true);

  final downloadService = await DownloadService().init();
  Get.put<DownloadService>(downloadService, permanent: true);

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

  // Initialize System Tray & Window Manager for desktop
  if (Constant.isDesktop) {
    final trayService = await TrayAndWindowService().init();
    Get.put<TrayAndWindowService>(trayService, permanent: true);
  }

  // Initialize UpdateService on Linux
  if (Constant.isLinux) {
    final updateService = await UpdateService().init();
    Get.put<UpdateService>(updateService, permanent: true);
  }

  // Lifecycle observer for session saving
  WidgetsBinding.instance.addObserver(AppLifecycleHandler());

  // System UI overlay
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const VillupaatukaranApp());
}

/// Initialize Hive storage boxes inside single vault folder's data/ subfolder
Future<void> initHive(String dataPath) async {
  Hive.init(dataPath);
  await StorageService.openBoxes();
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