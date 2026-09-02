import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/video_metadata.dart';

/// Talks to an optional, self-hosted yt-dlp extraction server (see
/// `/backend` in this repo).
///
/// Why this exists: on Android/iOS the app cannot run the yt-dlp binary
/// locally (no subprocess execution), so links from Facebook, Instagram
/// and Twitter/X were falling back to fragile on-device HTML scraping and
/// free third-party mirror APIs — several of which are unreliable or now
/// require paid API keys. This service lets mobile builds get the same
/// real yt-dlp extraction that the desktop build gets, over HTTP, for the
/// price of running one small free-tier server.
///
/// It is entirely optional: if the user hasn't configured a server URL in
/// Settings, every method here is a no-op and the app falls back to its
/// existing scraping logic unchanged.
class BackendExtractionService {
  static final BackendExtractionService _instance = BackendExtractionService._internal();
  factory BackendExtractionService() => _instance;
  BackendExtractionService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    // Free-tier hosts (Render/Fly.io) can take 20-50s to wake up from a
    // cold start, so this is generous on purpose.
    receiveTimeout: const Duration(seconds: 55),
  ));

  String? get baseUrl {
    final raw = SecureStorageService().getString(AppConstants.extractionBackendUrlKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim().replaceAll(RegExp(r'\/+$'), '');
  }

  String? get apiKey {
    final raw = SecureStorageService().getString(AppConstants.extractionBackendApiKeyKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  bool get isConfigured => baseUrl != null;

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    final key = apiKey;
    if (key != null) headers['x-api-key'] = key;
    return headers;
  }

  /// Runs `yt-dlp --dump-json` on the server for [url] and parses the
  /// result the same way the desktop build parses its local binary output.
  Future<VideoMetadata?> extract(String url) async {
    final base = baseUrl;
    if (base == null) return null;

    try {
      final res = await _dio.post(
        '$base/extract',
        data: jsonEncode({'url': url}),
        options: Options(headers: _headers, validateStatus: (s) => s != null && s < 500),
      );

      if (res.statusCode == 200) {
        final json = res.data is String ? jsonDecode(res.data) : res.data;
        if (json is Map<String, dynamic>) {
          return VideoMetadata.fromYtDlpJson(json);
        }
      } else {
        debugPrint('[BackendExtraction] Server responded ${res.statusCode}: ${res.data}');
      }
    } catch (e) {
      debugPrint('[BackendExtraction] Error: $e');
    }
    return null;
  }

  /// Pings the server's health endpoint. Used by the Settings screen to
  /// confirm the URL the user typed actually works before saving it.
  Future<bool> checkHealth() async {
    final base = baseUrl;
    if (base == null) return false;
    try {
      final res = await _dio.get(
        '$base/health',
        options: Options(
          headers: _headers,
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 55),
        ),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[BackendExtraction] Health check failed: $e');
      return false;
    }
  }
}
