import '../../../core/utils/formatters.dart';

class DownloadFormat {
  final String formatId;
  final String ext;
  final String resolution;
  final String note;
  final int? filesize;
  final bool isAudioOnly;
  final bool hasVideo;
  final bool hasAudio;
  final int? fps;
  final int? abr; // Audio bitrate
  final String? directUrl; // Pre-resolved direct stream URL (if available)

  const DownloadFormat({
    required this.formatId,
    required this.ext,
    required this.resolution,
    this.note = '',
    this.filesize,
    this.isAudioOnly = false,
    this.hasVideo = true,
    this.hasAudio = true,
    this.fps,
    this.abr,
    this.directUrl,
  });

  String get displayLabel {
    if (isAudioOnly) {
      final rate = abr != null ? '${abr}kbps' : (note.isNotEmpty ? note : 'High Quality');
      return 'Audio ($ext) • $rate';
    }
    final fpsStr = (fps != null && fps! > 30) ? '${fps}fps' : '';
    final res = resolution.isNotEmpty ? resolution : (note.isNotEmpty ? note : 'Standard');
    return '$res $fpsStr ($ext)'.trim();
  }

  String get sizeLabel {
    if (filesize != null && filesize! > 0) {
      return Formatters.formatBytes(filesize!);
    }
    return '';
  }

  factory DownloadFormat.fromJson(Map<String, dynamic> json) {
    final vcodec = json['vcodec']?.toString() ?? 'none';
    final acodec = json['acodec']?.toString() ?? 'none';
    final isAudio = vcodec == 'none' && acodec != 'none';
    final height = json['height'];

    String res = '';
    if (height != null && height > 0) {
      res = '${height}p';
    } else if (json['resolution'] != null) {
      res = json['resolution'].toString();
    }

    final filesize = json['filesize'] ?? json['filesize_approx'];

    return DownloadFormat(
      formatId: json['format_id']?.toString() ?? '',
      ext: json['ext']?.toString() ?? 'mp4',
      resolution: res,
      note: json['format_note']?.toString() ?? json['format']?.toString() ?? '',
      filesize: filesize is int ? filesize : null,
      isAudioOnly: isAudio,
      hasVideo: vcodec != 'none',
      hasAudio: acodec != 'none',
      fps: json['fps'] is int ? json['fps'] : null,
      abr: json['abr'] is num ? (json['abr'] as num).toInt() : null,
      // yt-dlp's --dump-json already resolves a direct playable URL per
      // format for most extractors. Capturing it here lets non-YouTube
      // downloads (Facebook/Instagram/Twitter/etc. via the extraction
      // backend) go straight to a direct HTTP download without a second
      // resolution step.
      directUrl: json['url']?.toString(),
    );
  }
}
