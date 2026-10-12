import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/constant.dart';
import '../../services/settings_controller.dart';
import '../../utils/app_assets.dart';
import '../theme/theme_controller.dart';
import '../widgets/boxy_card.dart';

/// Settings page for folder selection, cache limits, and playback options
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsController>();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Section: Storage Folders
        _buildSectionHeader('STORAGE & BASE DIRECTORIES', Icons.folder_open_rounded),
        const SizedBox(height: 12),

        // Base Audio Directory
        Obx(() => _buildFolderTile(
              title: 'Base Audio / Music Folder',
              subtitle: controller.audioDir.value,
              onBrowse: controller.pickAudioDirectory,
            )),
        const SizedBox(height: 10),

        // Base Video Directory
        Obx(() => _buildFolderTile(
              title: 'Base Videos Folder',
              subtitle: controller.videoDir.value,
              onBrowse: controller.pickVideoDirectory,
            )),
        const SizedBox(height: 10),

        // Cache Directory
        Obx(() => _buildFolderTile(
              title: 'Local Cache Directory',
              subtitle: controller.cacheDir.value,
              onBrowse: controller.pickCacheDirectory,
            )),
        const SizedBox(height: 28),

        // Section: Cache Management
        _buildSectionHeader('STREAMING CACHE & PERFORMANCE', Icons.speed_rounded),
        const SizedBox(height: 12),

        // Auto-cache Switch
        Obx(() => BoxyCard(
              borderRadius: AppTheme.radiusMedium,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppTheme.blueAccent,
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
                          color: AppTheme.blueLight,
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
                    activeColor: AppTheme.blueAccent,
                    onChanged: (val) => controller.setCacheSizeLimit(val.toInt()),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current usage: ${controller.cachedSongsCount.value} tracks • ${controller.cachedTotalSize.value}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
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
                      icon: const Icon(Icons.arrow_drop_down, color: AppTheme.blueAccent),
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
                  style: TextStyle(color: AppTheme.blueLight, fontSize: 12),
                ),
                trailing: Icon(Icons.check_circle_rounded, color: AppTheme.trafficGreen, size: 20),
              ),
              const Divider(color: AppTheme.borderSubtle),
              // Loudness normalization
              Obx(() => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppTheme.blueAccent,
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
                  const Column(
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
                        style: TextStyle(color: AppTheme.blueLight, fontSize: 12),
                      ),
                    ],
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
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.blueAccent),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textHeading,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildFolderTile({
    required String title,
    required String subtitle,
    required VoidCallback onBrowse,
  }) {
    return BoxyCard(
      borderRadius: AppTheme.radiusMedium,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle.isEmpty ? 'Not configured (using defaults)' : subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          BoxyButton(
            label: 'BROWSE',
            icon: Icons.folder_rounded,
            onPressed: onBrowse,
          ),
        ],
      ),
    );
  }
}
