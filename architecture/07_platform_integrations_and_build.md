# 07 — Platform Integrations, Native, Dependencies, Build/Distribution

## 7.1 Android (`android/`)

- Manifest (`app/src/main/AndroidManifest.xml`): label Harmony Music, `usesCleartextTraffic=true, requestLegacyExternalStorage=true`, multidex `FlutterMultiDexApplication.java`; `MainActivity(exported, singleInstance, adjustResize, Impeller, embeddingV2)`; app-links filters `autoVerify` + plain `VIEW+BROWSABLE+DEFAULT` for `music.youtube.com,m.youtube.com,www.youtube.com,youtu.be,youtube.com` + `SEND text/plain`; `AudioService(foregroundServiceType=mediaPlayback,exported)+MediaBrowserService` + `MediaButtonReceiver(MEDIA_BUTTON)`; perms `WRITE/READ_EXTERNAL_STORAGE, MANAGE_EXTERNAL_STORAGE, WAKE_LOCK, FOREGROUND_SERVICE(+_MEDIA_PLAYBACK), INTERNET, REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`; `automotive_app_desc.xml(<uses media/>)` for Auto; debug/profile manifests add INTERNET.
- Kotlin: `MainActivity.kt: AudioServiceActivity` (required); `Equalizer.kt(@Keep)`: `openEqualizer(sessionId,ctx,act)` (`ACTION_DISPLAY_AUDIO_EFFECT_CONTROL_PANEL` + fallback manufacturer activities) + `init/endAudioEffect` broadcasts; triggered `androidAudioSessionIdStream→init`, `customAction(openEqualizer)`; `SDKInt.kt(@Keep getSDKInt)` → `permission_service` branch <30 vs ≥30.
- Gradle: `app/build.gradle` (flutter plugin, ndk26.1, Java17, `com.anandnet.harmonymusic`, min/target flutter.*, versionCode/Name flutter.*, release→debug signing, multidex, splashscreen); `build.gradle/settings.gradle/gradle.properties(useAndroidX,Jetifier)/wrapper 8.9`.
- Res: `styles.xml(+night/v31)` Launch→Normal theme, `colors.xml`, `launch_background(+v21)/animated_splash_icon`, `mipmap-*/ic_launcher(+background/foreground/monochrome)+anydpi-v26 xml`; notification icon `mipmap/ic_launcher_monochrome` in `AudioServiceConfig`.

## 7.2 iOS (`ios/`)

`Info.plist`: display harmonymusic, storyboards, orientations, `NSAllowsArbitraryLoads=true`, `UIBackgroundModes=[audio]`; `AppDelegate.swift` stock; `Podfile` (`use_frameworks, AUDIO_SESSION_MICROPHONE=0, PERMISSION_MEDIA_LIBRARY=1`); `Podfile.lock` pins audio_service/just_audio/permission_handler; stock xcodeproj/storyboards/icons/tests.

## 7.3 Linux (`linux/`)

`CMakeLists(BINARY harmonymusic, APP_ID com.example.harmonymusic, RPATH $ORIGIN/lib, cxx14 -Wall -Werror -O3, GTK3, bundle ICU/flutter/plugins/assets/AOT)`; `main.cc→my_application`; `my_application.cc` GNOME header-bar detection (X11 wm_name/Wayland XDG), `1280×720`; `packaging/{deb,rpm,appimage}/make_config.yaml` (deb: mpv+libmpv1|2+appindicator, icon `assets/icons/icon.png`, Music cat; rpm: mpv-libs+appindicator, GPLv3; appimage: AudioVideo). Runtime MPV via `JustAudioMediaKit` + MPRIS via `audio_service_mpris` auto plugin (no Dart import).

## 7.4 Windows (`windows/`)

`CMakeLists(BINARY harmonymusic, cxx17 /W4/WX, bundle)`; `runner/main.cpp(wWinMain, CoInitialize, DartProject, 1280×720, SetQuitOnClose)`; `flutter_window/win32_window/utils` stock + custom `win_titlebar_color` MethodChannel (`setTitleBarColor{r,g,b}→DwmSetWindowAttribute 35`) called `theme_controller.setWindowsTitleBarColor` (350ms, Windows guard); `Runner.rc(versioninfo FLUTTER_VERSION, icon app_icon.ico)`; `runner.exe.manifest(PerMonitorV2, Win7-11)`; `packaging/exe/make_config.yaml(APP_ID B9F6E402-…, lowest priv, inno template)` + `inno_setup.iss(AppVersion 1.12.2+27, {autopf}\harmonymusic, Output harmonymusic-1.12.2.exe, lzma, x64, desktopicon task, postinstall Run)`.

## 7.5 macOS / Web

macOS: `Info.plist(arbitraryLoads)`, `AppInfo.xcconfig(PRODUCT harmonymusic, BUNDLE com.anandnet.harmonymusic)`, `Debug/Release/Warnings xcconfigs`, `Release.entitlements(sandbox+network.client)`, `DebugProfile(+jit+server)`, `AppDelegate(shouldTerminateAfterLastWindowClosed=false)` for tray, `MainFlutterWindow`, stock pods/xib/icons. Web: `index.html(flutter.js+serviceWorker)`, `manifest.json(PWA harmonymusic, standalone, #0175C2)`, icons — stub, no audio_service web support.

## 7.6 Native bridge (`jnigen.yaml` + `lib/native_bindings/andrid_utils.dart[typo]` + `lib/services/equalizer.dart`)

`jnigen single_file←android kotlin classes [Equalizer,SDKInt]→andrid_utils.dart(518, package:jni)`; facade `EqualizerService.open/init/endAudioEffect(sessionId)` via `Jni.getCurrentActivity/getCachedApplicationContext`; deps `jni ^0.14.0`, `jnigen` dev.

## 7.7 Dependency→feature map (`pubspec.yaml`)

`audio_service→background/notification/Auto/queue MediaItem`; `audio_service_mpris→Linux MPRIS (no import)`; `just_audio→AudioPlayer/Concatenating/LockCaching/LoadControl/skipSilence/sessionId`; `just_audio_media_kit(git)→Win/Lin MPV`; `jni/jnigen→EQ/SDK`; `palette_generator→dynamic theme`; `audiotags→download tags`; `youtube_explode_dart(git)→streams`; `dio/html→Innertube/Piped/lyrics`; `hive/flutter→persistence`; `get→DI/nav/state`; `app_links→links`; `cached_network_image→art`; `google_fonts→Inter`; `ionicons/animations/buttons_tabbar/slidable/toggle_switch/shimmer/audio_video_progress_bar/flutter_lyric/widget_marquee/sidebar_with_animation(git)→UI`; `path/provider/file_picker→backup/download dirs`; `archive→.hmb zip`; `permission_handler→storage/battery`; `share_plus→share`; `url_launcher→externals`; `package_info_plus→version/update`; `wakelock_plus→keep-awake (player_controller + settings)`; `window_manager/tray_manager→desktop window/tray (system_tray.dart only)`; `smtc_windows→Win SMTC (windows_audio_service.dart)`; `terminate_restart(git)→init + post-restore restart`; `flutter_keyboard_visibility→hide mini on keyboard`; `flutter_lints/test` dev; `flutter uses-material-design + assets/icons/`.

## 7.8 Requested integrations — exact call sites

- `window_manager` (`system_tray.dart:25,34-36,76,78,84,91,104,118`): `ensureInitialized,isVisible/hide/show,setPreventClose+CloseWindowListener(hide if backgroundPlay&&playing else saveSession+exit)`.
- `tray_manager` (same): `DesktopSystemTray(TrayListener), addListener, 2s initSystemTray, setIcon(ico Win else png), Menu[Show/Hide,Prev,Play/Pause,Next,Quit→saveSession+exit], setContextMenu, onTrayIconMouseDown/RightMouseDown (Win vs Linux inverted)`.
- `wakelock_plus` (`player_controller:15,78-79,186-209,829` + `settings:20,296-311`): `playing&&keepScreenAwake→enable/disable`; default false mobile/true desktop; `WAKE_LOCK` perm.
- `permission_handler` (`permission_service.dart` + `settings:128,320-322`): SDK branch + `ignoreBatteryOptimizations` gated `stopPlyabackOnSwipeAway→onTaskRemoved`.
- `share_plus` (`songinfo:304`, `album:372`, `playlist:507,522`, `artist:267`): `Share.share`.
- `url_launcher` (`settings_screen:58,670`, `new_version:31`, `songinfo:259,267`, `playlist_export:99`).
- `smtc_windows` (`windows_audio_service.dart:3,7-89` + `player_controller:95,825`): `SMTCWindows(enabled:false), buttonPressStream→play/pause/next/prev+status, buttonState→status, progress→position, currentSong→enable+metadata(title/album/artist/thumb)+endTime, onClose clear/disable/dispose`.

## 7.9 Build/distribution

- `distribute_options.yaml`: `output dist/, releases dev linux deb/rpm (enable-experiment:records)` (flutter_distributor).
- `action.yml`: stub `Flutter Runner docker` (no Dockerfile).
- `fastlane/metadata/android/en-US/{title,short/full_description(22 lines),images/icon+phoneScreenshots 1-4,changelogs/10-27}` latest 27: wakelock toggle + ext downloads + discover fix + CSV/YT-Music export(50-limit); root badges `down_fdroid/down_IzzyOnDroid`.
- `.github/workflows/code_quality.yml`: PR→main, ubuntu, flutter3.24.2+JDK17, `pub get→analyze→build apk→upload`.
- `.github/workflows/win_exe.yml`: dispatch, windows, flutter3.24.2, choco innosetup, `dart localization/generator.dart`, `updateCheckFlag=true`, `flutter_distributor package windows exe`, `osslsigncode2.9 + secrets.KEY_PEM→key.pem + win_cert/*.crt/pem → timestamp.digicert.com → verify → upload signed.exe`.
- `.github/scripts/close_search_issues.sh`, `ISSUE_TEMPLATE/{bug,feature}.md`, `copilot-instructions.md`; `win_cert/cert.pem(self-signed anandnet 2025-35)+DigiCertGlobalRootCA.crt`.
