import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../models/local_download_item.dart';
import '../services/downloads_library_service.dart';

class LocalMediaPlayerScreen extends StatelessWidget {
  final LocalDownloadItem item;

  const LocalMediaPlayerScreen({super.key, required this.item});

  Future<void> _openWithSystemApp() async {
    try {
      final file = File(item.filePath);
      if (await file.exists()) {
        if (Platform.isWindows) {
          await Process.run('cmd', ['/c', 'start', '""', item.filePath]);
        } else if (Platform.isMacOS) {
          await Process.run('open', [item.filePath]);
        } else if (Platform.isLinux) {
          await Process.run('xdg-open', [item.filePath]);
        } else {
          await launchUrl(Uri.file(item.filePath));
        }
      }
    } catch (e) {
      debugPrint('[LocalMediaPlayerScreen] Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.folderOpen, size: 18),
            tooltip: l10n.translate('open_folder'),
            onPressed: () => DownloadsLibraryService().openFileLocation(item.filePath),
          ),
          IconButton(
            icon: const Icon(LucideIcons.externalLink, size: 18),
            tooltip: 'Open in system player',
            onPressed: _openWithSystemApp,
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Media Artwork / Preview Card
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: (item.isAudioOnly ? AppColors.accentRose : AppColors.primary).withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: item.thumbnailUrl.isNotEmpty
                    ? Image.network(
                        item.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                item.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Info Badges
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (item.isAudioOnly ? AppColors.accentRose : AppColors.primary).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${item.formatExt.toUpperCase()} • ${item.resolution}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: item.isAudioOnly ? AppColors.accentRose : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (item.fileSizeBytes > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        Formatters.formatBytes(item.fileSizeBytes),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // File Location Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.file, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.filePath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _openWithSystemApp,
                    icon: const Icon(LucideIcons.play, size: 18),
                    label: const Text('Play with System Player', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => DownloadsLibraryService().openFileLocation(item.filePath),
                    icon: const Icon(LucideIcons.folderOpen, size: 18),
                    label: Text(l10n.translate('open_folder')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: (item.isAudioOnly ? AppColors.accentRose : AppColors.primary).withValues(alpha: 0.15),
      child: Center(
        child: Icon(
          item.isAudioOnly ? LucideIcons.music : LucideIcons.video,
          size: 64,
          color: item.isAudioOnly ? AppColors.accentRose : AppColors.primary,
        ),
      ),
    );
  }
}
