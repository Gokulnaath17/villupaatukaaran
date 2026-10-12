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
      padding: const EdgeInsets.all(16),
      children: [
        // Section: Storage Folders
        _buildSectionHeader('STORAGE & BASE DIRECTORIES', Icons.folder_open),
        const SizedBox(height: 10),

        // Base Audio Directory
        Obx(() => _buildFolderTile(
              title: 'Base Audio / Music Folder',
              subtitle: controller.audioDir.value,
              onBrowse: controller.pickAudioDirectory,
            )),
        const SizedBox(height: 8),

        // Base Video Directory
        Obx(() => _buildFolderTile(
              title: 'Base Videos Folder',
              subtitle: controller.videoDir.value,
              onBrowse: controller.pickVideoDirectory,
            )),
        const SizedBox(height: 8),

        // Cache Directory
        Obx(() => _buildFolderTile(
              title: 'Local Cache Directory',
              subtitle: controller.cacheDir.value,
              onBrowse: controller.pickCacheDirectory,
            )),
        const SizedBox(height: 24),

        // Section: Cache Management
        _buildSectionHeader('STREAMING CACHE & PERFORMANCE', Icons.speed),
        const SizedBox(height: 10),

        // Auto-cache Switch
        Obx(() => BoxyCard(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppTheme.yellowAccent,
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
        const SizedBox(height: 8),

        // Cache Limit Slider
        Obx(() => BoxyCard(
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
                          color: AppTheme.yellowAccent,
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
        const SizedBox(height: 24),

        // Section: Streaming Pipeline
        _buildSectionHeader('STREAMING PIPELINE & AUDIO QUALITY', Icons.graphic_eq),
        const SizedBox(height: 10),

        BoxyCard(
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
                      icon: const Icon(Icons.arrow_drop_down, color: AppTheme.yellowAccent),
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
              const Divider(color: AppTheme.border),
              // Stream sources
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Resolver Engine',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Primary: Innertube (WEB_REMIX) • Fallback: YtExplode (yt-dlp)',
                  style: TextStyle(color: AppTheme.yellowLight, fontSize: 12),
                ),
                trailing: Icon(Icons.check_circle, color: AppTheme.yellowAccent, size: 20),
              ),
              const Divider(color: AppTheme.border),
              // Loudness normalization
              Obx(() => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppTheme.yellowAccent,
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
        const SizedBox(height: 24),

        // Section: Brand & About
        _buildSectionHeader('ABOUT VILLUPAATUKARAN', Icons.info_outline),
        const SizedBox(height: 10),

        BoxyCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.yellowAccent),
                ),
                child: Image.asset(AppAssets.appIcon, fit: BoxFit.cover),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Villupaatukaran',
                      style: TextStyle(
                        color: AppTheme.yellowAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Paattil Ooru Ulagam • v1.12.2',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Minimalist high-speed client with zero ads and offline audio caching.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.yellowAccent),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 12,
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
                const SizedBox(height: 3),
                Text(
                  subtitle.isEmpty ? 'Not configured (using app default)' : subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          BoxyButton(
            label: 'BROWSE',
            onPressed: onBrowse,
          ),
        ],
      ),
    );
  }
}

