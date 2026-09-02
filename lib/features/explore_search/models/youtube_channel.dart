class YouTubeChannel {
  final String id;
  final String title;
  final String description;
  final String avatarUrl;
  final String? bannerUrl;
  final int subscriberCount;
  final int videoCount;

  const YouTubeChannel({
    required this.id,
    required this.title,
    required this.description,
    required this.avatarUrl,
    this.bannerUrl,
    this.subscriberCount = 0,
    this.videoCount = 0,
  });

  String get channelUrl => 'https://www.youtube.com/channel/$id';

  factory YouTubeChannel.fromApiJson(Map<String, dynamic> json) {
    final snippet = json['snippet'] ?? {};
    final idData = json['id'];
    String channelId = '';

    if (idData is Map) {
      channelId = idData['channelId'] ?? '';
    } else if (idData is String) {
      channelId = idData;
    } else if (json['id'] is String) {
      channelId = json['id'];
    }

    final thumbnails = snippet['thumbnails'] ?? {};
    final thumb = thumbnails['high']?['url'] ??
        thumbnails['medium']?['url'] ??
        thumbnails['default']?['url'] ??
        '';

    final stats = json['statistics'] ?? {};
    final subs = int.tryParse(stats['subscriberCount']?.toString() ?? '0') ?? 0;
    final vids = int.tryParse(stats['videoCount']?.toString() ?? '0') ?? 0;

    return YouTubeChannel(
      id: channelId,
      title: snippet['title'] ?? '',
      description: snippet['description'] ?? '',
      avatarUrl: thumb,
      subscriberCount: subs,
      videoCount: vids,
    );
  }
}
