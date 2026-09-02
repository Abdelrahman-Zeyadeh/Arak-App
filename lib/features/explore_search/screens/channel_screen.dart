import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive_layout.dart';
import '../models/youtube_channel.dart';
import '../models/youtube_video.dart';
import '../services/youtube_api_service.dart';
import 'widgets/video_card.dart';
import 'widgets/video_skeleton.dart';

class ChannelScreen extends ConsumerStatefulWidget {
  final YouTubeChannel channel;

  const ChannelScreen({super.key, required this.channel});

  @override
  ConsumerState<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends ConsumerState<ChannelScreen> {
  late Future<List<YouTubeVideo>> _channelVideosFuture;

  @override
  void initState() {
    super.initState();
    _channelVideosFuture = YouTubeApiService().fetchChannelVideos(widget.channel.id);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.channel.title),
      ),
      body: CustomScrollView(
        slivers: [
          // Channel Header Banner & Profile
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: widget.channel.avatarUrl.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              widget.channel.avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Center(
                                child: Text(
                                  widget.channel.title.isNotEmpty
                                      ? widget.channel.title.characters.first.toUpperCase()
                                      : 'C',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              widget.channel.title.isNotEmpty
                                  ? widget.channel.title.characters.first.toUpperCase()
                                  : 'C',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.channel.title,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(LucideIcons.badgeCheck, color: AppColors.primary, size: 18),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (widget.channel.subscriberCount > 0)
                          Text(
                            '${widget.channel.subscriberCount} ${l10n.translate('subscribers')}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          )
                        else if (widget.channel.videoCount > 0)
                          Text(
                            '${widget.channel.videoCount} فيديو',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        if (widget.channel.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.channel.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Channel Videos Header
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 16,
                vertical: 16,
              ),
              child: const Text(
                'أحدث الفيديوهات المرفوعة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Channel Uploads Grid
          FutureBuilder<List<YouTubeVideo>>(
            future: _channelVideosFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: ResponsiveLayout.getGridColumnCount(context),
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: ResponsiveLayout.getCardAspectRatio(context),
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => const VideoCardSkeleton(),
                      childCount: 6,
                    ),
                  ),
                );
              }

              final videos = snapshot.data ?? [];
              if (videos.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text('لا توجد فيديوهات متاحة لهذه القناة حالياً'),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: ResponsiveLayout.getGridColumnCount(context),
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    childAspectRatio: ResponsiveLayout.getCardAspectRatio(context),
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => VideoCard(video: videos[index]),
                    childCount: videos.length,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}
