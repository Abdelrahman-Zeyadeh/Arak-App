class RecentlyPlayedItem {
  final String videoId;
  final String title;
  final String thumbnailUrl;
  final String channelTitle;
  final String duration;
  final DateTime watchedAt;
  final double progress; // 0.0 to 1.0
  final int positionSeconds; // Position in video in seconds
  final int totalSeconds; // Total video duration in seconds

  const RecentlyPlayedItem({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    required this.channelTitle,
    required this.duration,
    required this.watchedAt,
    this.progress = 0.0,
    this.positionSeconds = 0,
    this.totalSeconds = 0,
  });

  bool get isPartiallyWatched => progress > 0.0 && progress < 0.95;
  bool get isCompleted => progress >= 0.95;

  RecentlyPlayedItem copyWith({
    String? videoId,
    String? title,
    String? thumbnailUrl,
    String? channelTitle,
    String? duration,
    DateTime? watchedAt,
    double? progress,
    int? positionSeconds,
    int? totalSeconds,
  }) {
    return RecentlyPlayedItem(
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      channelTitle: channelTitle ?? this.channelTitle,
      duration: duration ?? this.duration,
      watchedAt: watchedAt ?? this.watchedAt,
      progress: progress ?? this.progress,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'title': title,
      'thumbnailUrl': thumbnailUrl,
      'channelTitle': channelTitle,
      'duration': duration,
      'watchedAt': watchedAt.toIso8601String(),
      'progress': progress,
      'positionSeconds': positionSeconds,
      'totalSeconds': totalSeconds,
    };
  }

  factory RecentlyPlayedItem.fromJson(Map<String, dynamic> json) {
    return RecentlyPlayedItem(
      videoId: json['videoId'] ?? '',
      title: json['title'] ?? '',
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      channelTitle: json['channelTitle'] ?? '',
      duration: json['duration'] ?? '',
      watchedAt: DateTime.tryParse(json['watchedAt'] ?? '') ?? DateTime.now(),
      progress: (json['progress'] ?? 0.0).toDouble(),
      positionSeconds: json['positionSeconds'] ?? 0,
      totalSeconds: json['totalSeconds'] ?? 0,
    );
  }
}
