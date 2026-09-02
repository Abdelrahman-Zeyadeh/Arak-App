import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../downloader/widgets/download_modal_sheet.dart';
import '../models/youtube_channel.dart';
import '../providers/explore_search_provider.dart';
import 'channel_screen.dart';
import 'widgets/video_card.dart';
import 'widgets/video_skeleton.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _hasText = ValueNotifier(false);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(() {
      _hasText.value = _searchController.text.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _hasText.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      ref.read(searchNotifierProvider.notifier).loadMore();
    }
  }

  void _performSearch(String query, {String? sortBy}) {
    if (query.trim().isEmpty) return;
    final trimmed = query.trim();

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      DownloadModalSheet.show(context, url: trimmed);
      return;
    }

    _searchController.text = trimmed;
    ref.read(searchNotifierProvider.notifier).search(trimmed, sortBy: sortBy);
  }

  void _performSearchOnType(String val) {
    // Only update the URL detection banner, don't trigger search on every keystroke
    if (val.trim().isNotEmpty && _isUrl(val)) {
      setState(() {}); // Only rebuild for URL banner
    }
  }

  bool _isUrl(String text) {
    final t = text.trim();
    final urlPattern = RegExp(
      r'^(https?:\/\/)?(www\.)?(youtube\.com|youtu\.be|instagram\.com|tiktok\.com|vimeo\.com|facebook\.com|twitter\.com|x\.com)\/',
      caseSensitive: false,
    );
    return urlPattern.hasMatch(t);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchState = ref.watch(searchNotifierProvider);
    final historyList = ref.watch(searchHistoryProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 46,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (val) => _performSearch(val),
            onChanged: (val) {
              _performSearchOnType(val);
            },
            decoration: InputDecoration(
              hintText: l10n.translate('search_placeholder'),
              prefixIcon: IconButton(
                icon: const Icon(LucideIcons.search, size: 18, color: AppColors.primary),
                onPressed: () => _performSearch(_searchController.text),
              ),
              suffixIcon: ValueListenableBuilder<bool>(
                valueListenable: _hasText,
                builder: (context, hasText, _) {
                  return hasText
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(searchNotifierProvider.notifier).clear();
                            _hasText.value = false;
                          },
                        )
                      : const SizedBox.shrink();
                },
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ElevatedButton(
              onPressed: () => _performSearch(_searchController.text),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.translate('nav_search')),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // URL Detected Download Banner
          if (_isUrl(_searchController.text))
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 16,
                  vertical: 16,
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.15),
                        AppColors.accentBlue.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.link, color: AppColors.primary, size: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.translate('quick_download'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _searchController.text.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => DownloadModalSheet.show(context, url: _searchController.text.trim()),
                        icon: const Icon(LucideIcons.download, size: 16),
                        label: Text(l10n.translate('download_btn')),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Channel Match Result Card (Appears at the very top of search)
          if (searchState.channel != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 16,
                  vertical: 12,
                ),
                child: _buildChannelCard(searchState.channel!, isDark, l10n),
              ),
            ),

          // Search Results Header & Sort Filters Bar
          if (searchState.videos.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${l10n.translate('search_results')} (${searchState.videos.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Sort Filter Pills Bar
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            label: 'الأكثر صلة',
                            icon: LucideIcons.sparkles,
                            isSelected: searchState.sortBy == 'relevance',
                            onTap: () => ref.read(searchNotifierProvider.notifier).setSortBy('relevance'),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'الأحدث تاريخاً',
                            icon: LucideIcons.clock,
                            isSelected: searchState.sortBy == 'date',
                            onTap: () => ref.read(searchNotifierProvider.notifier).setSortBy('date'),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'الأعلى مشاهدة',
                            icon: LucideIcons.flame,
                            isSelected: searchState.sortBy == 'viewCount',
                            onTap: () => ref.read(searchNotifierProvider.notifier).setSortBy('viewCount'),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Loading Initial Search
          if (searchState.isLoading)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16, vertical: 16),
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
            )
          // No Results Found
          else if (searchState.videos.isEmpty && searchState.query.isNotEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(60),
                  child: Column(
                    children: [
                      Icon(LucideIcons.searchX, size: 48, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      const SizedBox(height: 16),
                      Text(
                        l10n.translate('no_results'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            )
          // Empty Query View: Show Search History & Suggestions
          else if (searchState.videos.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 16,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recent Searches Section
                    if (historyList.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.history, size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                l10n.translate('recent_searches'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () => ref.read(searchHistoryProvider.notifier).clearAll(),
                            child: Text(
                              l10n.translate('clear_all'),
                              style: const TextStyle(color: AppColors.error, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: historyList.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = historyList[index];
                            return ListTile(
                              leading: const Icon(LucideIcons.clock, size: 16, color: Colors.grey),
                              title: Text(
                                item,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              trailing: IconButton(
                                icon: const Icon(LucideIcons.x, size: 16, color: Colors.grey),
                                onPressed: () => ref.read(searchHistoryProvider.notifier).removeQuery(item),
                              ),
                              onTap: () => _performSearch(item),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Quick Suggested Topics
                    const Text(
                      'اقتراحات شائعة',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'قرآن كريم',
                        'بودكاست',
                        'أحدث الأغاني',
                        'أخبار التقنية',
                        'شروحات برمجية',
                        'وثائقيات',
                        'ألعاب وفيديو جيمز',
                      ].map((topic) {
                        return ActionChip(
                          avatar: const Icon(LucideIcons.trendingUp, size: 14, color: AppColors.primary),
                          label: Text(topic),
                          onPressed: () => _performSearch(topic),
                          backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            )
          // Search Results Grid
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16, vertical: 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: ResponsiveLayout.getGridColumnCount(context),
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: ResponsiveLayout.getCardAspectRatio(context),
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => VideoCard(video: searchState.videos[index]),
                  childCount: searchState.videos.length,
                ),
              ),
            ),

          // Infinite Scroll Loader
          if (searchState.isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildChannelCard(YouTubeChannel channel, bool isDark, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Channel Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: channel.avatarUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      channel.avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(
                        child: Text(
                          channel.title.isNotEmpty ? channel.title.characters.first.toUpperCase() : 'C',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      channel.title.isNotEmpty ? channel.title.characters.first.toUpperCase() : 'C',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        channel.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(LucideIcons.badgeCheck, color: AppColors.primary, size: 16),
                  ],
                ),
                const SizedBox(height: 2),
                if (channel.subscriberCount > 0)
                  Text(
                    '${channel.subscriberCount} ${l10n.translate('subscribers')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  )
                else if (channel.videoCount > 0)
                  Text(
                    '${channel.videoCount} فيديو',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ChannelScreen(channel: channel)),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('عرض القناة'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
