class LocalDownloadItem {
  final String id;
  final String title;
  final String filePath;
  final String originalUrl;
  final String thumbnailUrl;
  final String formatExt;
  final String resolution;
  final bool isAudioOnly;
  final int fileSizeBytes;
  final DateTime downloadedAt;
  final int durationSeconds;

  const LocalDownloadItem({
    required this.id,
    required this.title,
    required this.filePath,
    required this.originalUrl,
    required this.thumbnailUrl,
    required this.formatExt,
    required this.resolution,
    required this.isAudioOnly,
    required this.fileSizeBytes,
    required this.downloadedAt,
    this.durationSeconds = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'filePath': filePath,
      'originalUrl': originalUrl,
      'thumbnailUrl': thumbnailUrl,
      'formatExt': formatExt,
      'resolution': resolution,
      'isAudioOnly': isAudioOnly,
      'fileSizeBytes': fileSizeBytes,
      'downloadedAt': downloadedAt.toIso8601String(),
      'durationSeconds': durationSeconds,
    };
  }

  factory LocalDownloadItem.fromJson(Map<String, dynamic> map) {
    return LocalDownloadItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      filePath: map['filePath'] ?? '',
      originalUrl: map['originalUrl'] ?? '',
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      formatExt: map['formatExt'] ?? 'mp4',
      resolution: map['resolution'] ?? '',
      isAudioOnly: map['isAudioOnly'] ?? false,
      fileSizeBytes: map['fileSizeBytes'] ?? 0,
      downloadedAt: map['downloadedAt'] != null 
          ? DateTime.parse(map['downloadedAt']) 
          : DateTime.now(),
      durationSeconds: map['durationSeconds'] ?? 0,
    );
  }

  LocalDownloadItem copyWith({
    String? title,
    String? filePath,
  }) {
    return LocalDownloadItem(
      id: id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      originalUrl: originalUrl,
      thumbnailUrl: thumbnailUrl,
      formatExt: formatExt,
      resolution: resolution,
      isAudioOnly: isAudioOnly,
      fileSizeBytes: fileSizeBytes,
      downloadedAt: downloadedAt,
      durationSeconds: durationSeconds,
    );
  }
}
