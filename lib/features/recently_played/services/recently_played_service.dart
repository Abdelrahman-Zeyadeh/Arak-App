import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recently_played_item.dart';

class RecentlyPlayedService {
  static final RecentlyPlayedService _instance = RecentlyPlayedService._internal();
  factory RecentlyPlayedService() => _instance;
  RecentlyPlayedService._internal();

  static const String _storageKey = 'arak_recently_played';
  static const int _maxItems = 50;

  Future<List<RecentlyPlayedItem>> getRecentlyPlayed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList
          .map((json) => RecentlyPlayedItem.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('[RecentlyPlayedService] Error loading: $e');
      return [];
    }
  }

  Future<void> addItem(RecentlyPlayedItem item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = await getRecentlyPlayed();

      // Remove existing item with same videoId
      items.removeWhere((i) => i.videoId == item.videoId);

      // Add new item at the beginning
      items.insert(0, item);

      // Keep only the last _maxItems
      final trimmedItems = items.length > _maxItems ? items.sublist(0, _maxItems) : items;

      // Save
      final jsonList = trimmedItems.map((i) => i.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[RecentlyPlayedService] Error saving: $e');
    }
  }

  Future<void> updateProgress({
    required String videoId,
    required double progress,
    required int positionSeconds,
    required int totalSeconds,
  }) async {
    try {
      final items = await getRecentlyPlayed();
      final index = items.indexWhere((i) => i.videoId == videoId);
      if (index != -1) {
        items[index] = items[index].copyWith(
          progress: progress,
          positionSeconds: positionSeconds,
          totalSeconds: totalSeconds,
          watchedAt: DateTime.now(),
        );
        final prefs = await SharedPreferences.getInstance();
        final jsonList = items.map((i) => i.toJson()).toList();
        await prefs.setString(_storageKey, jsonEncode(jsonList));
      }
    } catch (e) {
      debugPrint('[RecentlyPlayedService] Error updating progress: $e');
    }
  }

  Future<void> removeItem(String videoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = await getRecentlyPlayed();
      items.removeWhere((i) => i.videoId == videoId);
      final jsonList = items.map((i) => i.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[RecentlyPlayedService] Error removing: $e');
    }
  }

  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      debugPrint('[RecentlyPlayedService] Error clearing: $e');
    }
  }

  Future<List<RecentlyPlayedItem>> getContinueWatching() async {
    final items = await getRecentlyPlayed();
    return items.where((i) => i.isPartiallyWatched).take(10).toList();
  }
}
