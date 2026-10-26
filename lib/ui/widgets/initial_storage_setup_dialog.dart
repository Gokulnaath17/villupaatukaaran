import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/storage_service.dart';
import '../theme/theme_controller.dart';
import 'boxy_card.dart';

/// Modal dialog shown during initial launch asking the user to setup their
/// single storage vault folder (keeping databases, configs, cache, and downloads
/// unified in one folder without touching ~/Documents).
class InitialStorageSetupDialog extends StatefulWidget {
  const InitialStorageSetupDialog({super.key});

  @override
  State<InitialStorageSetupDialog> createState() => _InitialStorageSetupDialogState();
}

class _InitialStorageSetupDialogState extends State<InitialStorageSetupDialog> {
  late String _selectedPath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final storageService = Get.find<StorageService>();
    _selectedPath = storageService.baseDir.value;
  }

  Future<void> _pickFolder() async {
    try {
      final picked = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Villupaatukaaran Storage Vault Folder',
      );
      if (picked != null && picked.isNotEmpty) {
        setState(() {
          _selectedPath = picked;
        });
      }
    } catch (e) {
      debugPrint('[InitialStorageSetupDialog] Folder pick error: $e');
    }
  }

  Future<void> _confirmAndContinue() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final storageService = Get.find<StorageService>();
      await storageService.completeInitialSetup(_selectedPath);
      if (mounted) {
        Navigator.of(context).pop();
        Get.snackbar(
          'Vault Configured',
          'Storage vault ready at $_selectedPath',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      Get.snackbar(
        'Setup Error',
        'Could not initialize storage folder: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.trafficRed.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        decoration: BoxDecoration(
          color: AppTheme.windowBg.withOpacity(0.97),
          borderRadius: AppTheme.radiusLarge,
          border: Border.all(color: AppTheme.borderSubtle, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.65),
              blurRadius: 36,
              spreadRadius: 4,
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.redAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.redAccent.withOpacity(0.3), width: 1.2),
                  ),
                  child: const Icon(
                    Icons.folder_special_rounded,
                    color: AppTheme.redAccent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STORAGE VAULT SETUP',
                        style: TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Welcome to Villupaatukaaran • Unified Storage',
                        style: TextStyle(
                          color: AppTheme.redLight,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Description
            const Text(
              'Villupaatukaaran keeps all your playlists, liked tracks, offline downloads, streaming buffer, and application databases consolidated inside a single folder. Your Documents folder remains clean and untouched.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),

            // Selected Folder Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardSurface,
                borderRadius: AppTheme.radiusMedium,
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.folder_rounded, size: 16, color: AppTheme.redLight),
                      SizedBox(width: 8),
                      Text(
                        'VAULT STORAGE ROOT',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedPath,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textWhite,
                            fontSize: 12.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      BoxyButton(
                        label: 'CHANGE',
                        icon: Icons.folder_open_rounded,
                        onPressed: _pickFolder,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Subfolder Layout Summary
            const Text(
              'Subfolders automatically created inside:',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSubfolderBadge('data/', 'Databases & Playlists', Icons.storage_rounded, AppTheme.redAccent),
                const SizedBox(width: 8),
                _buildSubfolderBadge('downloads/', 'Offline Audio', Icons.download_rounded, AppTheme.albumCyan),
                const SizedBox(width: 8),
                _buildSubfolderBadge('cache/', 'Stream Buffer', Icons.speed_rounded, AppTheme.albumLavender),
              ],
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                BoxyButton(
                  label: _isSaving ? 'CONFIGURING...' : 'CONFIRM & GET STARTED',
                  icon: Icons.arrow_forward_rounded,
                  isPrimary: true,
                  onPressed: _isSaving ? null : _confirmAndContinue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubfolderBadge(String folder, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardSurfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 5),
                Text(
                  folder,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
