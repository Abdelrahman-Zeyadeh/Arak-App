import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService {
  static final SearchHistoryService _instance = SearchHistoryService._internal();
  factory SearchHistoryService() => _instance;
  SearchHistoryService._internal();

  static const String _storageKey = 'arak_search_history_list';
  static const int _maxHistoryItems = 20;

  Future<List<String>> getRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List decoded = jsonDecode(jsonStr);
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('[SearchHistoryService] Error: $e');
      return [];
    }
  }

  Future<List<String>> addSearchQuery(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return await getRecentSearches();

    final prefs = await SharedPreferences.getInstance();
    final list = await getRecentSearches();

    // Remove duplicates if already exists and insert at the top
    list.removeWhere((item) => item.toLowerCase() == clean.toLowerCase());
    list.insert(0, clean);

    if (list.length > _maxHistoryItems) {
      list.removeRange(_maxHistoryItems, list.length);
    }

    await prefs.setString(_storageKey, jsonEncode(list));
    return list;
  }

  Future<List<String>> removeSearchQuery(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getRecentSearches();
    list.removeWhere((item) => item.toLowerCase() == query.trim().toLowerCase());
    await prefs.setString(_storageKey, jsonEncode(list));
    return list;
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
