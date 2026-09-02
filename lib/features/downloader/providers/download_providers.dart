import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/download_task.dart';
import '../models/video_metadata.dart';
import '../services/download_queue_service.dart';
import '../services/ytdlp_engine.dart';

final downloadQueueProvider = StreamProvider<List<DownloadTask>>((ref) {
  return DownloadQueueService().taskStream;
});

final probeVideoProvider = FutureProvider.family<VideoMetadata?, String>((ref, url) async {
  return await YtDlpEngine().probeVideo(url);
});

final activeDownloadsCountProvider = Provider<int>((ref) {
  final tasksAsync = ref.watch(downloadQueueProvider);
  return tasksAsync.maybeWhen(
    data: (tasks) => tasks.where((t) => t.status == DownloadStatus.downloading || t.status == DownloadStatus.pending).length,
    orElse: () => 0,
  );
});
