import '../../../core/utils/formatters.dart';

class YouTubeVideo {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String channelTitle;
  final String channelId;
  final String? channelAvatarUrl;
  final DateTime? publishedAt;
  final int viewCount;
  final int likeCount;
  final String duration;
  final bool isLive;

  const YouTubeVideo({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.channelTitle,
    required this.channelId,
    this.channelAvatarUrl,
    this.publishedAt,
    this.viewCount = 0,
    this.likeCount = 0,
    this.duration = '',
    this.isLive = false,
  });

  String get watchUrl => 'https://www.youtube.com/watch?v=$id';
  String get shortUrl => 'https://youtu.be/$id';

  factory YouTubeVideo.fromApiJson(Map<String, dynamic> json, {Map<String, dynamic>? detailsJson}) {
    final snippet = json['snippet'] ?? {};
    final idData = json['id'];
    String videoId = '';

    if (idData is Map) {
      videoId = idData['videoId'] ?? idData['playlistId'] ?? '';
    } else if (idData is String) {
      videoId = idData;
    } else if (json['id'] is String) {
      videoId = json['id'];
    }

    final thumbnails = snippet['thumbnails'] ?? {};
    final highThumb = thumbnails['high']?['url'] ??
        thumbnails['medium']?['url'] ??
        thumbnails['default']?['url'] ??
        'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

    // Details if available
    int views = 0;
    int likes = 0;
    String dur = '';

    if (detailsJson != null) {
      final stats = detailsJson['statistics'] ?? {};
      views = int.tryParse(stats['viewCount']?.toString() ?? '0') ?? 0;
      likes = int.tryParse(stats['likeCount']?.toString() ?? '0') ?? 0;

      final contentDetails = detailsJson['contentDetails'] ?? {};
      final rawDuration = contentDetails['duration']?.toString() ?? '';
      dur = Formatters.parseIso8601Duration(rawDuration);
    }

    DateTime? pubDate;
    if (snippet['publishedAt'] != null) {
      pubDate = DateTime.tryParse(snippet['publishedAt']);
    }

    final isLiveBroadcast = snippet['liveBroadcastContent'] == 'live';

    return YouTubeVideo(
      id: videoId,
      title: snippet['title'] ?? '',
      description: snippet['description'] ?? '',
      thumbnailUrl: highThumb,
      channelTitle: snippet['channelTitle'] ?? '',
      channelId: snippet['channelId'] ?? '',
      publishedAt: pubDate,
      viewCount: views,
      likeCount: likes,
      duration: dur,
      isLive: isLiveBroadcast,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'channelTitle': channelTitle,
      'channelId': channelId,
      'channelAvatarUrl': channelAvatarUrl,
      'publishedAt': publishedAt?.toIso8601String(),
      'viewCount': viewCount,
      'likeCount': likeCount,
      'duration': duration,
      'isLive': isLive,
    };
  }

  factory YouTubeVideo.fromJson(Map<String, dynamic> map) {
    return YouTubeVideo(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      channelTitle: map['channelTitle'] ?? '',
      channelId: map['channelId'] ?? '',
      channelAvatarUrl: map['channelAvatarUrl'],
      publishedAt: map['publishedAt'] != null ? DateTime.tryParse(map['publishedAt']) : null,
      viewCount: map['viewCount'] ?? 0,
      likeCount: map['likeCount'] ?? 0,
      duration: map['duration'] ?? '',
      isLive: map['isLive'] ?? false,
    );
  }
}
