import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../downloader/widgets/download_modal_sheet.dart';
import '../../explore_search/models/youtube_video.dart';
import '../../recently_played/models/recently_played_item.dart';
import '../../recently_played/providers/recently_played_provider.dart';
import '../../player/screens/watch_screen.dart';
import '../providers/explore_search_provider.dart';
import 'widgets/category_chips.dart';
import 'widgets/video_card.dart';
import 'widgets/video_skeleton.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  final VoidCallback onSearchTabRequested;

  const ExploreScreen({super.key, required this.onSearchTabRequested});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _quickLinkController = TextEditingController();
  String _detectedPlatform = 'none';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _quickLinkController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _quickLinkController.removeListener(_onUrlChanged);
    _quickLinkController.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    final text = _quickLinkController.text.trim().toLowerCase();
    String detected = 'none';
    if (text.contains('instagram.com') || text.contains('instagr.am')) {
      detected = 'instagram';
    } else if (text.contains('tiktok.com')) {
      detected = 'tiktok';
    } else if (text.contains('twitter.com') || text.contains('x.com')) {
      detected = 'twitter';
    } else if (text.contains('facebook.com') || text.contains('fb.watch') || text.contains('fb.com')) {
      detected = 'facebook';
    } else if (text.contains('youtube.com') || text.contains('youtu.be')) {
      detected = 'youtube';
    } else if (text.startsWith('http://') || text.startsWith('https://')) {
      detected = 'generic';
    }
    if (detected != _detectedPlatform) {
      setState(() {
        _detectedPlatform = detected;
      });
    }
  }

  void _handleQuickLinkSubmit(String value) {
    if (value.trim().isEmpty) return;
    final url = value.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) {
      _quickLinkController.clear();
      DownloadModalSheet.show(context, url: url);
    } else {
      ref.read(searchNotifierProvider.notifier).search(url);
      widget.onSearchTabRequested();
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      final text = data.text!.trim();
      _quickLinkController.text = text;
      _handleQuickLinkSubmit(text);
    }
  }

  void _openPlatformPrompt(String platformName, String placeholder) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: _getPlatformGradient(platformName),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.download, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text('$platformName Downloader'),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: placeholder,
            prefixIcon: const Icon(LucideIcons.link, size: 18),
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
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  LinearGradient _getPlatformGradient(String platform) {
    switch (platform.toLowerCase()) {
      case 'instagram':
        return AppColors.instaGradient;
      case 'tiktok':
        return AppColors.tiktokGradient;
      case 'x / twitter':
      case 'twitter':
        return AppColors.xTwitterGradient;
      case 'facebook':
        return AppColors.facebookGradient;
      case 'youtube':
      default:
        return AppColors.ytGradient;
    }
  }

  void _navigateToWatch(YouTubeVideo video) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WatchScreen(video: video)),
    );
  }

  void _navigateToRecentlyPlayed(RecentlyPlayedItem item) {
    final video = YouTubeVideo(
      id: item.videoId,
      title: item.title,
      description: '',
      thumbnailUrl: item.thumbnailUrl,
      channelTitle: item.channelTitle,
      channelId: '',
      viewCount: 0,
      duration: item.duration,
      publishedAt: null,
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WatchScreen(video: video)),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trendingAsync = ref.watch(trendingVideosProvider);
    final recentlyPlayed = ref.watch(recentlyPlayedProvider);
    final continueWatchingAsync = ref.watch(continueWatchingProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(trendingVideosProvider);
          ref.read(recentlyPlayedProvider.notifier).loadRecentlyPlayed();
        },
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // App Header & Hero Smart Downloader Banner
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 16,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top App Greeting Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => AppColors.cyberGradient.createShader(bounds),
                              child: Text(
                                l10n.translate('explore_title'),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.8,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.translate('explore_subtitle'),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                        // Quick Action Icon Button
                        Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _pasteFromClipboard,
                              child: const Padding(
                                padding: EdgeInsets.all(10),
                                child: Icon(LucideIcons.clipboardPaste, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Ultra-Modern Hero Smart Downloader Card
                    _buildHeroDownloaderCard(isDark, l10n),
                    const SizedBox(height: 20),

                    // Platform Launchers (Social Media Hub)
                    _buildPlatformLaunchers(isDark),
                    const SizedBox(height: 20),

                    // Quick Actions
                    _buildQuickActions(isDark, l10n),
                    const SizedBox(height: 20),

                    // Category Chips Bar
                    const CategoryChips(),
                  ],
                ),
              ),
            ),

            // Continue Watching Section
            if (continueWatchingAsync.valueOrNull != null &&
                continueWatchingAsync.value!.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildContinueWatchingSection(
                  continueWatchingAsync.value!,
                  isDark,
                  l10n,
                  isDesktop,
                ),
              ),

            // Recently Played Section
            if (recentlyPlayed.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildRecentlyPlayedSection(
                  recentlyPlayed.take(10).toList(),
                  isDark,
                  l10n,
                  isDesktop,
                ),
              ),

            // Trending Section Header
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.translate('trending'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),

            // Video Grid Section
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 16,
                vertical: 12,
              ),
              sliver: trendingAsync.when(
                data: (videos) {
                  if (videos.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Text(l10n.translate('no_results')),
                        ),
                      ),
                    );
                  }

                  final columnCount = ResponsiveLayout.getGridColumnCount(context);

                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columnCount,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: ResponsiveLayout.getCardAspectRatio(context),
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => VideoCard(video: videos[index]),
                      childCount: videos.length,
                    ),
                  );
                },
                loading: () {
                  final columnCount = ResponsiveLayout.getGridColumnCount(context);
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columnCount,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: ResponsiveLayout.getCardAspectRatio(context),
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => const VideoCardSkeleton(),
                      childCount: 8,
                    ),
                  );
                },
                error: (err, _) => SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text('Error loading videos: $err'),
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 50)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroDownloaderCard(bool isDark, AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF19132C), Color(0xFF111728), Color(0xFF0F1522)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFF3EEFF), Color(0xFFEDF4FF), Color(0xFFF0FDF4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppColors.primary).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.sparkles, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Universal Video Downloader',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (_detectedPlatform != 'none')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: _getPlatformGradient(_detectedPlatform),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _detectedPlatform.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Input Bar inside Hero Card
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0C101A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _detectedPlatform != 'none'
                    ? AppColors.primary
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                width: _detectedPlatform != 'none' ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(
                  _detectedPlatform == 'instagram'
                      ? LucideIcons.camera
                      : (_detectedPlatform == 'tiktok'
                          ? LucideIcons.music
                          : LucideIcons.link),
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _quickLinkController,
                    onSubmitted: _handleQuickLinkSubmit,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: l10n.translate('search_placeholder'),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                    ),
                  ),
                ),
                if (_quickLinkController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 16),
                    onPressed: () => _quickLinkController.clear(),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 6, left: 6),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _handleQuickLinkSubmit(_quickLinkController.text),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Icon(LucideIcons.download, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Fetch',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformLaunchers(bool isDark) {
    final platforms = [
      {'name': 'Instagram', 'icon': LucideIcons.camera, 'gradient': AppColors.instaGradient, 'hint': 'Paste Instagram Reel or Post link...'},
      {'name': 'TikTok', 'icon': LucideIcons.music, 'gradient': AppColors.tiktokGradient, 'hint': 'Paste TikTok video link...'},
      {'name': 'X / Twitter', 'icon': LucideIcons.send, 'gradient': AppColors.xTwitterGradient, 'hint': 'Paste X / Twitter post link...'},
      {'name': 'Facebook', 'icon': LucideIcons.video, 'gradient': AppColors.facebookGradient, 'hint': 'Paste Facebook Video or Watch link...'},
      {'name': 'YouTube', 'icon': LucideIcons.play, 'gradient': AppColors.ytGradient, 'hint': 'Paste YouTube link...'},
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: platforms.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final p = platforms[index];
          final gradient = p['gradient'] as LinearGradient;
          final name = p['name'] as String;
          final hint = p['hint'] as String;
          final icon = p['icon'] as IconData;

          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openPlatformPrompt(name, hint),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: gradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(icon, color: Colors.white, size: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions(bool isDark, AppLocalizations l10n) {
    return Row(
      children: [
        _buildQuickActionButton(
          icon: LucideIcons.clipboardPaste,
          label: l10n.translate('paste_link'),
          color: AppColors.primary,
          isDark: isDark,
          onTap: _pasteFromClipboard,
        ),
        const SizedBox(width: 10),
        _buildQuickActionButton(
          icon: LucideIcons.history,
          label: l10n.translate('recent'),
          color: AppColors.accentBlue,
          isDark: isDark,
          onTap: () {},
        ),
        const SizedBox(width: 10),
        _buildQuickActionButton(
          icon: LucideIcons.download,
          label: l10n.translate('nav_downloads'),
          color: AppColors.accentEmerald,
          isDark: isDark,
          onTap: () {
            DownloadModalSheet.show(
              context,
              url: _quickLinkController.text.isNotEmpty
                  ? _quickLinkController.text
                  : 'https://www.youtube.com',
            );
          },
        ),
        const SizedBox(width: 10),
        _buildQuickActionButton(
          icon: LucideIcons.shuffle,
          label: l10n.translate('surprise_me'),
          color: AppColors.accentRose,
          isDark: isDark,
          onTap: () {
            final trending = ref.read(trendingVideosProvider).valueOrNull;
            if (trending != null && trending.isNotEmpty) {
              final random = trending[DateTime.now().millisecondsSinceEpoch % trending.length];
              _navigateToWatch(random);
            }
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.12 : 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueWatchingSection(
    List<RecentlyPlayedItem> items,
    bool isDark,
    AppLocalizations l10n,
    bool isDesktop,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : 16,
            vertical: 12,
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.playCircle, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                l10n.translate('continue_watching'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 16,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildContinueWatchingCard(item, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContinueWatchingCard(RecentlyPlayedItem item, bool isDark) {
    return GestureDetector(
      onTap: () => _navigateToRecentlyPlayed(item),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 80,
                  width: double.infinity,
                  child: Image.network(
                    item.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      child: const Center(child: Icon(LucideIcons.video, size: 24)),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: item.progress,
                    backgroundColor: Colors.black26,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    minHeight: 3,
                  ),
                ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatSeconds(item.positionSeconds),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(item.progress * 100).toInt()}% • ${item.channelTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentlyPlayedSection(
    List<RecentlyPlayedItem> items,
    bool isDark,
    AppLocalizations l10n,
    bool isDesktop,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : 16,
            vertical: 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.clock, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    l10n.translate('recently_played'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => ref.read(recentlyPlayedProvider.notifier).clearAll(),
                child: Text(
                  l10n.translate('clear_all'),
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 16,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildRecentlyPlayedCard(item, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentlyPlayedCard(RecentlyPlayedItem item, bool isDark) {
    return GestureDetector(
      onTap: () => _navigateToRecentlyPlayed(item),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 70,
                  width: double.infinity,
                  child: Image.network(
                    item.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      child: const Center(child: Icon(LucideIcons.video, size: 20)),
                    ),
                  ),
                ),
                if (item.isPartiallyWatched)
                  Positioned.fill(
                    child: Container(
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.play, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.channelTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSeconds(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
