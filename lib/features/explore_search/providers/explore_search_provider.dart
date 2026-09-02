import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/youtube_channel.dart';
import '../models/youtube_video.dart';
import '../services/search_history_service.dart';
import '../services/youtube_api_service.dart';

final selectedCategoryProvider = StateProvider<String?>((ref) => null);

final trendingVideosProvider = FutureProvider<List<YouTubeVideo>>((ref) async {
  final categoryId = ref.watch(selectedCategoryProvider);
  return await YouTubeApiService().fetchTrendingVideos(categoryId: categoryId);
});

final relatedVideosProvider = FutureProvider.family<List<YouTubeVideo>, String>((ref, videoId) async {
  return await YouTubeApiService().fetchRelatedVideos(videoId);
});

// Search History State Notifier
final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier();
});

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier() : super(const []) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    state = await SearchHistoryService().getRecentSearches();
  }

  Future<void> addQuery(String query) async {
    state = await SearchHistoryService().addSearchQuery(query);
  }

  Future<void> removeQuery(String query) async {
    state = await SearchHistoryService().removeSearchQuery(query);
  }

  Future<void> clearAll() async {
    await SearchHistoryService().clearAll();
    state = [];
  }
}

// Search State
class SearchState {
  final String query;
  final List<YouTubeVideo> videos;
  final YouTubeChannel? channel;
  final String sortBy; // 'relevance', 'date', 'viewCount'
  final bool isLoading;
  final bool isLoadingMore;
  final String? nextPageToken;
  final String? errorMessage;
  final bool hasMore;

  const SearchState({
    this.query = '',
    this.videos = const [],
    this.channel,
    this.sortBy = 'relevance',
    this.isLoading = false,
    this.isLoadingMore = false,
    this.nextPageToken,
    this.errorMessage,
    this.hasMore = true,
  });

  SearchState copyWith({
    String? query,
    List<YouTubeVideo>? videos,
    YouTubeChannel? channel,
    bool clearChannel = false,
    String? sortBy,
    bool? isLoading,
    bool? isLoadingMore,
    String? nextPageToken,
    String? errorMessage,
    bool? hasMore,
  }) {
    return SearchState(
      query: query ?? this.query,
      videos: videos ?? this.videos,
      channel: clearChannel ? null : (channel ?? this.channel),
      sortBy: sortBy ?? this.sortBy,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      nextPageToken: nextPageToken ?? this.nextPageToken,
      errorMessage: errorMessage,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

final searchNotifierProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});

class SearchNotifier extends StateNotifier<SearchState> {
  final Ref _ref;
  SearchNotifier(this._ref) : super(const SearchState());

  final _apiService = YouTubeApiService();

  Future<void> search(String query, {String? sortBy}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = const SearchState();
      return;
    }

    final activeSort = sortBy ?? state.sortBy;

    // Save to search history
    _ref.read(searchHistoryProvider.notifier).addQuery(trimmed);

    state = state.copyWith(
      query: trimmed,
      sortBy: activeSort,
      isLoading: true,
      errorMessage: null,
      hasMore: true,
      clearChannel: true,
    );

    try {
      final result = await _apiService.searchVideos(
        query: trimmed,
        sortBy: activeSort,
      );

      state = state.copyWith(
        videos: result.videos,
        channel: result.channel,
        nextPageToken: result.nextPageToken,
        hasMore: result.hasMore,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void setSortBy(String newSort) {
    if (state.sortBy == newSort) return;
    if (state.query.isNotEmpty) {
      search(state.query, sortBy: newSort);
    } else {
      state = state.copyWith(sortBy: newSort);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.query.isEmpty) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);

    try {
      final result = await _apiService.loadMoreSearchResults(
        query: state.query,
        nextPageToken: state.nextPageToken,
        sortBy: state.sortBy,
      );

      if (result.videos.isNotEmpty) {
        state = state.copyWith(
          videos: [...state.videos, ...result.videos],
          nextPageToken: result.nextPageToken,
          isLoadingMore: false,
          hasMore: result.hasMore,
        );
      } else {
        state = state.copyWith(isLoadingMore: false, hasMore: false);
      }
    } catch (e) {
      debugPrint('[SearchNotifier] loadMore error: $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void clear() {
    state = const SearchState();
  }
}
