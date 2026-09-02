import 'download_format.dart';

class VideoMetadata {
  final String id;
  final String title;
  final String uploader;
  final String thumbnail;
  final int duration; // in seconds
  final String webpageUrl;
  final List<DownloadFormat> formats;

  const VideoMetadata({
    required this.id,
    required this.title,
    required this.uploader,
    required this.thumbnail,
    required this.duration,
    required this.webpageUrl,
    required this.formats,
  });

  factory VideoMetadata.fromYtDlpJson(Map<String, dynamic> json) {
    final rawFormats = json['formats'] as List? ?? [];
    final formats = rawFormats
        .map((f) => DownloadFormat.fromJson(f as Map<String, dynamic>))
        .where((f) => f.formatId.isNotEmpty)
        .toList();

    return VideoMetadata(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      uploader: json['uploader']?.toString() ?? json['channel']?.toString() ?? '',
      thumbnail: json['thumbnail']?.toString() ?? '',
      duration: json['duration'] is int ? json['duration'] : 0,
      webpageUrl: json['webpage_url']?.toString() ?? json['url']?.toString() ?? '',
      formats: formats,
    );
  }
}
