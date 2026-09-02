import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../downloader/models/download_task.dart';
import '../../downloader/providers/download_providers.dart';
import '../../downloader/services/download_queue_service.dart';
import '../../downloader/widgets/download_modal_sheet.dart';
import '../../downloader/widgets/download_progress_bar.dart';
import '../providers/downloads_library_provider.dart';
import '../widgets/download_item_tile.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  String _selectedFilter = 'all'; // 'all', 'video', 'audio'
  final TextEditingController _searchFilterController = TextEditingController();

  @override
  void dispose() {
    _searchFilterController.dispose();
    super.dispose();
  }

  void _openQuickDownload() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Download from URL'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Paste YouTube, X, TikTok, Vimeo link...',
            prefixIcon: Icon(LucideIcons.link, size: 18),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = controller.text.trim();
              Navigator.of(ctx).pop();
              if (url.isNotEmpty) {
                DownloadModalSheet.show(context, url: url);
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = ResponsiveLayout.isDesktop(context);

    final queueTasksAsync = ref.watch(downloadQueueProvider);
    final libraryItems = ref.watch(downloadsLibraryProvider);

    final activeTasks = queueTasksAsync.maybeWhen(
      data: (tasks) => tasks.where((t) => t.status != DownloadStatus.completed).toList(),
      orElse: () => <DownloadTask>[],
    );

    final filteredItems = libraryItems.where((item) {
      if (_selectedFilter == 'video' && item.isAudioOnly) return false;
      if (_selectedFilter == 'audio' && !item.isAudioOnly) return false;
      if (_searchFilterController.text.isNotEmpty) {
        return item.title.toLowerCase().contains(_searchFilterController.text.toLowerCase());
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.translate('downloads_title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ElevatedButton.icon(
              onPressed: _openQuickDownload,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: Text(l10n.translate('quick_download')),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Active Tasks Section
          if (activeTasks.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 16,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.loader, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          '${l10n.translate('active_downloads')} (${activeTasks.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => DownloadQueueService().clearCompleted(),
                      child: const Text('Clear finished'),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DownloadTaskTile(task: activeTasks[index]),
                  ),
                  childCount: activeTasks.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: Divider(height: 32)),
          ],

          // Filter Chips & Search inside library
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildFilterButton('all', l10n.translate('all'), isDark),
                          const SizedBox(width: 8),
                          _buildFilterButton('video', l10n.translate('videos'), isDark),
                          const SizedBox(width: 8),
                          _buildFilterButton('audio', l10n.translate('audios'), isDark),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Search within library
                  SizedBox(
                    width: isDesktop ? 220 : 130,
                    height: 40,
                    child: TextField(
                      controller: _searchFilterController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Filter...',
                        prefixIcon: const Icon(LucideIcons.filter, size: 14),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Downloaded Library List
          if (filteredItems.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(LucideIcons.downloadCloud, size: 44, color: Colors.white),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.translate('no_downloads_yet'),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.translate('no_downloads_sub'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _openQuickDownload,
                        icon: const Icon(LucideIcons.link, size: 18),
                        label: const Text('Download New Media'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 16,
                vertical: 12,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DownloadItemTile(item: filteredItems[index]),
                  ),
                  childCount: filteredItems.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String key, String label, bool isDark) {
    final isSelected = _selectedFilter == key;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selectedFilter = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.primaryGradient : null,
            color: isSelected
                ? null
                : (isDark ? AppColors.darkSurface : AppColors.lightSurfaceHover),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
