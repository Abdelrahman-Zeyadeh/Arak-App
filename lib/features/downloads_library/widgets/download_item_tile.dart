import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../models/local_download_item.dart';
import '../providers/downloads_library_provider.dart';
import '../screens/local_media_player_screen.dart';

class DownloadItemTile extends ConsumerWidget {
  final LocalDownloadItem item;

  const DownloadItemTile({super.key, required this.item});

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: item.title);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('rename_file')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(downloadsLibraryProvider.notifier).rename(item.id, controller.text.trim());
              }
              Navigator.of(ctx).pop();
            },
            child: Text(l10n.translate('save')),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('delete_file')),
        content: Text('Are you sure you want to delete "${item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              ref.read(downloadsLibraryProvider.notifier).remove(item.id, deleteFile: true);
              Navigator.of(ctx).pop();
            },
            child: Text(l10n.translate('delete_file')),
          ),
        ],
      ),
    );
  }

  void _playLocalMedia(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocalMediaPlayerScreen(item: item),
      ),
    );
  }

  void _shareFile() {
    final file = File(item.filePath);
    if (file.existsSync()) {
      Share.shareXFiles(
        [XFile(item.filePath)],
        text: item.title,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _playLocalMedia(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail with Play overlay badge
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 78,
                        height: 56,
                        child: item.thumbnailUrl.isNotEmpty
                            ? Image.network(
                                item.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _buildPlaceholderIcon(item.isAudioOnly),
                              )
                            : _buildPlaceholderIcon(item.isAudioOnly),
                      ),
                    ),
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.play, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: item.isAudioOnly ? AppColors.audioGradient : AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.formatExt.toUpperCase()} • ${item.resolution}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (item.fileSizeBytes > 0)
                            Text(
                              Formatters.formatBytes(item.fileSizeBytes),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Quick Action Buttons
                IconButton(
                  icon: const Icon(LucideIcons.share2, size: 18),
                  onPressed: _shareFile,
                  tooltip: l10n.translate('share_btn'),
                ),

                // Context Menu
                PopupMenuButton<String>(
                  icon: const Icon(LucideIcons.moreVertical, size: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (action) {
                    if (action == 'open') {
                      ref.read(downloadsLibraryProvider.notifier).openLocation(item.filePath);
                    } else if (action == 'share') {
                      _shareFile();
                    } else if (action == 'rename') {
                      _showRenameDialog(context, ref);
                    } else if (action == 'delete') {
                      _showDeleteDialog(context, ref);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          const Icon(LucideIcons.folderOpen, size: 16),
                          const SizedBox(width: 10),
                          Text(l10n.translate('open_folder')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          const Icon(LucideIcons.share2, size: 16),
                          const SizedBox(width: 10),
                          Text(l10n.translate('share_btn')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          const Icon(LucideIcons.edit2, size: 16),
                          const SizedBox(width: 10),
                          Text(l10n.translate('rename_file')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(LucideIcons.trash2, size: 16, color: AppColors.error),
                          const SizedBox(width: 10),
                          Text(l10n.translate('delete_file'), style: const TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon(bool isAudio) {
    return Container(
      decoration: BoxDecoration(
        gradient: isAudio ? AppColors.audioGradient : AppColors.primaryGradient,
      ),
      child: Center(
        child: Icon(
          isAudio ? LucideIcons.music : LucideIcons.video,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
