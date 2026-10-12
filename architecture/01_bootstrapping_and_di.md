# 01 — Bootstrapping, Hive Init, GetX DI, Lifecycle

Source files: `lib/main.dart`, `lib/utils/system_tray.dart`, `lib/utils/update_check_flag_file.dart`, `lib/utils/app_link_controller.dart`.

## 1.1 `main()` exact sequence (`lib/main.dart:1-143`)

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHive();            // blocks UI
  _setAppInitPrefs();          // sync seed
  startApplicationServices();  // sync, NOT awaited (lazy only)
  Get.put<AudioHandler>(await initAudioService(), permanent:true); // awaited
  WidgetsBinding.instance.addObserver(LifecycleHandler());
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  TerminateRestart.instance.initialize();
  runApp(const MyApp());
}
```

## 1.2 `initHive()`

- Desktop (`GetPlatform.isDesktop`): `getApplicationSupportDirectory()/db`; else `getApplicationDocumentsDirectory()`.
- `Hive.initFlutter(path)` then `openBox ×4`: `SongsCache`, `SongDownloads`, `SongsUrlCache`, `AppPrefs`.
- Boxes are untyped `Box<dynamic>` holding `Map<String,dynamic>` JSON. No `registerAdapter`.

## 1.3 `_setAppInitPrefs()`

Only if `Hive.box("AppPrefs").isEmpty`, `putAll`:
`themeModeType:0, cacheSongs:false, skipSilenceEnabled:false, streamingQuality:1(High), themePrimaryColor:4278199603, discoverContentType:"QP"(QuickPicks), newVersionVisibility:updateCheckFlag(false), cacheHomeScreenData:true`.
`updateCheckFlag` const in `lib/utils/update_check_flag_file.dart` = `false` (F-Droid flavor disables GitHub check; CI overwrites to `true` for GitHub EXE build).

## 1.4 `startApplicationServices()` — all lazy

```dart
Get.lazyPut(()=>PipedServices(), fenix:true);
Get.lazyPut(()=>MusicServices(), fenix:true);
Get.lazyPut(()=>ThemeController(), fenix:true);
Get.lazyPut(()=>PlayerController(), fenix:true);
Get.lazyPut(()=>HomeScreenController(), fenix:true);
Get.lazyPut(()=>LibrarySongsController(), fenix:true);
Get.lazyPut(()=>LibraryPlaylistsController(), fenix:true);
Get.lazyPut(()=>LibraryAlbumsController(), fenix:true);
Get.lazyPut(()=>LibraryArtistsController(), fenix:true);
Get.lazyPut(()=>SettingsScreenController(), fenix:true);
Get.lazyPut(()=>Downloader(), fenix:true);
if (GetPlatform.isDesktop) { Get.lazyPut(()=>SearchScreenController(), fenix:true); Get.put(DesktopSystemTray()); }
```

`fenix:true` = recreate after delete. Nothing instantiated here.

## 1.5 `initAudioService()` (`lib/services/audio_handler.dart:1-~30`)

```dart
AudioService.init(builder:()=>MyAudioHandler(), config:AudioServiceConfig(
  androidNotificationIcon:'mipmap/ic_launcher_monochrome',
  androidNotificationChannelId:'com.mycompany.myapp.audio',
  androidNotificationChannelName:'Harmony Music Notification',
  androidNotificationOngoing:true, androidStopForegroundOnPause:true))
```

Stored `permanent:true` so never disposed. Constructor side-effects (see `03_*`): MPV title/whitelist desktop, `AudioPlayer(AndroidLoadControl 50s/120s/50ms/2s)`, `cachedSongs/` temp dir, empty `ConcatenatingAudioSource`, 4 stream listeners, pref restores.

## 1.6 `MyApp extends StatelessWidget`

- `if (!GetPlatform.isDesktop) Get.put(AppLinksController())` inside `build` (mobile only).
- `SystemChrome edgeToEdge` again.
- `GetMaterialApp(title:'Harmony Music', home:Home(), debugShowCheckedModeBanner:false, translations:Languages(), locale:Locale(AppPrefs.currentAppLanguageCode??"en"), fallbackLocale:en, builder:...)`.
- `builder`: clamp `textScaler` to `[1.0,1.1]`, wrap in `Stack[GetX<ThemeController>(MediaQuery+AnimatedTheme 700ms), GestureDetector(bottom padding)]`.

## 1.7 `LifecycleHandler extends WidgetsBindingObserver`

- `resumed` → re-apply `edgeToEdge`.
- `detached` → `await Get.find<AudioHandler>().customAction("saveSession")`.

## 1.8 Lazy instantiation cascade (first `Get.find` triggers ctor)

| Controller | Trigger | `onInit` work |
|---|---|---|
| `ThemeController` | `MyApp builder GetX` | read `appPrefs` color/mode, brightness listener |
| `SettingsScreenController` | first settings/home access | `_setInitValue` (~25 prefs), `mkdir support/Music`, version check |
| `MusicServices` | first content fetch | `init()`: clientVersion date, signatureTimestamp, hlCode, visitorId |
| `PlayerController` | `Home` mini-player/tray | listeners + prefs + Win service + `prevSessionData` restore |
| `HomeScreenController` | `HomeScreen` | Db else network feed, stale>8h silent refresh, version dialog |
| `Library*` | library tabs/Auto | `refreshLib` + Piped sync + `house_keeping` |
| `Downloader` | first download | idle (`isJobRunning=false`) |
| `DesktopSystemTray` | desktop `Get.put` eager | 2s delayed `initSystemTray` |
| `AppLinksController` | mobile `MyApp.build` | `getInitialAppLink` + `uriLinkStream` |

## 1.9 DI rules for clone

- Singleton audio handler `permanent:true`; everything else `lazyPut fenix:true`.
- Per-route: `Get.put(Playlist/Album/Artist/SearchResultController, tag:Key(id).hashCode)` + `Get.delete` on close; dialog controllers deleted on dismiss. Guard `Get.isRegistered` before `find` for optional screens.
- Cross-controller access exclusively via `Get.find` (no constructor injection).
