import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../downloader/widgets/download_modal_sheet.dart';
import '../../../player/screens/watch_screen.dart';
import '../../models/youtube_video.dart';

class VideoCard extends ConsumerStatefulWidget {
  final YouTubeVideo video;
  final bool isHorizontal;

  const VideoCard({
    super.key,
    required this.video,
    this.isHorizontal = false,
  });

  @override
  ConsumerState<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends ConsumerState<VideoCard> {
  bool _isHovered = false;

  void _navigateToWatch(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WatchScreen(video: widget.video),
      ),
    );
  }

  void _openDownloadSheet(BuildContext context) {
    DownloadModalSheet.show(
      context,
      url: widget.video.watchUrl,
      title: widget.video.title,
      thumbnail: widget.video.thumbnailUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = ref.watch(localeProvider);
    final isArabic = locale.languageCode == 'ar';
    final l10n = AppLocalizations.of(context);

    if (widget.isHorizontal) {
      return _buildHorizontalCard(context, isDark, isArabic, l10n);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isHovered
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: _isHovered ? 1.5 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? AppColors.primary.withValues(alpha: 0.16)
                    : (isDark ? Colors.black26 : const Color(0x06000000)),
                blurRadius: _isHovered ? 16 : 8,
                offset: Offset(0, _isHovered ? 6 : 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _navigateToWatch(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Thumbnail with Duration & Quick Download badge
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: widget.video.thumbnailUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.video.thumbnailUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                  child: const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.primary)),
                                  ),
                                ),
                                errorWidget: (_, _, _) => Container(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                  child: const Center(
                                    child: Icon(LucideIcons.video, size: 32, color: Colors.grey),
                                  ),
                                ),
                              )
                            : Container(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                child: const Center(
                                  child: Icon(LucideIcons.video, size: 32, color: Colors.grey),
                                ),
                              ),
                      ),
                      // Duration badge
                      if (widget.video.duration.isNotEmpty)
                        Positioned(
                          bottom: 8,
                          right: isArabic ? null : 8,
                          left: isArabic ? 8 : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.82),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.video.duration,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      // Quick Download Button Overlay
                      Positioned(
                        top: 8,
                        right: isArabic ? null : 8,
                        left: isArabic ? 8 : null,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _openDownloadSheet(context),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                LucideIcons.download,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Info details
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                gradient: AppColors.cyberGradient,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  widget.video.channelTitle.isNotEmpty
                                      ? widget.video.channelTitle.characters.first.toUpperCase()
                                      : 'Y',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.video.channelTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (widget.video.viewCount > 0) ...[
                              Text(
                                '${Formatters.formatViews(widget.video.viewCount, isArabic: isArabic)} ${l10n.translate('views')}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '•',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            if (widget.video.publishedAt != null)
                              Expanded(
                                child: Text(
                                  Formatters.formatRelativeTime(widget.video.publishedAt, isArabic: isArabic),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalCard(BuildContext context, bool isDark, bool isArabic, AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToWatch(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              SizedBox(
                width: 130,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: widget.video.thumbnailUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.video.thumbnailUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey.shade300,
                                  child: const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (_, _, _) => Container(
                                  color: Colors.grey.shade300,
                                  child: const Icon(LucideIcons.video, size: 24, color: Colors.grey),
                                ),
                              )
                            : Container(color: Colors.grey.shade300),
                      ),
                      if (widget.video.duration.isNotEmpty)
                        Positioned(
                          bottom: 4,
                          right: isArabic ? null : 4,
                          left: isArabic ? 4 : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.video.duration,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.25),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.video.channelTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (widget.video.viewCount > 0)
                        Text(
                          '${Formatters.formatViews(widget.video.viewCount, isArabic: isArabic)} ${l10n.translate('views')}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.download, size: 16),
                onPressed: () => _openDownloadSheet(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
