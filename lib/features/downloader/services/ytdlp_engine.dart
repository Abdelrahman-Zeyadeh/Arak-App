import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/download_format.dart';
import '../models/video_metadata.dart';
import 'backend_extraction_service.dart';

class YtDlpEngine {
  static final YtDlpEngine _instance = YtDlpEngine._internal();
  factory YtDlpEngine() => _instance;
  YtDlpEngine._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    },
  ));

  String? _cachedBinaryPath;
  bool _isDownloadingEngine = false;

  bool get _canExecuteSubprocesses =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  Future<String?> getBinaryPath({void Function(double progress)? onDownloadProgress}) async {
    if (!_canExecuteSubprocesses) return null;

    if (_cachedBinaryPath != null && await File(_cachedBinaryPath!).exists()) {
      return _cachedBinaryPath;
    }

    try {
      final checkCmd = Platform.isWindows ? 'where' : 'which';
      final checkProcess = await Process.run(checkCmd, ['yt-dlp']);
      if (checkProcess.exitCode == 0) {
        final path = checkProcess.stdout.toString().trim().split('\n').first.trim();
        if (path.isNotEmpty && await File(path).exists()) {
          _cachedBinaryPath = path;
          return path;
        }
      }
    } catch (e) {
      debugPrint('[YtDlpEngine] Error: $e');
    }

    try {
      final appDir = await getApplicationSupportDirectory();
      final binName = Platform.isWindows ? 'yt-dlp.exe' : 'yt-dlp';
      final localBinFile = File(p.join(appDir.path, 'bin', binName));

      if (await localBinFile.exists()) {
        _cachedBinaryPath = localBinFile.path;
        return localBinFile.path;
      }

      return await downloadBinary(onProgress: onDownloadProgress);
    } catch (e) {
      debugPrint('[YtDlpEngine] Error: $e');
      return null;
    }
  }

  Future<String?> downloadBinary({void Function(double progress)? onProgress}) async {
    if (!_canExecuteSubprocesses || _isDownloadingEngine) return null;
    _isDownloadingEngine = true;

    try {
      final appDir = await getApplicationSupportDirectory();
      final binDir = Directory(p.join(appDir.path, 'bin'));
      if (!await binDir.exists()) {
        await binDir.create(recursive: true);
      }

      final isWin = Platform.isWindows;
      final isMac = Platform.isMacOS;

      String downloadUrl = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe';
      String targetFilename = 'yt-dlp.exe';

      if (isMac) {
        downloadUrl = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos';
        targetFilename = 'yt-dlp';
      } else if (Platform.isLinux) {
        downloadUrl = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp';
        targetFilename = 'yt-dlp';
      }

      final targetFile = File(p.join(binDir.path, targetFilename));
      final tempFile = File('${targetFile.path}.tmp');

      final dio = Dio();
      await dio.download(
        downloadUrl,
        tempFile.path,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetFile.path);

      if (!isWin) {
        await Process.run('chmod', ['+x', targetFile.path]);
      }

      _cachedBinaryPath = targetFile.path;
      _isDownloadingEngine = false;
      return targetFile.path;
    } catch (e) {
      _isDownloadingEngine = false;
      return null;
    }
  }

  Future<VideoMetadata?> probeVideo(String url) async {
    final ytId = _extractYouTubeId(url);
    if (ytId != null) {
      try {
        final yt = YoutubeExplode();
        final video = await yt.videos.get(ytId);
        final manifest = await yt.videos.streamsClient.getManifest(ytId);
        yt.close();

        final List<DownloadFormat> formats = [];

        for (final muxed in manifest.muxed.sortByVideoQuality()) {
          final res = muxed.qualityLabel;
          final sizeMb = (muxed.size.totalBytes / (1024 * 1024)).toStringAsFixed(1);
          formats.add(DownloadFormat(
            formatId: muxed.tag.toString(),
            ext: muxed.container.name,
            resolution: res,
            note: '$res ($sizeMb MB)',
            filesize: muxed.size.totalBytes,
            hasVideo: true,
            hasAudio: true,
          ));
        }

        for (final vOnly in manifest.videoOnly.sortByVideoQuality()) {
          if (!formats.any((f) => f.resolution == vOnly.qualityLabel)) {
            final res = vOnly.qualityLabel;
            final sizeMb = (vOnly.size.totalBytes / (1024 * 1024)).toStringAsFixed(1);
            formats.add(DownloadFormat(
              formatId: vOnly.tag.toString(),
              ext: vOnly.container.name,
              resolution: res,
              note: '$res Video ($sizeMb MB)',
              filesize: vOnly.size.totalBytes,
              hasVideo: true,
              hasAudio: false,
            ));
          }
        }

        for (final audio in manifest.audioOnly.sortByBitrate()) {
          final bitrateKbps = (audio.bitrate.kiloBitsPerSecond).round();
          final sizeMb = (audio.size.totalBytes / (1024 * 1024)).toStringAsFixed(1);
          final ext = audio.container.name == 'mp4' ? 'm4a' : audio.container.name;
          formats.add(DownloadFormat(
            formatId: audio.tag.toString(),
            ext: ext,
            resolution: 'Audio $bitrateKbps kbps',
            note: '${ext.toUpperCase()} $bitrateKbps kbps ($sizeMb MB)',
            filesize: audio.size.totalBytes,
            isAudioOnly: true,
            hasVideo: false,
            hasAudio: true,
            abr: bitrateKbps,
          ));
        }

        if (formats.isNotEmpty) {
          return VideoMetadata(
            id: video.id.value,
            title: video.title,
            uploader: video.author,
            thumbnail: video.thumbnails.highResUrl,
            duration: video.duration?.inSeconds ?? 0,
            webpageUrl: url,
            formats: formats,
          );
        }
      } catch (e) {
        debugPrint('[YtDlpEngine] Error: $e');
      }
    }

    if (_canExecuteSubprocesses) {
      final bin = await getBinaryPath();
      if (bin != null) {
        try {
          final result = await Process.run(
            bin,
            ['--dump-json', '--no-warnings', '--no-playlist', url],
          );

          if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
            final Map<String, dynamic> json = jsonDecode(result.stdout.toString().trim());
            return VideoMetadata.fromYtDlpJson(json);
          }
        } catch (e) {
          debugPrint('[YtDlpEngine] Error: $e');
        }
      }
    }

    return await _probeSocialMedia(url);
  }

  Future<VideoMetadata> _probeSocialMedia(String url) async {
    // Prefer a self-hosted yt-dlp extraction backend when the user has
    // configured one (Settings → Extraction Server). It runs the real
    // yt-dlp extractors, which handle Facebook/Instagram/Twitter far more
    // reliably than the on-device regex scraping below — those platforms
    // increasingly serve a login wall to anonymous scraped requests.
    if (BackendExtractionService().isConfigured) {
      final backendResult = await BackendExtractionService().extract(url);
      if (backendResult != null && backendResult.formats.isNotEmpty) {
        return backendResult;
      }
      debugPrint('[YtDlpEngine] Backend extraction returned nothing, falling back to on-device scraping.');
    }

    String title = 'Social Media Video';
    String author = 'Creator';
    String thumbnail = 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=600&auto=format&fit=crop&q=60';
    int duration = 0;
    final cleanUrl = url.trim();

    String? directHdUrl;
    String? directSdUrl;
    String? directAudioUrl;

    // 1. Instagram
    if (cleanUrl.contains('instagram.com') || cleanUrl.contains('instagr.am')) {
      final match = RegExp(r'(?:reel|reels|p|tv)\/([a-zA-Z0-9_-]+)').firstMatch(cleanUrl);
      final code = match?.group(1) ?? 'reel';
      title = 'Instagram Reel ($code)';
      author = 'Instagram Creator';
      thumbnail = 'https://images.unsplash.com/photo-1611162617213-7d7a39e9b1d7?w=600&auto=format&fit=crop&q=60';

      final resolved = await _resolveInstagramStream(cleanUrl);
      if (resolved != null) {
        directHdUrl = resolved;
        directSdUrl = resolved;
      }
    }
    // 2. TikTok
    else if (cleanUrl.contains('tiktok.com')) {
      title = 'TikTok Video';
      author = 'TikTok Creator';
      thumbnail = 'https://images.unsplash.com/photo-1596558450255-7c0b7be9d56a?w=600&auto=format&fit=crop&q=60';

      try {
        final res = await _dio.get('https://www.tiktok.com/oembed?url=${Uri.encodeComponent(cleanUrl)}');
        if (res.statusCode == 200 && res.data is Map) {
          title = res.data['title'] ?? title;
          author = res.data['author_name'] ?? author;
          thumbnail = res.data['thumbnail_url'] ?? thumbnail;
        }
      } catch (e) {
        debugPrint('[YtDlpEngine] Error: $e');
      }

      final tikData = await _resolveTikTokDetails(cleanUrl);
      if (tikData != null) {
        if (tikData['title'] != null && tikData['title']!.isNotEmpty) {
          title = tikData['title']!;
        }
        if (tikData['cover'] != null && tikData['cover']!.isNotEmpty) {
          thumbnail = tikData['cover']!;
        }
        if (tikData['author'] != null && tikData['author']!.isNotEmpty) {
          author = tikData['author']!;
        }
        directHdUrl = tikData['hdplay'] ?? tikData['play'];
        directSdUrl = tikData['play'];
        directAudioUrl = tikData['music'];
      }
    }
    // 3. Facebook
    else if (cleanUrl.contains('facebook.com') || cleanUrl.contains('fb.watch') || cleanUrl.contains('fb.com')) {
      title = 'Facebook Video';
      author = 'Facebook User';
      thumbnail = 'https://images.unsplash.com/photo-1563986768609-322da13575f3?w=600&auto=format&fit=crop&q=60';

      final fbStreams = await _resolveFacebookStreams(cleanUrl);
      if (fbStreams != null) {
        directHdUrl = fbStreams['hd'] ?? fbStreams['sd'];
        directSdUrl = fbStreams['sd'] ?? fbStreams['hd'];
        if (fbStreams['title'] != null) title = fbStreams['title']!;
        if (fbStreams['thumbnail'] != null) thumbnail = fbStreams['thumbnail']!;
      }
    }
    // 4. Twitter / X
    else if (cleanUrl.contains('twitter.com') || cleanUrl.contains('x.com')) {
      title = 'Twitter / X Video';
      author = 'X User';
      thumbnail = 'https://images.unsplash.com/photo-1611605698335-8b1569810432?w=600&auto=format&fit=crop&q=60';

      final xStreams = await _resolveTwitterStreams(cleanUrl);
      if (xStreams != null) {
        directHdUrl = xStreams['hd'] ?? xStreams['sd'];
        directSdUrl = xStreams['sd'] ?? xStreams['hd'];
        directAudioUrl = xStreams['audio'];
        if (xStreams['title'] != null) title = xStreams['title']!;
        if (xStreams['thumbnail'] != null) thumbnail = xStreams['thumbnail']!;
      }
    }
    // 5. Vimeo
    else if (cleanUrl.contains('vimeo.com')) {
      try {
        final res = await _dio.get('https://vimeo.com/api/oembed.json?url=$cleanUrl');
        if (res.statusCode == 200 && res.data is Map) {
          title = res.data['title'] ?? title;
          author = res.data['author_name'] ?? author;
          thumbnail = res.data['thumbnail_url'] ?? thumbnail;
          duration = res.data['duration'] ?? 0;
        }
      } catch (e) {
        debugPrint('[YtDlpEngine] Error: $e');
      }
    }

    final List<DownloadFormat> formats = [];

    if (directHdUrl != null && directHdUrl.isNotEmpty) {
      formats.add(DownloadFormat(
        formatId: 'hd',
        ext: 'mp4',
        resolution: 'HD (Best Quality)',
        note: 'High Definition (MP4)',
        directUrl: directHdUrl,
        hasVideo: true,
        hasAudio: true,
      ));
    } else {
      formats.add(const DownloadFormat(
        formatId: 'hd',
        ext: 'mp4',
        resolution: 'HD (Best Quality)',
        note: 'High Definition (MP4)',
        hasVideo: true,
        hasAudio: true,
      ));
    }

    if (directSdUrl != null && directSdUrl.isNotEmpty && directSdUrl != directHdUrl) {
      formats.add(DownloadFormat(
        formatId: 'sd',
        ext: 'mp4',
        resolution: 'SD (Standard)',
        note: 'Standard Quality (MP4)',
        directUrl: directSdUrl,
        hasVideo: true,
        hasAudio: true,
      ));
    } else if (directHdUrl == null) {
      formats.add(const DownloadFormat(
        formatId: 'sd',
        ext: 'mp4',
        resolution: 'SD (Standard)',
        note: 'Standard Quality (MP4)',
        hasVideo: true,
        hasAudio: true,
      ));
    }

    if (directAudioUrl != null && directAudioUrl.isNotEmpty) {
      formats.add(DownloadFormat(
        formatId: 'audio',
        ext: 'mp3',
        resolution: 'Audio (MP3)',
        note: 'Audio Only (MP3)',
        directUrl: directAudioUrl,
        isAudioOnly: true,
        hasVideo: false,
        hasAudio: true,
        abr: 128,
      ));
    } else {
      formats.add(const DownloadFormat(
        formatId: 'audio',
        ext: 'mp3',
        resolution: 'Audio (MP3)',
        note: 'Audio Only (MP3)',
        isAudioOnly: true,
        hasVideo: false,
        hasAudio: true,
        abr: 128,
      ));
    }

    return VideoMetadata(
      id: 'media_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      uploader: author,
      thumbnail: thumbnail,
      duration: duration,
      webpageUrl: url,
      formats: formats,
    );
  }

  Stream<Map<String, dynamic>> downloadStream({
    required String url,
    required DownloadFormat format,
    required String outputDir,
    String? customFilename,
  }) {
    final ytId = _extractYouTubeId(url);

    if (ytId != null) {
      return _downloadYouTubeNative(
        videoId: ytId,
        format: format,
        outputDir: outputDir,
        customFilename: customFilename,
      );
    }

    // If directUrl is pre-resolved, use direct HTTP downloader immediately
    if (format.directUrl != null && format.directUrl!.isNotEmpty) {
      return _downloadViaDirectHttp(
        url: url,
        format: format,
        outputDir: outputDir,
        customFilename: customFilename,
      );
    }

    if (_canExecuteSubprocesses) {
      return _downloadViaYtDlpProcess(
        url: url,
        format: format,
        outputDir: outputDir,
        customFilename: customFilename,
      );
    }

    return _downloadViaDirectHttp(
      url: url,
      format: format,
      outputDir: outputDir,
      customFilename: customFilename,
    );
  }

  Stream<Map<String, dynamic>> _downloadYouTubeNative({
    required String videoId,
    required DownloadFormat format,
    required String outputDir,
    String? customFilename,
  }) {
    final controller = StreamController<Map<String, dynamic>>();

    () async {
      try {
        final outDir = Directory(outputDir);
        if (!await outDir.exists()) {
          await outDir.create(recursive: true);
        }

        controller.add({
          'type': 'progress',
          'progress': 0.05,
          'percentageStr': '5%',
          'speed': 'Connecting...',
          'eta': '...',
        });

        final yt = YoutubeExplode();
        final video = await yt.videos.get(videoId);
        final manifest = await yt.videos.streamsClient.getManifest(videoId);

        StreamInfo? streamInfo;
        String ext = 'mp4';

        if (format.isAudioOnly) {
          if (manifest.audioOnly.isNotEmpty) {
            streamInfo = manifest.audioOnly.withHighestBitrate();
            ext = streamInfo.container.name == 'mp4' ? 'm4a' : streamInfo.container.name;
          } else if (manifest.muxed.isNotEmpty) {
            streamInfo = manifest.muxed.first;
            ext = 'mp4';
          }
        } else {
          final tagId = int.tryParse(format.formatId);
          if (tagId != null && manifest.streams.any((s) => s.tag == tagId)) {
            streamInfo = manifest.streams.firstWhere((s) => s.tag == tagId);
          } else {
            final cleanRes = format.resolution.replaceAll(RegExp(r'[^0-9]'), '');
            final matching = manifest.muxed.where((s) => s.qualityLabel.contains(cleanRes));
            if (matching.isNotEmpty) {
              streamInfo = matching.first;
            } else if (manifest.muxed.isNotEmpty) {
              streamInfo = manifest.muxed.sortByVideoQuality().last;
            } else if (manifest.videoOnly.isNotEmpty) {
              streamInfo = manifest.videoOnly.sortByVideoQuality().last;
            } else {
              streamInfo = manifest.streams.first;
            }
          }
          ext = streamInfo.container.name;
        }

        if (streamInfo == null) {
          throw Exception('No stream available for selected quality');
        }
        final validStream = streamInfo;

        final title = customFilename ?? video.title;
        final sanitizedTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final targetFilePath = p.join(outputDir, '$sanitizedTitle.$ext');
        final targetFile = File(targetFilePath);

        if (await targetFile.exists()) {
          await targetFile.delete();
        }

        final stream = yt.videos.streamsClient.get(validStream);
        final outputSink = targetFile.openWrite();

        final totalBytes = validStream.size.totalBytes;
        int receivedBytes = 0;
        final startTime = DateTime.now();
        DateTime lastTime = DateTime.now();
        int lastBytes = 0;
        String currentSpeed = '0 KB/s';

        await for (final chunk in stream) {
          outputSink.add(chunk);
          receivedBytes += chunk.length;

          final now = DateTime.now();
          final elapsedSec = now.difference(lastTime).inMilliseconds / 1000.0;

          if (elapsedSec >= 0.4 && totalBytes > 0) {
            final bytesDiff = receivedBytes - lastBytes;
            final speedBps = bytesDiff / (elapsedSec > 0 ? elapsedSec : 1.0);
            if (speedBps > 1024 * 1024) {
              currentSpeed = '${(speedBps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
            } else {
              currentSpeed = '${(speedBps / 1024).toStringAsFixed(0)} KB/s';
            }
            lastBytes = receivedBytes;
            lastTime = now;

            final progress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
            final remainingBytes = totalBytes - receivedBytes;
            final totalElapsed = now.difference(startTime).inSeconds;
            final avgSpeed = totalElapsed > 0 ? receivedBytes / totalElapsed : 1.0;
            final remainingSec = avgSpeed > 0 ? (remainingBytes / avgSpeed).round() : 0;
            final etaStr = '${(remainingSec ~/ 60)}:${(remainingSec % 60).toString().padLeft(2, '0')}';

            final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
            final percentInt = (progress * 100).toInt();

            controller.add({
              'type': 'progress',
              'progress': progress,
              'percentageStr': '$percentInt%',
              'totalSizeStr': '$totalMb MB',
              'speed': currentSpeed,
              'eta': etaStr,
            });
          }
        }

        await outputSink.flush();
        await outputSink.close();
        yt.close();

        controller.add({
          'type': 'completed',
          'filePath': targetFilePath,
        });
        await controller.close();
      } catch (e) {
        try {
          final fallbackStream = _downloadViaDirectHttp(
            url: 'https://www.youtube.com/watch?v=$videoId',
            format: format,
            outputDir: outputDir,
            customFilename: customFilename,
          );
          await for (final event in fallbackStream) {
            controller.add(event);
          }
          await controller.close();
        } catch (fallbackError) {
          controller.add({
            'type': 'error',
            'message': 'Download failed: $e',
          });
          await controller.close();
        }
      }
    }();

    return controller.stream;
  }

  // ==========================================
  // MULTI-ENGINE DIRECT STREAM EXTRACTORS
  // ==========================================

  /// Resolves the stream URL using pre-resolved format directUrl or dedicated platform engines
  Future<String?> _resolveSocialMediaStreamUrl(
    String rawUrl, {
    bool isAudioOnly = false,
    String? formatId,
  }) async {
    final cleanUrl = rawUrl.trim();

    // 1. Direct media links (.mp4, .mp3, etc.)
    if (cleanUrl.endsWith('.mp4') || cleanUrl.endsWith('.mp3') || cleanUrl.endsWith('.m4a') || cleanUrl.endsWith('.webm')) {
      return cleanUrl;
    }

    // 1.5 Self-hosted yt-dlp extraction backend, when configured. Direct
    // CDN URLs from Facebook/Instagram often expire within minutes, so
    // this re-resolves a fresh one at actual download time rather than
    // relying only on the URL cached from the earlier probe step.
    if (BackendExtractionService().isConfigured) {
      final backendUrl = await _resolveViaBackend(cleanUrl, isAudioOnly: isAudioOnly, formatId: formatId);
      if (backendUrl != null) return backendUrl;
    }

    // 2. Facebook
    if (cleanUrl.contains('facebook.com') || cleanUrl.contains('fb.watch') || cleanUrl.contains('fb.com')) {
      final fbStreams = await _resolveFacebookStreams(cleanUrl);
      if (fbStreams != null) {
        if (formatId == 'sd' && fbStreams['sd'] != null) return fbStreams['sd'];
        return fbStreams['hd'] ?? fbStreams['sd'];
      }
    }

    // 3. TikTok
    if (cleanUrl.contains('tiktok.com')) {
      final tikData = await _resolveTikTokDetails(cleanUrl);
      if (tikData != null) {
        if (isAudioOnly && tikData['music'] != null) return tikData['music'];
        if (formatId == 'sd' && tikData['play'] != null) return tikData['play'];
        return tikData['hdplay'] ?? tikData['play'];
      }
    }

    // 4. Twitter / X
    if (cleanUrl.contains('twitter.com') || cleanUrl.contains('x.com')) {
      final xStreams = await _resolveTwitterStreams(cleanUrl);
      if (xStreams != null) {
        if (isAudioOnly && xStreams['audio'] != null) return xStreams['audio'];
        if (formatId == 'sd' && xStreams['sd'] != null) return xStreams['sd'];
        return xStreams['hd'] ?? xStreams['sd'];
      }
    }

    // 5. Instagram
    if (cleanUrl.contains('instagram.com') || cleanUrl.contains('instagr.am')) {
      final instaUrl = await _resolveInstagramStream(cleanUrl);
      if (instaUrl != null && instaUrl.isNotEmpty) return instaUrl;
    }

    // 6. Reddit / Pinterest / Other Media
    final other = await _resolveOtherMediaStream(cleanUrl, isAudioOnly: isAudioOnly);
    if (other != null && other.isNotEmpty) return other;

    // 7. Global Cobalt Fallback (works for many platforms)
    try {
      final cobaltRes = await _dio.post(
        'https://api.cobalt.tools/',
        data: jsonEncode({
          'url': cleanUrl,
          'videoQuality': '720',
          'audioFormat': 'mp3',
          'downloadMode': isAudioOnly ? 'audio' : 'auto',
        }),
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );
      if (cobaltRes.statusCode == 200 && cobaltRes.data is Map) {
        final streamUrl = cobaltRes.data['url']?.toString();
        if (streamUrl != null && streamUrl.isNotEmpty) return streamUrl;
      }
    } catch (e) {
      debugPrint('[YtDlpEngine] Global Cobalt fallback error: $e');
    }

    return null;
  }

  /// Resolves a direct stream URL via the self-hosted extraction backend,
  /// picking the best matching format from its yt-dlp response.
  Future<String?> _resolveViaBackend(String url, {bool isAudioOnly = false, String? formatId}) async {
    final meta = await BackendExtractionService().extract(url);
    if (meta == null || meta.formats.isEmpty) return null;

    if (isAudioOnly) {
      final audioFormats = meta.formats.where((f) => f.isAudioOnly && f.directUrl != null).toList()
        ..sort((a, b) => (b.abr ?? 0).compareTo(a.abr ?? 0));
      if (audioFormats.isNotEmpty) return audioFormats.first.directUrl;
    }

    final videoFormats = meta.formats.where((f) => f.hasVideo && f.directUrl != null).toList();
    if (videoFormats.isEmpty) return null;
    videoFormats.sort((a, b) => _formatHeight(a).compareTo(_formatHeight(b)));
    return formatId == 'sd' ? videoFormats.first.directUrl : videoFormats.last.directUrl;
  }

  int _formatHeight(DownloadFormat f) {
    return int.tryParse(f.resolution.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  /// Facebook Direct & API Stream Extractor
  Future<Map<String, String>?> _resolveFacebookStreams(String url) async {
    // Engine A: Direct Page Scraper (Extracts HD & SD fbcdn video URLs)
    try {
      final res = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
          },
        ),
      );

      final body = res.data.toString();
      String? hdUrl;
      String? sdUrl;
      String? title;
      String? thumbnail;

      final hdMatch = RegExp(r'playable_url_quality_hd["\\]*:\s*["\\]*(https:[^"\\]+)').firstMatch(body) ??
          RegExp(r'browser_native_hd_url["\\]*:\s*["\\]*(https:[^"\\]+)').firstMatch(body) ??
          RegExp(r'hd_src["\\]*:\s*["\\]*(https:[^"\\]+)').firstMatch(body);

      final sdMatch = RegExp(r'playable_url["\\]*:\s*["\\]*(https:[^"\\]+)').firstMatch(body) ??
          RegExp(r'browser_native_sd_url["\\]*:\s*["\\]*(https:[^"\\]+)').firstMatch(body) ??
          RegExp(r'sd_src["\\]*:\s*["\\]*(https:[^"\\]+)').firstMatch(body);

      if (hdMatch != null) {
        hdUrl = _cleanStreamUrl(hdMatch.group(1)!);
      }
      if (sdMatch != null) {
        sdUrl = _cleanStreamUrl(sdMatch.group(1)!);
      }

      // Title & Thumbnail
      final titleMatch = RegExp(r'<title id="pageTitle">([^<]+)<\/title>').firstMatch(body) ??
          RegExp(r'property="og:title"\s+content="([^"]+)"').firstMatch(body);
      if (titleMatch != null) title = titleMatch.group(1);

      final thumbMatch = RegExp(r'property="og:image"\s+content="([^"]+)"').firstMatch(body);
      if (thumbMatch != null) thumbnail = _cleanStreamUrl(thumbMatch.group(1)!);

      // Fallback: search for any fbcdn .mp4
      if (hdUrl == null && sdUrl == null) {
        final allMp4s = RegExp(r'https:[^"\s<>]+\.mp4[^"\s<>]*').allMatches(body);
        for (final m in allMp4s) {
          final candidate = _cleanStreamUrl(m.group(0)!);
          if (candidate.contains('fbcdn.net') && !candidate.contains('.js') && !candidate.contains('.css')) {
            if (candidate.contains('hd') || candidate.contains('1280') || candidate.contains('720')) {
              hdUrl ??= candidate;
            } else {
              sdUrl ??= candidate;
            }
          }
        }
      }

      if (hdUrl != null || sdUrl != null) {
        final map = <String, String>{};
        if (hdUrl != null) map['hd'] = hdUrl;
        if (sdUrl != null) map['sd'] = sdUrl;
        if (title != null) map['title'] = title;
        if (thumbnail != null) map['thumbnail'] = thumbnail;
        return map;
      }
    } catch (e) {
      debugPrint('[YtDlpEngine] Error: $e');
    }

    // Engine B: FDownloader API
    try {
      final fRes = await _dio.post(
        'https://v3.fdownloader.net/api/ajaxSearch',
        data: FormData.fromMap({'q': url, 't': 'media', 'lang': 'en', 'v': 'v2'}),
        options: Options(
          headers: {
            'Origin': 'https://fdownloader.net',
            'Referer': 'https://fdownloader.net/',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          },
        ),
      );
      if (fRes.statusCode == 200 && fRes.data is Map) {
        final html = fRes.data['data']?.toString() ?? '';
        final hrefs = RegExp(r'href="(https:\/\/[^"]+(?:fbcdn|video)[^"]*)"').allMatches(html);
        if (hrefs.isNotEmpty) {
          return {'hd': hrefs.first.group(1)!, 'sd': hrefs.last.group(1)!};
        }
      }
    } catch (e) {
      debugPrint('[YtDlpEngine] Error: $e');
    }

    return null;
  }

  /// TikTok Details & Stream Extractor
  Future<Map<String, String>?> _resolveTikTokDetails(String url) async {
    // Engine A: TikWM API (most reliable)
    try {
      final res = await _dio.post(
        'https://www.tikwm.com/api/',
        data: FormData.fromMap({'url': url, 'hd': 1}),
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          },
        ),
      );

      final dynamic data = res.data is String ? jsonDecode(res.data) : res.data;
      if (data is Map && data['data'] != null) {
        final d = data['data'];
        String? play = d['play']?.toString();
        String? hdplay = d['hdplay']?.toString();
        String? music = d['music']?.toString();

        if (play != null && play.startsWith('/')) play = 'https://www.tikwm.com$play';
        if (hdplay != null && hdplay.startsWith('/')) hdplay = 'https://www.tikwm.com$hdplay';
        if (music != null && music.startsWith('/')) music = 'https://www.tikwm.com$music';

        if (play != null && play.isNotEmpty) {
          final resMap = <String, String>{'play': play};
          if (hdplay != null && hdplay.isNotEmpty) resMap['hdplay'] = hdplay;
          if (music != null && music.isNotEmpty) resMap['music'] = music;
          return resMap;
        }
      }
    } catch (e) {
      debugPrint('[YtDlpEngine] TikWM error: $e');
    }

    // Engine B: Cobalt API
    try {
      final cobaltRes = await _dio.post(
        'https://api.cobalt.tools/',
        data: jsonEncode({
          'url': url,
          'videoQuality': '720',
          'downloadMode': 'auto',
        }),
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );
      if (cobaltRes.statusCode == 200 && cobaltRes.data is Map) {
        final streamUrl = cobaltRes.data['url']?.toString();
        if (streamUrl != null && streamUrl.isNotEmpty) {
          return {'play': streamUrl, 'hdplay': streamUrl};
        }
      }
    } catch (e) {
      debugPrint('[YtDlpEngine] Cobalt TikTok error: $e');
    }

    // Engine C: TikMate API
    try {
      final res = await _dio.post(
        'https://api.tikmate.app/api/lookup',
        data: FormData.fromMap({'url': url}),
        options: Options(headers: {'Origin': 'https://tikmate.app', 'Referer': 'https://tikmate.app/'}),
      );
      if (res.statusCode == 200 && res.data is Map) {
        final token = res.data['token'];
        final id = res.data['id'];
        if (token != null && id != null) {
          final streamUrl = 'https://tikmate.app/download/$token/$id.mp4?hd=1';
          return {'play': streamUrl, 'hdplay': streamUrl};
        }
      }
    } catch (e) {
      debugPrint('[YtDlpEngine] TikMate error: $e');
    }

    return null;
  }

  /// Twitter / X Stream Extractor
  Future<Map<String, String>?> _resolveTwitterStreams(String url) async {
    // Engine A: VxTwitter / FxTwitter API (most reliable)
    try {
      final match = RegExp(r'(?:twitter\.com|x\.com)\/(?:#!\/)?(\w+)\/status(?:es)?\/(\d+)').firstMatch(url);
      final user = match?.group(1) ?? 'i';
      final id = match?.group(2);
      if (id != null) {
        // Try FxTwitter first (better quality)
        try {
          final fx = await _dio.get(
            'https://fxtwitter.com/$user/status/$id',
            options: Options(
              headers: {
                'User-Agent': 'Mozilla/5.0 (compatible; bot/1.0)',
                'Accept': 'application/json',
              },
            ),
          );
          if (fx.statusCode == 200 && fx.data is Map) {
            final tweet = fx.data['tweet'];
            if (tweet != null && tweet['media'] != null) {
              final videos = tweet['media']['videos'] as List?;
              if (videos != null && videos.isNotEmpty) {
                final video = videos.first;
                final urlStr = video['url']?.toString();
                if (urlStr != null && urlStr.isNotEmpty) {
                  return {
                    'hd': urlStr,
                    'sd': urlStr,
                    if (tweet['text'] != null) 'title': tweet['text'].toString(),
                  };
                }
              }
            }
          }
        } catch (_) {}

        // Try VxTwitter
        try {
          final vx = await _dio.get(
            'https://api.vxtwitter.com/$user/status/$id',
            options: Options(
              headers: {'User-Agent': 'Mozilla/5.0'},
            ),
          );
          if (vx.statusCode == 200 && vx.data is Map) {
            final mediaUrls = vx.data['media_URLs'] as List?;
            if (mediaUrls != null && mediaUrls.isNotEmpty) {
              final videoUrl = mediaUrls.first.toString();
              return {
                'hd': videoUrl,
                'sd': videoUrl,
                if (vx.data['text'] != null) 'title': vx.data['text'].toString(),
              };
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[YtDlpEngine] Twitter API error: $e');
    }

    // Engine B: Cobalt API
    try {
      final cobaltRes = await _dio.post(
        'https://api.cobalt.tools/',
        data: jsonEncode({
          'url': url,
          'videoQuality': '720',
          'downloadMode': 'auto',
        }),
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );
      if (cobaltRes.statusCode == 200 && cobaltRes.data is Map) {
        final streamUrl = cobaltRes.data['url']?.toString();
        if (streamUrl != null && streamUrl.isNotEmpty) {
          return {'hd': streamUrl, 'sd': streamUrl};
        }
      }
    } catch (e) {
      debugPrint('[YtDlpEngine] Cobalt Twitter error: $e');
    }

    // Engine C: TwDown Scraper
    try {
      final res = await _dio.post(
        'https://twdown.net/download.php',
        data: FormData.fromMap({'URL': url}),
        options: Options(
          validateStatus: (s) => s != null && s < 400,
          headers: {
            'Origin': 'https://twdown.net',
            'Referer': 'https://twdown.net/',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          },
        ),
      );

      String body = res.data.toString();
      final streamMatches = RegExp(r'href="(https:\/\/[^"]*(?:video\.twimg\.com|twdown\.net)[^"]*)"').allMatches(body);
      final List<String> foundUrls = [];
      for (final m in streamMatches) {
        final link = m.group(1)!;
        if (!link.contains('.css') && !link.contains('.js')) {
          foundUrls.add(link);
        }
      }

      if (foundUrls.isNotEmpty) {
        return {
          'hd': foundUrls.first,
          'sd': foundUrls.last,
        };
      }
    } catch (e) {
      debugPrint('[YtDlpEngine] TwDown error: $e');
    }

    return null;
  }

  /// Instagram Direct & Embed Stream Extractor
  Future<String?> _resolveInstagramStream(String url) async {
    final match = RegExp(r'(?:reel|reels|p|tv|stories)\/([a-zA-Z0-9_-]+)').firstMatch(url);
    final shortcode = match?.group(1);

    // Engine A: Instagram Embed Scraper
    if (shortcode != null) {
      final embedEndpoints = [
        'https://www.instagram.com/reel/$shortcode/embed/captioned/',
        'https://www.instagram.com/p/$shortcode/embed/captioned/',
        'https://www.instagram.com/reel/$shortcode/embed/',
        'https://www.instagram.com/p/$shortcode/embed/',
      ];

      for (final endpoint in embedEndpoints) {
        try {
          final res = await _dio.get(
            endpoint,
            options: Options(
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              },
            ),
          );

          final body = res.data.toString();
          
          // Try multiple patterns to find video URL
          final videoMatch = RegExp(r'video_url["\\]*:\s*["\\]*(https:[^"\\]+)').firstMatch(body) ??
              RegExp(r'playable_url["\\]*:\s*["\\]*(https:[^"\\]+)').firstMatch(body) ??
              RegExp(r'<video[^>]+src="([^"]+)"').firstMatch(body) ??
              RegExp(r'"video_url"\s*:\s*"(https[^"]+)"').firstMatch(body);

          if (videoMatch != null) {
            final stream = _cleanStreamUrl(videoMatch.group(1)!);
            if (stream.isNotEmpty && (stream.contains('cdninstagram.com') || stream.contains('fbcdn.net') || stream.contains('instagram'))) {
              return stream;
            }
          }

          // Search for any cdninstagram or fbcdn .mp4
          final allMp4s = RegExp(r'https:[^"\s<>\\]+\.mp4[^"\s<>\\]*').allMatches(body);
          for (final m in allMp4s) {
            final cleaned = _cleanStreamUrl(m.group(0)!);
            if (cleaned.contains('cdninstagram.com') || cleaned.contains('fbcdn.net')) {
              return cleaned;
            }
          }
        } catch (e) {
          debugPrint('[YtDlpEngine] Instagram embed error: $e');
        }
      }
    }

    // Engine B: Cobalt API (more reliable)
    try {
      final cobaltRes = await _dio.post(
        'https://api.cobalt.tools/',
        data: jsonEncode({
          'url': url,
          'videoQuality': '720',
          'downloadMode': 'auto',
        }),
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );
      if (cobaltRes.statusCode == 200 && cobaltRes.data is Map) {
        final streamUrl = cobaltRes.data['url']?.toString();
        if (streamUrl != null && streamUrl.isNotEmpty) return streamUrl;
      }
    } catch (e) {
      debugPrint('[YtDlpEngine] Cobalt error: $e');
    }

    // Engine C: SaveFrom style API
    try {
      final res = await _dio.post(
        'https://snapinsta.app/api/ajaxSearch',
        data: FormData.fromMap({'url': url, 'lang': 'en'}),
        options: Options(
          headers: {
            'Origin': 'https://snapinsta.app',
            'Referer': 'https://snapinsta.app/',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        ),
      );
      if (res.statusCode == 200 && res.data is Map) {
        final html = res.data['data']?.toString() ?? '';
        final hrefs = RegExp(r'href="(https:\/\/[^"]+(?:cdninstagram|fbcdn|download)[^"]*)"').allMatches(html);
        if (hrefs.isNotEmpty) {
          return hrefs.first.group(1)!;
        }
        // Also check for data-url
        final dataUrl = RegExp(r'data-url="(https:\/\/[^"]+)"').firstMatch(html);
        if (dataUrl != null) return dataUrl.group(1)!;
      }
    } catch (e) {
      debugPrint('[YtDlpEngine] SnapInsta error: $e');
    }

    return null;
  }

  /// Reddit, Pinterest, Threads & Other Media Extractor
  Future<String?> _resolveOtherMediaStream(String url, {bool isAudioOnly = false}) async {
    // Reddit
    if (url.contains('reddit.com') || url.contains('redd.it')) {
      try {
        final clean = url.split('?').first.replaceAll(RegExp(r'\/$'), '');
        final res = await _dio.get('$clean.json');
        if (res.statusCode == 200 && res.data is List && (res.data as List).isNotEmpty) {
          final postData = res.data[0]['data']['children'][0]['data'];
          final secureMedia = postData['secure_media'] ?? postData['media'];
          if (secureMedia != null && secureMedia['reddit_video'] != null) {
            final fallback = secureMedia['reddit_video']['fallback_url']?.toString();
            if (fallback != null) return fallback;
          }
        }
      } catch (e) {
        debugPrint('[YtDlpEngine] Error: $e');
      }
    }

    // Pinterest
    if (url.contains('pinterest.com') || url.contains('pin.it')) {
      try {
        final res = await _dio.get(url, options: Options(headers: {'User-Agent': 'Mozilla/5.0'}));
        final body = res.data.toString();
        final videoMatch = RegExp(r'https:\/\/[^"\s<>]+\.(?:pinimg\.com|pinterest\.com)[^"\s<>]+\.mp4[^"\s<>]*').firstMatch(body);
        if (videoMatch != null) return _cleanStreamUrl(videoMatch.group(0)!);
      } catch (e) {
        debugPrint('[YtDlpEngine] Error: $e');
      }
    }

    // Threads
    if (url.contains('threads.net')) {
      return await _resolveInstagramStream(url);
    }

    return null;
  }

  String _cleanStreamUrl(String raw) {
    return raw
        .replaceAll(r'\/', '/')
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\u0025', '%')
        .replaceAll(r'\\', '')
        .replaceAll('&amp;', '&');
  }

  Stream<Map<String, dynamic>> _downloadViaDirectHttp({
    required String url,
    required DownloadFormat format,
    required String outputDir,
    String? customFilename,
  }) {
    final controller = StreamController<Map<String, dynamic>>();

    () async {
      try {
        final outDir = Directory(outputDir);
        if (!await outDir.exists()) {
          await outDir.create(recursive: true);
        }

        final ext = format.isAudioOnly ? (format.ext.isNotEmpty ? format.ext : 'mp3') : 'mp4';
        final sanitizedTitle = (customFilename ?? 'media_${DateTime.now().millisecondsSinceEpoch}')
            .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final targetFilePath = p.join(outputDir, '$sanitizedTitle.$ext');

        controller.add({
          'type': 'progress',
          'progress': 0.05,
          'percentageStr': '5%',
          'speed': 'Connecting...',
          'eta': '...',
        });

        // 1. Check if directUrl is already populated
        String? directStreamUrl = format.directUrl;

        // 2. Otherwise resolve directly
        if (directStreamUrl == null || directStreamUrl.isEmpty) {
          directStreamUrl = await _resolveSocialMediaStreamUrl(
            url,
            isAudioOnly: format.isAudioOnly,
            formatId: format.formatId,
          );
        }

        if (directStreamUrl == null || directStreamUrl.isEmpty) {
          controller.add({
            'type': 'error',
            'message': 'Could not extract direct stream URL for this link. Please verify the link is public.',
          });
          await controller.close();
          return;
        }

        final startTime = DateTime.now();
        int lastBytes = 0;
        DateTime lastTime = DateTime.now();
        String currentSpeed = '0 KB/s';

        await _dio.download(
          directStreamUrl,
          targetFilePath,
          options: Options(
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
              'Accept': '*/*',
              'Referer': url,
            },
          ),
          onReceiveProgress: (received, total) {
            if (total > 0) {
              final now = DateTime.now();
              final elapsedSec = now.difference(lastTime).inMilliseconds / 1000.0;

              if (elapsedSec >= 0.4) {
                final bytesDiff = received - lastBytes;
                final speedBps = bytesDiff / (elapsedSec > 0 ? elapsedSec : 1.0);
                if (speedBps > 1024 * 1024) {
                  currentSpeed = '${(speedBps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
                } else {
                  currentSpeed = '${(speedBps / 1024).toStringAsFixed(0)} KB/s';
                }
                lastBytes = received;
                lastTime = now;
              }

              final progress = (received / total).clamp(0.0, 1.0);
              final remainingBytes = total - received;
              final totalElapsed = now.difference(startTime).inSeconds;
              final avgSpeed = totalElapsed > 0 ? received / totalElapsed : 1.0;
              final remainingSec = avgSpeed > 0 ? (remainingBytes / avgSpeed).round() : 0;
              final etaStr = '${(remainingSec ~/ 60)}:${(remainingSec % 60).toString().padLeft(2, '0')}';

              final totalMb = (total / (1024 * 1024)).toStringAsFixed(1);
              final percentInt = (progress * 100).toInt();

              controller.add({
                'type': 'progress',
                'progress': progress,
                'percentageStr': '$percentInt%',
                'totalSizeStr': '$totalMb MB',
                'speed': currentSpeed,
                'eta': etaStr,
              });
            } else {
              // Unknown total length chunked download
              final now = DateTime.now();
              final elapsedSec = now.difference(lastTime).inMilliseconds / 1000.0;
              if (elapsedSec >= 0.5) {
                final bytesDiff = received - lastBytes;
                final speedBps = bytesDiff / (elapsedSec > 0 ? elapsedSec : 1.0);
                if (speedBps > 1024 * 1024) {
                  currentSpeed = '${(speedBps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
                } else {
                  currentSpeed = '${(speedBps / 1024).toStringAsFixed(0)} KB/s';
                }
                lastBytes = received;
                lastTime = now;

                final receivedMb = (received / (1024 * 1024)).toStringAsFixed(1);
                controller.add({
                  'type': 'progress',
                  'progress': 0.5,
                  'percentageStr': '$receivedMb MB',
                  'totalSizeStr': '$receivedMb MB',
                  'speed': currentSpeed,
                  'eta': '...',
                });
              }
            }
          },
        );

        controller.add({
          'type': 'completed',
          'filePath': targetFilePath,
        });
        await controller.close();
      } catch (e) {
        controller.add({
          'type': 'error',
          'message': 'Download failed: $e',
        });
        await controller.close();
      }
    }();

    return controller.stream;
  }

  Stream<Map<String, dynamic>> _downloadViaYtDlpProcess({
    required String url,
    required DownloadFormat format,
    required String outputDir,
    String? customFilename,
  }) async* {
    final bin = await getBinaryPath();
    if (bin == null) {
      yield* _downloadViaDirectHttp(
        url: url,
        format: format,
        outputDir: outputDir,
        customFilename: customFilename,
      );
      return;
    }

    final outDir = Directory(outputDir);
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    final outTemplate = p.join(
      outputDir,
      customFilename != null ? '$customFilename.%(ext)s' : '%(title)s [%(id)s].%(ext)s',
    );

    List<String> args = [
      '--newline',
      '--no-playlist',
      '--progress',
      '-o',
      outTemplate,
    ];

    if (format.isAudioOnly) {
      args.addAll([
        '-x',
        '--audio-format',
        format.ext.isNotEmpty ? format.ext : 'mp3',
        '--audio-quality',
        '0',
        url,
      ]);
    } else {
      // Validate if formatId is numeric yt-dlp format tag
      final isNumericTag = RegExp(r'^\d+$').hasMatch(format.formatId);
      if (isNumericTag) {
        args.addAll([
          '-f',
          '${format.formatId}+bestaudio/best',
          '--merge-output-format',
          'mp4',
          url,
        ]);
      } else {
        args.addAll(['-f', 'bestvideo+bestaudio/best', '--merge-output-format', 'mp4', url]);
      }
    }

    Process? process;
    try {
      process = await Process.start(bin, args);
    } catch (e) {
      yield* _downloadViaDirectHttp(
        url: url,
        format: format,
        outputDir: outputDir,
        customFilename: customFilename,
      );
      return;
    }

    final linesStream = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    String finalFilePath = '';

    await for (final line in linesStream) {
      final parsed = _parseYtDlpOutput(line);
      if (parsed != null) {
        if (parsed.containsKey('destination')) {
          finalFilePath = parsed['destination'];
        }
        yield {'type': 'progress', ...parsed};
      }
    }

    final exitCode = await process.exitCode;
    if (exitCode == 0) {
      yield {
        'type': 'completed',
        'filePath': finalFilePath.isNotEmpty ? finalFilePath : outputDir,
      };
    } else {
      // If yt-dlp fails on Desktop, fallback seamlessly to direct HTTP extractor
      yield* _downloadViaDirectHttp(
        url: url,
        format: format,
        outputDir: outputDir,
        customFilename: customFilename,
      );
    }
  }

  Map<String, dynamic>? _parseYtDlpOutput(String line) {
    final downloadMatch = RegExp(
      r'\[download\]\s+([\d\.]+)%\s+of\s+~?([\d\.]+\w+)\s+at\s+([\d\.]+\w+\/s)\s+ETA\s+([\d:]+)',
    ).firstMatch(line);

    if (downloadMatch != null) {
      final percentStr = downloadMatch.group(1) ?? '0';
      final percent = (double.tryParse(percentStr) ?? 0.0) / 100.0;
      final totalSize = downloadMatch.group(2) ?? '';
      final speed = downloadMatch.group(3) ?? '';
      final eta = downloadMatch.group(4) ?? '';

      return {
        'progress': percent,
        'percentageStr': '$percentStr%',
        'totalSizeStr': totalSize,
        'speed': speed,
        'eta': eta,
      };
    }

    if (line.contains('Destination: ')) {
      final path = line.split('Destination: ').last.trim();
      return {'destination': path};
    }

    if (line.contains('Merging formats into "')) {
      final match = RegExp(r'Merging formats into "(.*?)"').firstMatch(line);
      if (match != null) {
        return {'destination': match.group(1)};
      }
    }

    return null;
  }

  String? _extractYouTubeId(String url) {
    if (url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(trimmed)) return trimmed;
    final shortMatch = RegExp(r'youtu\.be\/([a-zA-Z0-9_-]{11})').firstMatch(trimmed);
    if (shortMatch != null) return shortMatch.group(1);
    final watchMatch = RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})').firstMatch(trimmed);
    if (watchMatch != null) return watchMatch.group(1);
    final shortsMatch = RegExp(r'youtube\.com\/shorts\/([a-zA-Z0-9_-]{11})').firstMatch(trimmed);
    if (shortsMatch != null) return shortsMatch.group(1);
    final liveMatch = RegExp(r'youtube\.com\/live\/([a-zA-Z0-9_-]{11})').firstMatch(trimmed);
    if (liveMatch != null) return liveMatch.group(1);
    final embedMatch = RegExp(r'youtube\.com\/embed\/([a-zA-Z0-9_-]{11})').firstMatch(trimmed);
    if (embedMatch != null) return embedMatch.group(1);
    return null;
  }
}
