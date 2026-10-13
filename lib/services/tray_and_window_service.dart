import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'constant.dart';
import 'player_controller.dart';
import 'settings_controller.dart';
import '../ui/theme/theme_controller.dart';
import '../ui/widgets/boxy_card.dart';
import '../utils/app_assets.dart';

/// Service managing the desktop system tray icon, Apple Music-like context menu,
/// and window close behaviors (play in background vs exit app).
class TrayAndWindowService extends GetxService with TrayListener, WindowListener {
  bool _isWindowVisible = true;
  bool _isInitialized = false;

  Future<TrayAndWindowService> init() async {
    if (!Constant.isDesktop) return this;

    try {
      // 1. Initialize Window Manager
      await windowManager.ensureInitialized();
      windowManager.addListener(this);
      await windowManager.setPreventClose(true);

      const windowOptions = WindowOptions(
        size: Size(1280, 800),
        minimumSize: Size(960, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        title: 'Villupaatukaaran',
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
        _isWindowVisible = true;
      });

      // 2. Initialize Tray Manager
      trayManager.addListener(this);
      await trayManager.setIcon(AppAssets.trayIcon);
      await trayManager.setToolTip('Villupaatukaaran');

      _isInitialized = true;

      // 3. Listen to player observables to keep tray menu dynamically synchronized
      if (Get.isRegistered<PlayerController>()) {
        final player = Get.find<PlayerController>();
        player.currentSong.listen((_) => updateTrayMenu());
        player.isPlaying.listen((_) => updateTrayMenu());
        player.likedSongIds.listen((_) => updateTrayMenu());
      }

      await updateTrayMenu();
    } catch (e) {
      debugPrint('[TrayAndWindowService] Init error: $e');
    }

    return this;
  }

  @override
  void onClose() {
    if (Constant.isDesktop) {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
    }
    super.onClose();
  }

  /// Update the system tray context menu dynamically like Apple Music
  Future<void> updateTrayMenu() async {
    if (!_isInitialized || !Constant.isDesktop) return;

    try {
      final player = Get.isRegistered<PlayerController>() ? Get.find<PlayerController>() : null;
      final song = player?.currentSong.value;
      final isPlaying = player?.isPlaying.value ?? false;
      final isLiked = (song != null && player != null) ? player.isLiked(song.videoId) : false;

      // Update tooltip
      final tooltip = song != null ? '${song.title} — ${song.artist}' : 'Villupaatukaaran';
      await trayManager.setToolTip(tooltip);

      final menuItems = <MenuItem>[
        // Now Playing Header (Apple Music style)
        if (song != null) ...[
          MenuItem(
            label: '🎵  ${song.title}',
            disabled: true,
          ),
          MenuItem(
            label: '     ${song.artist}',
            disabled: true,
          ),
          MenuItem.separator(),
        ] else ...[
          MenuItem(
            label: '🎵  Villupaatukaaran',
            disabled: true,
          ),
          MenuItem.separator(),
        ],

        // Playback Controls
        MenuItem(
          label: isPlaying ? '⏸   Pause' : '▶   Play',
          onClick: (_) async {
            if (player != null) await player.togglePlayPause();
            await updateTrayMenu();
          },
        ),
        MenuItem(
          label: '⏭   Next Track',
          onClick: (_) async {
            if (player != null) await player.skipToNext();
          },
        ),
        MenuItem(
          label: '⏮   Previous Track',
          onClick: (_) async {
            if (player != null) await player.skipToPrevious();
          },
        ),
        if (song != null)
          MenuItem(
            label: isLiked ? '♥   Liked' : '♡   Like',
            onClick: (_) async {
              if (player != null) await player.toggleLike(song);
              await updateTrayMenu();
            },
          ),

        MenuItem.separator(),

        // Window Controls
        MenuItem(
          label: _isWindowVisible ? 'Hide Window' : 'Open Villupaatukaaran',
          onClick: (_) async {
            await toggleWindow();
          },
        ),

        MenuItem.separator(),

        // Quit Entire App
        MenuItem(
          label: 'Quit Villupaatukaaran',
          onClick: (_) async {
            await quitApp();
          },
        ),
      ];

      await trayManager.setContextMenu(Menu(items: menuItems));
    } catch (e) {
      debugPrint('[TrayAndWindowService] Update menu error: $e');
    }
  }

  /// Toggle window visibility
  Future<void> toggleWindow() async {
    if (!Constant.isDesktop) return;

    final isVis = await windowManager.isVisible();
    if (isVis) {
      await windowManager.hide();
      _isWindowVisible = false;
    } else {
      await windowManager.show();
      await windowManager.focus();
      _isWindowVisible = true;
    }
    await updateTrayMenu();
  }

  /// Show and bring window to front
  Future<void> showWindow() async {
    if (!Constant.isDesktop) return;
    await windowManager.show();
    await windowManager.focus();
    _isWindowVisible = true;
    await updateTrayMenu();
  }

  /// Hide window into system tray
  Future<void> hideWindow() async {
    if (!Constant.isDesktop) return;
    await windowManager.hide();
    _isWindowVisible = false;
    await updateTrayMenu();
  }

  /// Quit application entirely
  Future<void> quitApp() async {
    try {
      if (Get.isRegistered<PlayerController>()) {
        Get.find<PlayerController>().saveSession();
        await Get.find<PlayerController>().stop();
      }
      await trayManager.destroy();
      await windowManager.destroy();
    } catch (_) {
      exit(0);
    }
  }

  // --- TrayListener Callbacks ---

  @override
  void onTrayIconMouseDown() {
    showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  // --- WindowListener Callbacks ---

  @override
  void onWindowClose() async {
    if (!Constant.isDesktop) return;

    final settings = Get.isRegistered<SettingsController>() ? Get.find<SettingsController>() : null;
    final action = settings?.closeAction.value ?? Constant.closeActionAsk;

    if (action == Constant.closeActionBackground) {
      await hideWindow();
      _notifyTrayBackground();
      return;
    } else if (action == Constant.closeActionExit) {
      await quitApp();
      return;
    }

    // Otherwise 'ask'
    await showWindow();
    _showCloseConfirmationDialog();
  }

  @override
  void onWindowFocus() {
    _isWindowVisible = true;
    updateTrayMenu();
  }

  void _notifyTrayBackground() {
    if (Get.context != null) {
      try {
        Get.snackbar(
          'Playing in Background',
          'Villupaatukaaran is still running in your system tray',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xE61C1C1E),
          colorText: AppTheme.textPrimary,
          duration: const Duration(seconds: 3),
        );
      } catch (_) {}
    }
  }

  void _showCloseConfirmationDialog() {
    final context = Get.context;
    if (context == null) {
      hideWindow();
      return;
    }

    final dontAskAgain = false.obs;

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xF21C1C1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 40,
                      height: 40,
                      color: const Color(0xFF252838),
                      child: Image.asset(AppAssets.appIcon, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Close Villupaatukaaran',
                          style: TextStyle(
                            color: AppTheme.textWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Background Playback vs Exit',
                          style: TextStyle(color: AppTheme.blueLight, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Would you like Villupaatukaaran to continue playing audio seamlessly in the background in your system tray, or exit the application completely?',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 18),
              Obx(() => InkWell(
                    onTap: () => dontAskAgain.value = !dontAskAgain.value,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: dontAskAgain.value,
                              activeColor: AppTheme.blueAccent,
                              onChanged: (val) => dontAskAgain.value = val ?? false,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Do not ask again (can be changed in Settings)',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  BoxyButton(
                    label: 'EXIT APP',
                    icon: Icons.power_settings_new_rounded,
                    onPressed: () async {
                      if (dontAskAgain.value && Get.isRegistered<SettingsController>()) {
                        Get.find<SettingsController>().setCloseAction(Constant.closeActionExit);
                      }
                      Get.back();
                      await quitApp();
                    },
                  ),
                  const SizedBox(width: 8),
                  BoxyButton(
                    label: 'PLAY IN BACKGROUND',
                    icon: Icons.headphones_rounded,
                    isPrimary: true,
                    onPressed: () async {
                      if (dontAskAgain.value && Get.isRegistered<SettingsController>()) {
                        Get.find<SettingsController>().setCloseAction(Constant.closeActionBackground);
                      }
                      Get.back();
                      await hideWindow();
                      _notifyTrayBackground();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }
}
