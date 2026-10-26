import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/update_service.dart';
import '../theme/theme_controller.dart';
import 'boxy_card.dart';

/// Animated update availability banner shown in Settings and optionally
/// anywhere else. Shows download progress, release notes, and action buttons.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<UpdateService>()) return const SizedBox.shrink();
    final svc = Get.find<UpdateService>();

    return Obx(() {
      final status = svc.updateStatus.value;

      // Nothing to show when idle / up-to-date
      if (status == UpdateStatus.idle || status == UpdateStatus.upToDate) {
        return const SizedBox.shrink();
      }

      return AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        child: _buildCard(context, svc),
      );
    });
  }

  Widget _buildCard(BuildContext context, UpdateService svc) {
    final status = svc.updateStatus.value;

    final isChecking    = status == UpdateStatus.checking;
    final isAvailable   = status == UpdateStatus.available;
    final isDownloading = status == UpdateStatus.downloading;
    final isVerifying   = status == UpdateStatus.verifying;
    final isInstalling  = status == UpdateStatus.installing;
    final isFailed      = status == UpdateStatus.failed;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isFailed
            ? AppTheme.trafficRed.withOpacity(0.08)
            : AppTheme.cardSurfaceElevated,
        borderRadius: AppTheme.radiusMedium,
        border: Border.all(
          color: isFailed
              ? AppTheme.trafficRed.withOpacity(0.35)
              : isAvailable
                  ? AppTheme.redAccent.withOpacity(0.4)
                  : AppTheme.borderSubtle,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ─────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isFailed
                      ? AppTheme.trafficRed.withOpacity(0.15)
                      : AppTheme.redAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  isFailed
                      ? Icons.error_outline_rounded
                      : isChecking
                          ? Icons.search_rounded
                          : Icons.system_update_alt_rounded,
                  color: isFailed ? AppTheme.trafficRed : AppTheme.redAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title(status, svc),
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      svc.statusMessage.value,
                      style: TextStyle(
                        color: isFailed ? AppTheme.trafficRed : AppTheme.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Spinner for checking
              if (isChecking)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.redAccent,
                  ),
                ),
            ],
          ),

          // ── Download progress bar ─────────────────────────────────────────
          if (isDownloading || isVerifying || isInstalling) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: isDownloading ? svc.downloadProgress.value : null,
                      minHeight: 4,
                      backgroundColor: AppTheme.borderSubtle.withOpacity(0.4),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.redAccent),
                    ),
                  ),
                ),
                if (isDownloading) ...[
                  const SizedBox(width: 10),
                  Text(
                    svc.formattedDownloadProgress,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            if (isDownloading && svc.pendingSizeMb.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Downloading ${svc.pendingSizeMb}…',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ),
            if (isVerifying)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Verifying SHA-256 checksum…',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ),
            if (isInstalling)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Replacing bundle files — do not close the window…',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ),
          ],

          // ── Release notes snippet ─────────────────────────────────────────
          if (isAvailable && svc.releaseNotes.value.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: AppTheme.borderSubtle, height: 1),
            const SizedBox(height: 10),
            Text(
              "What's new in ${svc.latestVersion.value}:",
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _truncateNotes(svc.releaseNotes.value),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ],

          // ── Action buttons ────────────────────────────────────────────────
          if (isAvailable) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                BoxyButton(
                  label: 'UPDATE NOW',
                  icon: Icons.download_rounded,
                  isPrimary: true,
                  onPressed: () => _confirmAndUpdate(context, svc),
                ),
                const SizedBox(width: 10),
                BoxyButton(
                  label: 'SKIP VERSION',
                  icon: Icons.skip_next_rounded,
                  onPressed: svc.skipVersion,
                ),
              ],
            ),
          ],

          if (isDownloading) ...[
            const SizedBox(height: 12),
            BoxyButton(
              label: 'CANCEL',
              icon: Icons.close_rounded,
              onPressed: svc.cancelDownload,
            ),
          ],

          if (isFailed) ...[
            const SizedBox(height: 12),
            BoxyButton(
              label: 'RETRY',
              icon: Icons.refresh_rounded,
              onPressed: () => svc.checkForUpdate(),
            ),
          ],
        ],
      ),
    );
  }

  String _title(UpdateStatus status, UpdateService svc) {
    switch (status) {
      case UpdateStatus.checking:
        return 'Checking for updates…';
      case UpdateStatus.available:
        return 'Update available — v${svc.latestVersion.value}';
      case UpdateStatus.downloading:
        return 'Downloading update…';
      case UpdateStatus.verifying:
        return 'Verifying download…';
      case UpdateStatus.installing:
        return 'Installing update…';
      case UpdateStatus.failed:
        return 'Update failed';
      default:
        return 'Update';
    }
  }

  String _truncateNotes(String notes) {
    // Show first 250 chars of release notes
    if (notes.length <= 250) return notes;
    return '${notes.substring(0, 250)}…';
  }

  void _confirmAndUpdate(BuildContext context, UpdateService svc) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.windowBg,
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.radiusLarge,
          side: const BorderSide(color: AppTheme.borderHighlight, width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.system_update_alt_rounded, color: AppTheme.redAccent, size: 22),
            SizedBox(width: 10),
            Text(
              'INSTALL UPDATE?',
              style: TextStyle(
                color: AppTheme.textWhite,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Villupaatukaaran v${svc.latestVersion.value} will be downloaded '
              'and installed. The app will restart automatically when the update '
              'is complete.',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
            if (svc.pendingSizeMb.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.folder_zip_outlined, size: 15, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'Download size: ${svc.pendingSizeMb}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Audio playback will stop when the app restarts.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5, height: 1.3),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL', style: TextStyle(color: AppTheme.textMuted)),
          ),
          BoxyButton(
            label: 'DOWNLOAD & INSTALL',
            icon: Icons.download_rounded,
            isPrimary: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              svc.applyUpdate();
            },
          ),
        ],
      ),
    );
  }
}

