import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/constant.dart';
import '../../services/settings_controller.dart';
import '../../services/update_service.dart';
import '../../utils/app_assets.dart';
import '../theme/theme_controller.dart';
import '../widgets/boxy_card.dart';
import '../widgets/update_banner.dart';

/// Settings page for folder selection, cache limits, and playback options
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsController>();

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width < 600 ? 16 : 24,
        vertical: 16,
      ),
      children: [
        // Live Update Banner (active whenever an update is discovered, downloading, or verifying)
        const UpdateBanner(),

        // Section: Storage Folders
        _buildSectionHeader('BASE STORAGE DIRECTORY', Icons.folder_special_rounded),
        const SizedBox(height: 12),

        // Unified Base Directory Card
        BoxyCard(
          borderRadius: AppTheme.radiusMedium,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 460;

              return Obx(() {
                final base = controller.baseDir.value;
                final dl = controller.downloadsDir.value;
                final cache = controller.cacheDir.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isNarrow) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Unified Music & Storage Vault',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            base.isEmpty
                                ? (Constant.isDesktop
                                    ? 'Default: ~/Music/Villupaatukaaran'
                                    : 'Default: App Internal Storage')
                                : base,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.redLight,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                          if (Constant.isDesktop) ...[
                            const SizedBox(height: 10),
                            BoxyButton(
                              label: 'CHANGE FOLDER',
                              icon: Icons.folder_open_rounded,
                              onPressed: controller.pickBaseDirectory,
                            ),
                          ],
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Unified Music & Storage Vault',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  base.isEmpty
                                      ? (Constant.isDesktop
                                          ? 'Default: ~/Music/Villupaatukaaran'
                                          : 'Default: App Internal Storage')
                                      : base,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.redLight,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (Constant.isDesktop) ...[
                            const SizedBox(width: 12),
                            BoxyButton(
                              label: 'CHANGE FOLDER',
                              icon: Icons.folder_open_rounded,
                              onPressed: controller.pickBaseDirectory,
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Divider(color: AppTheme.borderSubtle),
                    const SizedBox(height: 8),
                    // Subfolder layout explanation
                    if (isNarrow) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• Downloads Subfolder',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            dl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '• Cache Subfolder',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            cache,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '• Database & Config Subfolder',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            controller.dataDir.value.isNotEmpty ? controller.dataDir.value : '$base/data',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '• Downloads Subfolder',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  dl,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '• Cache Subfolder',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  cache,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '• Database Subfolder',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  controller.dataDir.value.isNotEmpty ? controller.dataDir.value : '$base/data',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              });
            },
          ),
        ),
        const SizedBox(height: 28),

        // Section: Cache Management
        _buildSectionHeader('STREAMING CACHE & PERFORMANCE', Icons.speed_rounded),
        const SizedBox(height: 12),

        // Auto-cache Switch
        Obx(() => BoxyCard(
              borderRadius: AppTheme.radiusMedium,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppTheme.redAccent,
                title: const Text(
                  'Auto-Cache All Played Songs',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Saves streamed tracks locally for zero-buffering replay',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                value: controller.autoCacheEnabled.value,
                onChanged: controller.toggleAutoCache,
              ),
            )),
        const SizedBox(height: 10),

        // Cache Limit Slider
        Obx(() => BoxyCard(
              borderRadius: AppTheme.radiusMedium,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Cache Capacity Limit',
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${controller.cacheSizeLimit.value} Songs (Default: 350)',
                        style: const TextStyle(
                          color: AppTheme.redLight,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: controller.cacheSizeLimit.value.toDouble(),
                    min: 50,
                    max: 1000,
                    divisions: 19,
                    activeColor: AppTheme.redAccent,
                    onChanged: (val) => controller.setCacheSizeLimit(val.toInt()),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Current usage: ${controller.cachedSongsCount.value} tracks • ${controller.cachedTotalSize.value}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      BoxyButton(
                        label: 'CLEAR CACHE',
                        onPressed: controller.clearCache,
                      ),
                    ],
                  ),
                ],
              ),
            )),
        const SizedBox(height: 28),

        // Section: Streaming Pipeline
        _buildSectionHeader('STREAMING PIPELINE & AUDIO QUALITY', Icons.graphic_eq_rounded),
        const SizedBox(height: 12),

        BoxyCard(
          borderRadius: AppTheme.radiusMedium,
          child: Column(
            children: [
              // Quality selector
              Obx(() => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Audio Stream Quality',
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      controller.streamingQuality.value == Constant.qualityHigh
                          ? 'High Quality (Opus 160kbps / M4A)'
                          : 'Low Quality (Opus 50kbps - Data Saver)',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                    trailing: DropdownButton<int>(
                      value: controller.streamingQuality.value,
                      dropdownColor: AppTheme.cardSurfaceElevated,
                      underline: const SizedBox.shrink(),
                      icon: const Icon(Icons.arrow_drop_down, color: AppTheme.redAccent),
                      items: const [
                        DropdownMenuItem(
                          value: Constant.qualityHigh,
                          child: Text('High Quality', style: TextStyle(color: AppTheme.textPrimary)),
                        ),
                        DropdownMenuItem(
                          value: Constant.qualityLow,
                          child: Text('Low Quality', style: TextStyle(color: AppTheme.textPrimary)),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) controller.setStreamingQuality(v);
                      },
                    ),
                  )),
              const Divider(color: AppTheme.borderSubtle),
              // Stream sources
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Resolver Engine',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Primary: Innertube (WEB_REMIX) • Fallback: YtExplode (yt-dlp)',
                  style: TextStyle(color: AppTheme.redLight, fontSize: 12),
                ),
                trailing: Icon(Icons.check_circle_rounded, color: AppTheme.trafficGreen, size: 20),
              ),
              const Divider(color: AppTheme.borderSubtle),
              // Loudness normalization
              Obx(() => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppTheme.redAccent,
                    title: const Text(
                      'Loudness Normalization',
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Balances volume differences between various song tracks',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                    value: controller.loudnessNormalization.value,
                    onChanged: controller.toggleLoudness,
                  )),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Section: Window & System Tray (Desktop)
        if (Constant.isDesktop) ...[
          _buildSectionHeader('WINDOW & SYSTEM TRAY', Icons.desktop_windows_rounded),
          const SizedBox(height: 12),
          BoxyCard(
            borderRadius: AppTheme.radiusMedium,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.redAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close_fullscreen_rounded, color: AppTheme.redLight, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'On Window Close Action',
                            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Configure behavior when clicking the window close button',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: AppTheme.borderSubtle),
                const SizedBox(height: 8),
                Obx(() => Column(
                      children: [
                        _buildCloseActionOption(
                          controller: controller,
                          value: Constant.closeActionAsk,
                          title: 'Ask every time',
                          subtitle: 'Show confirmation prompt with "Do not ask again" option',
                          icon: Icons.help_outline_rounded,
                        ),
                        const SizedBox(height: 6),
                        _buildCloseActionOption(
                          controller: controller,
                          value: Constant.closeActionBackground,
                          title: 'Play in background (Minimize to tray)',
                          subtitle: 'Keep audio playing and minimize into system tray',
                          icon: Icons.headphones_rounded,
                        ),
                        const SizedBox(height: 6),
                        _buildCloseActionOption(
                          controller: controller,
                          value: Constant.closeActionExit,
                          title: 'Exit application',
                          subtitle: 'Stop music playback and quit Villupaatukaaran completely',
                          icon: Icons.power_settings_new_rounded,
                        ),
                      ],
                    )),
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],

        // Section: Brand & About
        _buildSectionHeader('ABOUT VILLUPAATUKAARAN', Icons.info_outline_rounded),
        const SizedBox(height: 12),

        BoxyCard(
          borderRadius: AppTheme.radiusMedium,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: const Color(0xFF252838),
                      child: Image.asset(AppAssets.appIcon, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Villupaatukaaran',
                          style: TextStyle(
                            color: AppTheme.textWhite,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          'v1.0.0 • Modern Glass Desktop Edition',
                          style: TextStyle(color: AppTheme.redLight, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'A dedicated Tamil folk, classical, and regional music client inspired by the ancient art of Villupaatu (the musical bow). Built with Flutter, MediaKit/libmpv, and GetX.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Section: Backup & Restore
        _buildSectionHeader('BACKUP & RESTORE', Icons.settings_backup_restore_rounded),
        const SizedBox(height: 12),

        BoxyCard(
          borderRadius: AppTheme.radiusMedium,
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 540;

              final textBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Library & Vault Backup',
                    style: TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Export all your liked tracks, playlists, downloads, and cache list into a portable single file, or restore from a previous backup file. On restore, downloaded and cached songs will be automatically downloaded and cached into your storage vault.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.35),
                  ),
                ],
              );

              final actionButtons = Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  BoxyButton(
                    label: 'EXPORT BACKUP',
                    icon: Icons.file_upload_outlined,
                    isPrimary: true,
                    onPressed: () => controller.exportBackup(),
                  ),
                  BoxyButton(
                    label: 'IMPORT BACKUP',
                    icon: Icons.file_download_outlined,
                    onPressed: () => controller.importBackup(context),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    textBlock,
                    const SizedBox(height: 14),
                    actionButtons,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: textBlock),
                  const SizedBox(width: 16),
                  actionButtons,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 28),

        // Section: Software Updates
        _buildSectionHeader('SOFTWARE UPDATES', Icons.system_update_rounded),
        const SizedBox(height: 12),

        BoxyCard(
          borderRadius: AppTheme.radiusMedium,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Version & Check Action Row
              Obx(() {
                final isChecking = controller.updateStatus.value == UpdateStatus.checking;
                final currVer = controller.currentAppVersion.value;
                final statusMsg = controller.updateStatusMessage.value;

                return Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.redAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.redAccent.withOpacity(0.25), width: 1),
                      ),
                      child: const Icon(Icons.update_rounded, color: AppTheme.redAccent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Version $currVer (Linux x64)',
                            style: const TextStyle(
                              color: AppTheme.textWhite,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            statusMsg.isNotEmpty ? statusMsg : 'Ready to check for updates',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    BoxyButton(
                      label: isChecking ? 'CHECKING...' : 'CHECK FOR UPDATES',
                      icon: isChecking ? null : Icons.refresh_rounded,
                      isPrimary: false,
                      onPressed: isChecking ? null : controller.checkForUpdatesManual,
                    ),
                  ],
                );
              }),

              const SizedBox(height: 14),
              const Divider(color: AppTheme.borderSubtle),
              const SizedBox(height: 8),

              // Auto-check Switch
              Obx(() => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppTheme.redAccent,
                    title: const Text(
                      'Auto-Check on Startup',
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    subtitle: const Text(
                      'Silently checks GitHub Releases in the background once every 24 hours',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                    ),
                    value: controller.autoUpdateCheck.value,
                    onChanged: controller.toggleAutoUpdateCheck,
                  )),

              const SizedBox(height: 4),

              // Auto-install Switch
              Obx(() => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppTheme.redAccent,
                    title: const Text(
                      'Auto-Install Updates',
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    subtitle: const Text(
                      'Automatically downloads and applies newer releases when discovered',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                    ),
                    value: controller.autoUpdateInstall.value,
                    onChanged: controller.toggleAutoUpdateInstall,
                  )),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Section: Danger Zone & Factory Reset
        _buildSectionHeader('DANGER ZONE & FACTORY RESET', Icons.warning_amber_rounded),
        const SizedBox(height: 12),

        BoxyCard(
          borderRadius: AppTheme.radiusMedium,
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 480;

              final textBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Reset Entire Application',
                    style: TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Permanently erase all offline downloads, cached songs, custom playlists, likes, playback history, and restore settings to defaults.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.3),
                  ),
                ],
              );

              final actionButton = BoxyButton(
                label: 'RESET ENTIRE APP',
                icon: Icons.delete_forever_rounded,
                isPrimary: true,
                onPressed: () => _showResetConfirmationDialog(context, controller),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    textBlock,
                    const SizedBox(height: 12),
                    actionButton,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: textBlock),
                  const SizedBox(width: 16),
                  actionButton,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  void _showResetConfirmationDialog(BuildContext context, SettingsController controller) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppTheme.windowBg,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.radiusLarge,
            side: const BorderSide(color: AppTheme.trafficRed, width: 1.5),
          ),
          actionsOverflowDirection: VerticalDirection.down,
          title: const Row(
            children: [
              Icon(Icons.warning_rounded, color: AppTheme.trafficRed, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'RESET VILLUPAATUKAARAN?',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'This action is irreversible. All offline songs, downloaded tracks, cache vault, playlists, liked songs, history, and preferences will be permanently wiped.\n\nAre you sure you want to proceed?',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.trafficRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusSmall),
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await controller.resetEntireApp();
              },
              icon: const Icon(Icons.delete_forever_rounded, size: 16),
              label: const Text('YES, RESET EVERYTHING', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCloseActionOption({
    required SettingsController controller,
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = controller.closeAction.value == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => controller.setCloseAction(value),
        borderRadius: AppTheme.radiusMedium,
        hoverColor: Colors.white.withOpacity(0.04),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.redAccent.withOpacity(0.10) : Colors.white.withOpacity(0.02),
            borderRadius: AppTheme.radiusMedium,
            border: Border.all(
              color: isSelected ? AppTheme.redAccent.withOpacity(0.4) : AppTheme.borderSubtle,
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppTheme.redAccent : AppTheme.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isSelected ? AppTheme.textWhite : AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Radio<String>(
                value: value,
                groupValue: controller.closeAction.value,
                activeColor: AppTheme.redAccent,
                onChanged: (val) {
                  if (val != null) controller.setCloseAction(val);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.redAccent),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textHeading,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}
