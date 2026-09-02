import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import '../../../core/constants/app_constants.dart';
import '../models/local_download_item.dart';

class DownloadsLibraryService {
  static final DownloadsLibraryService _instance = DownloadsLibraryService._internal();
  factory DownloadsLibraryService() => _instance;
  DownloadsLibraryService._internal();

  List<LocalDownloadItem> _items = [];

  Future<List<LocalDownloadItem>> loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(AppConstants.downloadsDbKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      _items = [];
      return [];
    }

    try {
      final List decoded = jsonDecode(jsonStr);
      _items = decoded.map((e) => LocalDownloadItem.fromJson(e as Map<String, dynamic>)).toList();
      return _items;
    } catch (e) {
      debugPrint('[DownloadsLibraryService] Error: $e');
      _items = [];
      return [];
    }
  }

  Future<void> addItem(LocalDownloadItem item) async {
    await loadItems();
    _items.removeWhere((it) => it.id == item.id || it.filePath == item.filePath);
    _items.insert(0, item);
    await _save();
  }

  Future<void> removeItem(String id, {bool deleteFileFromDisk = true}) async {
    await loadItems();
    final itemIndex = _items.indexWhere((it) => it.id == id);
    if (itemIndex != -1) {
      final item = _items[itemIndex];
      if (deleteFileFromDisk) {
        try {
          final file = File(item.filePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('[DownloadsLibraryService] Error: $e');
        }
      }
      _items.removeAt(itemIndex);
      await _save();
    }
  }

  Future<void> renameItem(String id, String newTitle) async {
    await loadItems();
    final index = _items.indexWhere((it) => it.id == id);
    if (index != -1) {
      final item = _items[index];
      final file = File(item.filePath);
      if (await file.exists()) {
        final dir = file.parent.path;
        final ext = p.extension(item.filePath);
        final safeName = newTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final newPath = p.join(dir, '$safeName$ext');

        try {
          await file.rename(newPath);
          _items[index] = item.copyWith(title: newTitle, filePath: newPath);
          await _save();
        } catch (e) {
          debugPrint('[DownloadsLibraryService] Error: $e');
        }
      } else {
        _items[index] = item.copyWith(title: newTitle);
        await _save();
      }
    }
  }

  Future<void> openFileLocation(String filePath) async {
    try {
      final file = File(filePath);
      final dir = file.existsSync() ? file.parent.path : filePath;

      if (Platform.isWindows) {
        if (file.existsSync()) {
          await Process.run('explorer.exe', ['/select,', filePath]);
        } else {
          await Process.run('explorer.exe', [dir]);
        }
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', filePath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [dir]);
      } else {
        await launchUrl(Uri.file(dir));
      }
    } catch (e) {
      debugPrint('[DownloadsLibraryService] Error: $e');
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString(AppConstants.downloadsDbKey, jsonStr);
  }
}
