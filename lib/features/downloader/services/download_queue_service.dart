import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/storage/secure_storage_service.dart';
import '../../downloads_library/models/local_download_item.dart';
import '../../downloads_library/services/downloads_library_service.dart';
import '../models/download_format.dart';
import '../models/download_task.dart';
import 'ytdlp_engine.dart';

class DownloadQueueService {
  static final DownloadQueueService _instance = DownloadQueueService._internal();
  factory DownloadQueueService() => _instance;
  DownloadQueueService._internal();

  final List<DownloadTask> _tasks = [];
  int _maxConcurrent = 2;
  final _controller = StreamController<List<DownloadTask>>.broadcast();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;

  Stream<List<DownloadTask>> get taskStream => _controller.stream;
  List<DownloadTask> get currentTasks => List.unmodifiable(_tasks);
  int get maxConcurrent => _maxConcurrent;

  final _activeSubscriptions = <String, StreamSubscription>{};

  Future<void> initNotifications() async {
    if (_notificationsInitialized) return;
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _notifications.initialize(initSettings);
      _notificationsInitialized = true;
    } catch (e) {
      debugPrint('[DownloadQueueService] Failed to init notifications: $e');
    }
  }

  void setMaxConcurrent(int max) {
    _maxConcurrent = max.clamp(1, 5);
    _processQueue();
  }

  Future<String> getDefaultDownloadDirectory() async {
    final customPath = SecureStorageService().getDownloadPath();
    if (customPath != null && customPath.isNotEmpty) {
      final dir = Directory(customPath);
      if (await dir.exists()) return customPath;
    }

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final arakDir = Directory(p.join(downloadsDir.path, 'Arak Downloads'));
        if (!await arakDir.exists()) await arakDir.create(recursive: true);
        return arakDir.path;
      }
    }

    final docDir = await getApplicationDocumentsDirectory();
    final arakDir = Directory(p.join(docDir.path, 'Arak Downloads'));
    if (!await arakDir.exists()) await arakDir.create(recursive: true);
    return arakDir.path;
  }

  Future<void> enqueueDownload({
    required String url,
    required String title,
    required String thumbnailUrl,
    required DownloadFormat format,
    String? customOutputDir,
  }) async {
    final saveDir = customOutputDir ?? await getDefaultDownloadDirectory();
    final taskId = 'task_${DateTime.now().millisecondsSinceEpoch}_${_tasks.length}';

    final task = DownloadTask(
      id: taskId,
      url: url,
      title: title,
      thumbnailUrl: thumbnailUrl,
      format: format,
      savePath: saveDir,
      status: DownloadStatus.pending,
      createdAt: DateTime.now(),
    );

    _tasks.insert(0, task);
    _notify();
    _processQueue();
  }

  void _notify() {
    _controller.add(List.unmodifiable(_tasks));
  }

  void _processQueue() {
    final activeCount = _tasks.where((t) => t.status == DownloadStatus.downloading).length;
    if (activeCount >= _maxConcurrent) return;

    final pendingTasks = _tasks.where((t) => t.status == DownloadStatus.pending).toList();
    if (pendingTasks.isNotEmpty) {
      _startTask(pendingTasks.first);
    }
  }

  Future<void> _startTask(DownloadTask task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) return;

    _tasks[index] = task.copyWith(status: DownloadStatus.downloading);
    _notify();

    final stream = YtDlpEngine().downloadStream(
      url: task.url,
      format: task.format,
      outputDir: task.savePath,
    );

    final subscription = stream.listen((event) async {
      final taskIdx = _tasks.indexWhere((t) => t.id == task.id);
      if (taskIdx == -1) return;

      final current = _tasks[taskIdx];
      final type = event['type'];

      if (type == 'progress') {
        _tasks[taskIdx] = current.copyWith(
          progress: event['progress'] as double? ?? current.progress,
          percentageStr: event['percentageStr'] as String? ?? current.percentageStr,
          speedStr: event['speed'] as String? ?? current.speedStr,
          etaStr: event['eta'] as String? ?? current.etaStr,
        );
        _notify();
      } else if (type == 'completed') {
        final filePath = event['filePath'] as String? ?? task.savePath;
        _tasks[taskIdx] = current.copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
          percentageStr: '100%',
          completedAt: DateTime.now(),
        );
        _notify();
        _activeSubscriptions.remove(task.id);

        // Register in local library
        int fileSize = 0;
        try {
          final f = File(filePath);
          if (await f.exists()) fileSize = await f.length();
        } catch (e) {
          debugPrint('[DownloadQueueService] Error: $e');
        }

        await DownloadsLibraryService().addItem(LocalDownloadItem(
          id: task.id,
          title: task.title,
          filePath: filePath,
          originalUrl: task.url,
          thumbnailUrl: task.thumbnailUrl,
          formatExt: task.format.ext,
          resolution: task.format.resolution,
          isAudioOnly: task.format.isAudioOnly,
          fileSizeBytes: fileSize,
          downloadedAt: DateTime.now(),
        ));

        // Show completion notification
        _showCompleteNotification(task.title);

        _processQueue();
      } else if (type == 'error') {
        _tasks[taskIdx] = current.copyWith(
          status: DownloadStatus.failed,
          errorMessage: event['message']?.toString() ?? 'Download failed',
        );
        _notify();
        _activeSubscriptions.remove(task.id);
        _processQueue();
      }
    }, onError: (e) {
      final taskIdx = _tasks.indexWhere((t) => t.id == task.id);
      if (taskIdx != -1) {
        _tasks[taskIdx] = _tasks[taskIdx].copyWith(
          status: DownloadStatus.failed,
          errorMessage: e.toString(),
        );
        _notify();
      }
      _activeSubscriptions.remove(task.id);
      _processQueue();
    });

    _activeSubscriptions[task.id] = subscription;
  }

  void pauseTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1 && _tasks[index].status == DownloadStatus.downloading) {
      _activeSubscriptions[taskId]?.cancel();
      _activeSubscriptions.remove(taskId);
      _tasks[index] = _tasks[index].copyWith(status: DownloadStatus.paused);
      _notify();
      _processQueue();
    }
  }

  void resumeTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1 && _tasks[index].status == DownloadStatus.paused) {
      _tasks[index] = _tasks[index].copyWith(
        status: DownloadStatus.pending,
        progress: _tasks[index].progress,
      );
      _notify();
      _processQueue();
    }
  }

  void cancelTask(String taskId) {
    _activeSubscriptions[taskId]?.cancel();
    _activeSubscriptions.remove(taskId);

    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(status: DownloadStatus.canceled);
      _notify();
    }
    _processQueue();
  }

  void retryTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _tasks[index];
      _tasks[index] = task.copyWith(
        status: DownloadStatus.pending,
        progress: 0.0,
        percentageStr: '0%',
        errorMessage: null,
      );
      _notify();
      _processQueue();
    }
  }

  void clearCompleted() {
    _tasks.removeWhere((t) =>
        t.status == DownloadStatus.completed || t.status == DownloadStatus.canceled);
    _notify();
  }

  Future<void> _showCompleteNotification(String title) async {
    if (!_notificationsInitialized) return;
    try {
      const androidDetails = AndroidNotificationDetails(
        'arak_downloads',
        'Arak Downloads',
        channelDescription: 'Notifications for completed downloads',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const details = NotificationDetails(android: androidDetails);
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'Download Complete',
        '$title has been downloaded successfully',
        details,
      );
    } catch (e) {
      debugPrint('[DownloadQueueService] Failed to show notification: $e');
    }
  }
}
