import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../downloads_library/services/downloads_library_service.dart';
import '../models/download_format.dart';
import '../models/video_metadata.dart';
import '../services/download_queue_service.dart';
import '../services/ytdlp_engine.dart';

class DownloadModalSheet extends ConsumerStatefulWidget {
  final String initialUrl;
  final String? preloadedTitle;
  final String? preloadedThumbnail;

  const DownloadModalSheet({
    super.key,
    required this.initialUrl,
    this.preloadedTitle,
    this.preloadedThumbnail,
  });

  static Future<void> show(
    BuildContext context, {
    required String url,
    String? title,
    String? thumbnail,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DownloadModalSheet(
        initialUrl: url,
        preloadedTitle: title,
        preloadedThumbnail: thumbnail,
      ),
    );
  }

  @override
  ConsumerState<DownloadModalSheet> createState() => _DownloadModalSheetState();
}

class _DownloadModalSheetState extends ConsumerState<DownloadModalSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  VideoMetadata? _metadata;
  bool _isLoading = true;
  String? _error;
  DownloadFormat? _selectedFormat;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _titleController = TextEditingController(text: widget.preloadedTitle ?? '');
    _probeVideo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _probeVideo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final meta = await YtDlpEngine().probeVideo(widget.initialUrl);
      if (mounted) {
        setState(() {
          _metadata = meta;
          _isLoading = false;
          if (meta != null) {
            if (_titleController.text.isEmpty && meta.title.isNotEmpty) {
              _titleController.text = meta.title;
            }
            // Auto select best video format
            final videoFormats = meta.formats.where((f) => !f.isAudioOnly).toList();
            if (videoFormats.isNotEmpty) {
              _selectedFormat = videoFormats.first;
            } else if (meta.formats.isNotEmpty) {
              _selectedFormat = meta.formats.first;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _startDownload() async {
    if (_selectedFormat == null) return;
    final l10n = AppLocalizations.of(context);
    final resolution = _selectedFormat!.resolution;

    // Duplicate detection: warn before queueing the exact same video at the
    // exact same quality twice, whether it's already finished or already
    // sitting in the queue.
    final existingTask = DownloadQueueService().findActiveTask(widget.initialUrl, resolution: resolution);
    if (existingTask != null) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.translate('already_queued_title')),
          content: Text(l10n.translate('already_queued_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.translate('cancel')),
            ),
          ],
        ),
      );
      return;
    }

    final existingItem = await DownloadsLibraryService().findByUrl(widget.initialUrl, resolution: resolution);
    if (existingItem != null) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.translate('already_downloaded_title')),
          content: Text(l10n.translate('already_downloaded_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.translate('cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.translate('download_anyway')),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    if (!mounted) return;

    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : (_metadata?.title ?? 'Media Download');

    final thumbnail = widget.preloadedThumbnail ?? _metadata?.thumbnail ?? '';

    DownloadQueueService().enqueueDownload(
      url: widget.initialUrl,
      title: title,
      thumbnailUrl: thumbnail,
      format: _selectedFormat!,
    );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.checkCircle2, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.translate('download_started'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final videoFormats = (_metadata?.formats ?? [])
        .where((f) => !f.isAudioOnly && (f.resolution.isNotEmpty || f.isImage))
        .toList();
    final audioFormats = (_metadata?.formats ?? [])
        .where((f) => f.isAudioOnly || f.abr != null)
        .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
        maxWidth: 650,
      ),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1422) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(LucideIcons.downloadCloud, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('download_modal_title'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        widget.initialUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body
          Flexible(
            child: _isLoading
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          padding: const EdgeInsets.all(8),
                          child: const CircularProgressIndicator(
                            strokeWidth: 3.5,
                            valueColor: AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          l10n.translate('probing_formats'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 40),
                            const SizedBox(height: 14),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _probeVideo,
                              icon: const Icon(LucideIcons.refreshCw, size: 16),
                              label: Text(l10n.translate('retry')),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          // Media Preview Card
                          if (_metadata != null && _metadata!.thumbnail.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkCard : AppColors.lightSurfaceHover,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 100,
                                    height: 75,
                                    child: Image.network(
                                      _metadata!.thumbnail,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        color: isDark ? Colors.black26 : Colors.black12,
                                        child: const Icon(LucideIcons.video, size: 24),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _metadata!.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _metadata!.uploader,
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // File Name Field
                          TextField(
                            controller: _titleController,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              labelText: l10n.translate('description'),
                              prefixIcon: const Icon(LucideIcons.fileText, size: 18),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Tabs for Video / Audio with Animated Glass Pill
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF161E30) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: TabBar(
                              controller: _tabController,
                              indicator: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              indicatorSize: TabBarIndicatorSize.tab,
                              labelColor: Colors.white,
                              unselectedLabelColor:
                                  isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              tabs: [
                                Tab(
                                  icon: const Icon(LucideIcons.video, size: 16),
                                  text: l10n.translate('video_with_audio'),
                                ),
                                Tab(
                                  icon: const Icon(LucideIcons.music, size: 16),
                                  text: l10n.translate('audio_only'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Tab View Formats List
                          SizedBox(
                            height: 230,
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildFormatsList(videoFormats, false),
                                _buildFormatsList(audioFormats, true),
                              ],
                            ),
                          ),
                        ],
                      ),
          ),

          // Footer Download Action Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0C101A) : const Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  gradient: _selectedFormat != null ? AppColors.primaryGradient : null,
                  color: _selectedFormat == null ? (isDark ? Colors.white12 : Colors.black12) : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _selectedFormat != null
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _selectedFormat != null ? _startDownload : null,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.download, size: 20, color: Colors.white),
                          const SizedBox(width: 10),
                          Text(
                            l10n.translate('download_now'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatsList(List<DownloadFormat> formats, bool isAudio) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (formats.isEmpty) {
      return Center(
        child: Text(
          'No formats available for this selection',
          style: TextStyle(
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: formats.length,
      physics: const BouncingScrollPhysics(),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final format = formats[index];
        final isSelected = _selectedFormat == format;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _selectedFormat = format;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.1)
                    : (isDark ? const Color(0xFF131A29) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isSelected ? AppColors.primaryGradient : null,
                      border: Border.all(
                        color: isSelected ? Colors.transparent : Colors.grey,
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? const Center(
                            child: Icon(LucideIcons.check, size: 14, color: Colors.white),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              format.displayLabel,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                              ),
                            ),
                            if (format.fps != null && format.fps! > 30) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accentEmerald.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${format.fps}FPS',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accentEmerald,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (format.note.isNotEmpty && !format.displayLabel.contains(format.note))
                          Text(
                            format.note,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (format.sizeLabel.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E283E) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        format.sizeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

