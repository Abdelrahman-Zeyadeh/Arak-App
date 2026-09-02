import 'download_format.dart';

enum DownloadStatus {
  pending,
  probing,
  downloading,
  processing,
  completed,
  failed,
  paused,
  canceled,
}

class DownloadTask {
  final String id;
  final String url;
  final String title;
  final String thumbnailUrl;
  final DownloadFormat format;
  final String savePath;
  final double progress; // 0.0 to 1.0
  final String percentageStr;
  final String speedStr;
  final String etaStr;
  final int downloadedBytes;
  final int totalBytes;
  final DownloadStatus status;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;

  const DownloadTask({
    required this.id,
    required this.url,
    required this.title,
    required this.thumbnailUrl,
    required this.format,
    required this.savePath,
    this.progress = 0.0,
    this.percentageStr = '0%',
    this.speedStr = '',
    this.etaStr = '',
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.status = DownloadStatus.pending,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
  });

  DownloadTask copyWith({
    String? id,
    String? url,
    String? title,
    String? thumbnailUrl,
    DownloadFormat? format,
    String? savePath,
    double? progress,
    String? percentageStr,
    String? speedStr,
    String? etaStr,
    int? downloadedBytes,
    int? totalBytes,
    DownloadStatus? status,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      format: format ?? this.format,
      savePath: savePath ?? this.savePath,
      progress: progress ?? this.progress,
      percentageStr: percentageStr ?? this.percentageStr,
      speedStr: speedStr ?? this.speedStr,
      etaStr: etaStr ?? this.etaStr,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'thumbnailUrl': thumbnailUrl,
      'formatId': format.formatId,
      'formatExt': format.ext,
      'formatRes': format.resolution,
      'isAudioOnly': format.isAudioOnly,
      'savePath': savePath,
      'status': status.name,
      'totalBytes': totalBytes,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }
}
