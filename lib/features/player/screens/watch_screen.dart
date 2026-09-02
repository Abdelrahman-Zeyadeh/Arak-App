import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../downloader/widgets/download_modal_sheet.dart';
import '../../explore_search/models/youtube_video.dart';
import '../../explore_search/providers/explore_search_provider.dart';
import '../../explore_search/screens/widgets/video_card.dart';
import '../../recently_played/models/recently_played_item.dart';
import '../../recently_played/providers/recently_played_provider.dart';

class WatchScreen extends ConsumerStatefulWidget {
  final YouTubeVideo video;

  const WatchScreen({super.key, required this.video});

  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen> {
  late YoutubePlayerController _controller;
  bool _isDescriptionExpanded = false;
  bool _hasAddedToRecentlyPlayed = false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.video.id,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
    );

    // Add to recently played
    _addToRecentlyPlayed();
  }

  void _addToRecentlyPlayed() {
    if (_hasAddedToRecentlyPlayed) return;
    _hasAddedToRecentlyPlayed = true;

    final item = RecentlyPlayedItem(
      videoId: widget.video.id,
      title: widget.video.title,
      thumbnailUrl: widget.video.thumbnailUrl,
      channelTitle: widget.video.channelTitle,
      duration: widget.video.duration,
      watchedAt: DateTime.now(),
      totalSeconds: _parseDuration(widget.video.duration),
    );

    ref.read(recentlyPlayedProvider.notifier).addItem(item);
  }

  int _parseDuration(String duration) {
    // Parse "3:45" or "1:02:30" format
    final parts = duration.split(':').reversed.toList();
    int seconds = 0;
    if (parts.isNotEmpty) seconds += int.tryParse(parts[0]) ?? 0;
    if (parts.length > 1) seconds += (int.tryParse(parts[1]) ?? 0) * 60;
    if (parts.length > 2) seconds += (int.tryParse(parts[2]) ?? 0) * 3600;
    return seconds;
  }

  @override
  void dispose() {
    // Save progress before disposing
    _saveProgress();
    _controller.close();
    super.dispose();
  }

  void _saveProgress() async {
    try {
      final currentTime = await _controller.currentTime;
      final totalSeconds = _parseDuration(widget.video.duration);
      final positionSeconds = currentTime.round();
      final progress = totalSeconds > 0 ? positionSeconds / totalSeconds : 0.0;

      ref.read(recentlyPlayedProvider.notifier).updateProgress(
        videoId: widget.video.id,
        progress: progress.clamp(0.0, 1.0),
        positionSeconds: positionSeconds,
        totalSeconds: totalSeconds,
      );
    } catch (e) {
      // Player might already be disposed
    }
  }

  void _openDownloadModal() {
    DownloadModalSheet.show(
      context,
      url: widget.video.watchUrl,
      title: widget.video.title,
      thumbnail: widget.video.thumbnailUrl,
    );
  }

  void _copyLink() {
    final l10n = AppLocalizations.of(context);
    Clipboard.setData(ClipboardData(text: widget.video.watchUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.check, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(l10n.translate('link_copied')),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openExternal() async {
    final uri = Uri.parse(widget.video.watchUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = ref.watch(localeProvider);
    final isArabic = locale.languageCode == 'ar';
    final l10n = AppLocalizations.of(context);
    final relatedAsync = ref.watch(relatedVideosProvider(widget.video.id));
    final isDesktop = ResponsiveLayout.isDesktop(context);

    final playerWidget = YoutubePlayer(
      controller: _controller,
      aspectRatio: 16 / 9,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.video.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.share2, size: 18),
            tooltip: l10n.translate('share_btn'),
            onPressed: _copyLink,
          ),
          IconButton(
            icon: const Icon(LucideIcons.externalLink, size: 18),
            tooltip: 'YouTube',
            onPressed: _openExternal,
          ),
        ],
      ),
      body: isDesktop
          ? _buildDesktopLayout(playerWidget, isDark, isArabic, l10n, relatedAsync)
          : _buildMobileLayout(playerWidget, isDark, isArabic, l10n, relatedAsync),
    );
  }

  Widget _buildDesktopLayout(
    Widget player,
    bool isDark,
    bool isArabic,
    AppLocalizations l10n,
    AsyncValue<List<YouTubeVideo>> relatedAsync,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Player & Details Column (65%)
        Expanded(
          flex: 65,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(color: Colors.black, child: player),
                  ),
                ),
                const SizedBox(height: 20),
                _buildVideoInfoAndActions(isDark, isArabic, l10n),
                const SizedBox(height: 16),
                _buildDescriptionCard(isDark, isArabic, l10n),
              ],
            ),
          ),
        ),

        // Sidebar: Related Videos (35%)
        Expanded(
          flex: 35,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: isArabic ? BorderSide.none : BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                right: isArabic ? BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder) : BorderSide.none,
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.listVideo, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      l10n.translate('related_videos'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRelatedVideosList(relatedAsync, isDark),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    Widget player,
    bool isDark,
    bool isArabic,
    AppLocalizations l10n,
    AsyncValue<List<YouTubeVideo>> relatedAsync,
  ) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // 1. Flush Edge-to-Edge Player
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.black,
            child: player,
          ),
        ),

        // 2. Video Details & Actions Container
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                widget.video.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.35),
              ),
              const SizedBox(height: 8),

              // Views & Date stats
              Row(
                children: [
                  if (widget.video.viewCount > 0) ...[
                    Text(
                      '${Formatters.formatViews(widget.video.viewCount, isArabic: isArabic)} ${l10n.translate('views')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '•',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (widget.video.publishedAt != null)
                    Text(
                      Formatters.formatRelativeTime(widget.video.publishedAt, isArabic: isArabic),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Action Buttons Row (Horizontal Scrollable Pills)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Download Button (Primary)
                    ElevatedButton.icon(
                      onPressed: _openDownloadModal,
                      icon: const Icon(LucideIcons.download, size: 16),
                      label: Text(l10n.translate('download_btn')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Copy Link Button
                    OutlinedButton.icon(
                      onPressed: _copyLink,
                      icon: const Icon(LucideIcons.copy, size: 15),
                      label: Text(l10n.translate('copy_link')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Open in YouTube Button
                    OutlinedButton.icon(
                      onPressed: _openExternal,
                      icon: const Icon(LucideIcons.externalLink, size: 15),
                      label: const Text('YouTube'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Channel Header Tile
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          widget.video.channelTitle.isNotEmpty
                              ? widget.video.channelTitle.characters.first.toUpperCase()
                              : 'Y',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.video.channelTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'YouTube Channel',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Description Card
              _buildDescriptionCard(isDark, isArabic, l10n),
              const SizedBox(height: 20),

              // Related Videos Section Header
              Row(
                children: [
                  const Icon(LucideIcons.listVideo, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    l10n.translate('related_videos'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Related Videos List
              _buildRelatedVideosList(relatedAsync, isDark),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoInfoAndActions(bool isDark, bool isArabic, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.video.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.3),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.video.channelTitle.isNotEmpty
                      ? widget.video.channelTitle.characters.first.toUpperCase()
                      : 'Y',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.video.channelTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    'YouTube Channel',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _openDownloadModal,
              icon: const Icon(LucideIcons.download, size: 16),
              label: Text(
                l10n.translate('download_btn'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              icon: const Icon(LucideIcons.copy, size: 16),
              tooltip: l10n.translate('copy_link'),
              onPressed: _copyLink,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescriptionCard(bool isDark, bool isArabic, AppLocalizations l10n) {
    if (widget.video.description.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.video.description,
            maxLines: _isDescriptionExpanded ? null : 3,
            overflow: _isDescriptionExpanded ? null : TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
            child: Text(
              _isDescriptionExpanded ? l10n.translate('show_less') : l10n.translate('show_more'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedVideosList(AsyncValue<List<YouTubeVideo>> relatedAsync, bool isDark) {
    return relatedAsync.when(
      data: (videos) {
        if (videos.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('لا توجد مقاطع مقترحة حالياً', style: TextStyle(color: Colors.grey)),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: videos.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            return VideoCard(video: videos[index], isHorizontal: true);
          },
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary)),
        ),
      ),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}
