import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recently_played_item.dart';
import '../services/recently_played_service.dart';

final recentlyPlayedProvider = StateNotifierProvider<RecentlyPlayedNotifier, List<RecentlyPlayedItem>>((ref) {
  return RecentlyPlayedNotifier();
});

final continueWatchingProvider = FutureProvider<List<RecentlyPlayedItem>>((ref) async {
  return await RecentlyPlayedService().getContinueWatching();
});

class RecentlyPlayedNotifier extends StateNotifier<List<RecentlyPlayedItem>> {
  RecentlyPlayedNotifier() : super([]) {
    loadRecentlyPlayed();
  }

  Future<void> loadRecentlyPlayed() async {
    state = await RecentlyPlayedService().getRecentlyPlayed();
  }

  Future<void> addItem(RecentlyPlayedItem item) async {
    await RecentlyPlayedService().addItem(item);
    await loadRecentlyPlayed();
  }

  Future<void> updateProgress({
    required String videoId,
    required double progress,
    required int positionSeconds,
    required int totalSeconds,
  }) async {
    await RecentlyPlayedService().updateProgress(
      videoId: videoId,
      progress: progress,
      positionSeconds: positionSeconds,
      totalSeconds: totalSeconds,
    );
    await loadRecentlyPlayed();
  }

  Future<void> removeItem(String videoId) async {
    await RecentlyPlayedService().removeItem(videoId);
    await loadRecentlyPlayed();
  }

  Future<void> clearAll() async {
    await RecentlyPlayedService().clearAll();
    state = [];
  }
}
