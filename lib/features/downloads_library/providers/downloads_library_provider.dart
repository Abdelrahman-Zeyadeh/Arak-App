import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/local_download_item.dart';
import '../services/downloads_library_service.dart';

final downloadsLibraryProvider = StateNotifierProvider<DownloadsLibraryNotifier, List<LocalDownloadItem>>((ref) {
  return DownloadsLibraryNotifier();
});

class DownloadsLibraryNotifier extends StateNotifier<List<LocalDownloadItem>> {
  DownloadsLibraryNotifier() : super([]) {
    load();
  }

  final _service = DownloadsLibraryService();

  Future<void> load() async {
    final items = await _service.loadItems();
    state = items;
  }

  Future<void> add(LocalDownloadItem item) async {
    await _service.addItem(item);
    await load();
  }

  Future<void> remove(String id, {bool deleteFile = true}) async {
    await _service.removeItem(id, deleteFileFromDisk: deleteFile);
    await load();
  }

  Future<void> rename(String id, String newTitle) async {
    await _service.renameItem(id, newTitle);
    await load();
  }

  Future<void> openLocation(String filePath) async {
    await _service.openFileLocation(filePath);
  }
}
