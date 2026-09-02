import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/youtube_channel.dart';
import '../models/youtube_video.dart';

class YouTubeApiService {
  static final YouTubeApiService _instance = YouTubeApiService._internal();
  factory YouTubeApiService() => _instance;
  YouTubeApiService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  VideoSearchList? _activeSearchList;
  YoutubeExplode? _activeYt;

  Future<String?> _getApiKey() async {
    final customKey = await SecureStorageService().getApiKey();
    if (customKey != null && customKey.isNotEmpty) {
      return customKey;
    }
    if (AppConstants.defaultYouTubeApiKey.isNotEmpty) {
      return AppConstants.defaultYouTubeApiKey;
    }
    return null;
  }

  /// Search videos & channels with sorting (relevance, date, viewCount)
  Future<({List<YouTubeVideo> videos, YouTubeChannel? channel, String? nextPageToken, bool hasMore})> searchVideos({
    required String query,
    String? pageToken,
    String? categoryId,
    String sortBy = 'relevance', // 'relevance', 'date', 'viewCount'
    int maxResults = 25,
  }) async {
    _activeSearchList = null;
    final apiKey = await _getApiKey();
    YouTubeChannel? matchedChannel;

    // 1. Try Official YouTube Data API v3
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final apiOrder = sortBy == 'date'
            ? 'date'
            : (sortBy == 'viewCount' ? 'viewCount' : 'relevance');

        // A. Search for matching Channel if pageToken is empty
        if (pageToken == null || pageToken.isEmpty) {
          try {
            final channelRes = await _dio.get(
              '${AppConstants.ytBaseApiUrl}/search',
              queryParameters: {
                'part': 'snippet',
                'q': query,
                'type': 'channel',
                'maxResults': 1,
                'key': apiKey,
              },
            );
            if (channelRes.statusCode == 200 && channelRes.data != null) {
              final items = channelRes.data['items'] as List? ?? [];
              if (items.isNotEmpty) {
                final chId = items[0]['id']?['channelId']?.toString() ?? '';
                if (chId.isNotEmpty) {
                  final details = await _fetchChannelDetails(chId, apiKey);
                  if (details != null) {
                    matchedChannel = details;
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('[YouTubeApiService] Error: $e');
          }
        }

        // B. Search for Videos
        final Map<String, dynamic> queryParams = {
          'part': 'snippet',
          'q': query,
          'type': 'video',
          'order': apiOrder,
          'maxResults': maxResults,
          'key': apiKey,
        };
        if (pageToken != null && pageToken.isNotEmpty) {
          queryParams['pageToken'] = pageToken;
        }
        if (categoryId != null && categoryId.isNotEmpty) {
          queryParams['videoCategoryId'] = categoryId;
        }

        final response = await _dio.get(
          '${AppConstants.ytBaseApiUrl}/search',
          queryParameters: queryParams,
        );

        if (response.statusCode == 200 && response.data != null) {
          final items = response.data['items'] as List? ?? [];
          final nextToken = response.data['nextPageToken'] as String?;

          final videoIds = items
              .map((it) => it['id']?['videoId']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toList();

          Map<String, dynamic> detailsMap = {};
          if (videoIds.isNotEmpty) {
            detailsMap = await _fetchVideosDetails(videoIds, apiKey);
          }

          final List<YouTubeVideo> result = [];
          for (final item in items) {
            final id = item['id']?['videoId']?.toString() ?? '';
            if (id.isEmpty) continue;
            final details = detailsMap[id];
            result.add(YouTubeVideo.fromApiJson(item, detailsJson: details));
          }

          if (result.isNotEmpty) {
            return (videos: result, channel: matchedChannel, nextPageToken: nextToken, hasMore: nextToken != null);
          }
      }
    } catch (e) {
      debugPrint('[YouTubeApiService] Error: $e');
    }
    }

    // 2. Native Client-Side YouTube Search via YoutubeExplode
    try {
      _activeYt?.close();
      _activeYt = YoutubeExplode();

      // Search for channel match if query resembles channel search
      if (pageToken == null || pageToken.isEmpty) {
        try {
          final contentSearch = await _activeYt!.search.searchContent(query);
          for (final item in contentSearch) {
            if (item is SearchChannel) {
              matchedChannel = YouTubeChannel(
                id: item.id.value,
                title: item.name,
                description: item.description,
                avatarUrl: '',
                videoCount: item.videoCount,
              );
              break;
            }
          }
          } catch (e) {
            debugPrint('[YouTubeApiService] Error: $e');
          }
        }

        final searchList = await _activeYt!.search.search(query);
      _activeSearchList = searchList;

      if (searchList.isNotEmpty) {
        List<YouTubeVideo> videos = searchList.map((v) => _mapSearchVideo(v)).toList();

        // Sort videos according to selected filter
        if (sortBy == 'date') {
          videos.sort((a, b) {
            if (a.publishedAt == null && b.publishedAt == null) return 0;
            if (a.publishedAt == null) return 1;
            if (b.publishedAt == null) return -1;
            return b.publishedAt!.compareTo(a.publishedAt!);
          });
        } else if (sortBy == 'viewCount') {
          videos.sort((a, b) => b.viewCount.compareTo(a.viewCount));
        }

        return (videos: videos, channel: matchedChannel, nextPageToken: 'native_page_1', hasMore: true);
      }
    } catch (e) {
      debugPrint('[YouTubeApiService] Error: $e');
    }

    // 3. Fallback mirror search
    final mirror = await _fetchPublicSearchResults(query: query, pageToken: pageToken);
    return (videos: mirror.videos, channel: null, nextPageToken: mirror.nextPageToken, hasMore: false);
  }

  /// Load more items from active search session (Infinite scroll)
  Future<({List<YouTubeVideo> videos, String? nextPageToken, bool hasMore})> loadMoreSearchResults({
    String? query,
    String? nextPageToken,
    String sortBy = 'relevance',
  }) async {
    // A. If active YoutubeExplode search list exists, fetch next page
    if (_activeSearchList != null) {
      try {
        final nextBatch = await _activeSearchList!.nextPage();
        if (nextBatch != null && nextBatch.isNotEmpty) {
          _activeSearchList = nextBatch;
          List<YouTubeVideo> more = nextBatch.map((v) => _mapSearchVideo(v)).toList();
          if (sortBy == 'date') {
            more.sort((a, b) {
              if (a.publishedAt == null && b.publishedAt == null) return 0;
              if (a.publishedAt == null) return 1;
              if (b.publishedAt == null) return -1;
              return b.publishedAt!.compareTo(a.publishedAt!);
            });
          } else if (sortBy == 'viewCount') {
            more.sort((a, b) => b.viewCount.compareTo(a.viewCount));
          }
          return (videos: more, nextPageToken: 'native_page', hasMore: true);
        }
      } catch (e) {
        debugPrint('[YouTubeApiService] Error: $e');
      }
    }

    // B. If using YouTube Data API pageToken
    if (query != null && nextPageToken != null && nextPageToken != 'native_page_1') {
      final res = await searchVideos(query: query, pageToken: nextPageToken, sortBy: sortBy);
      return (videos: res.videos, nextPageToken: res.nextPageToken, hasMore: res.hasMore);
    }

    return (videos: <YouTubeVideo>[], nextPageToken: null, hasMore: false);
  }

  /// Fetch videos uploaded by a specific channel
  Future<List<YouTubeVideo>> fetchChannelVideos(String channelId) async {
    try {
      final yt = YoutubeExplode();
      final uploads = await yt.channels.getUploads(ChannelId(channelId)).take(30).toList();
      yt.close();

      if (uploads.isNotEmpty) {
        return uploads.map((v) => _mapSearchVideo(v)).toList();
      }
    } catch (e) {
      debugPrint('[YouTubeApiService] Error: $e');
    }

    return [];
  }

  Future<YouTubeChannel?> _fetchChannelDetails(String channelId, String apiKey) async {
    try {
      final res = await _dio.get(
        '${AppConstants.ytBaseApiUrl}/channels',
        queryParameters: {
          'part': 'snippet,statistics',
          'id': channelId,
          'key': apiKey,
        },
      );
      if (res.statusCode == 200 && res.data != null) {
        final items = res.data['items'] as List? ?? [];
        if (items.isNotEmpty) {
          return YouTubeChannel.fromApiJson(items[0]);
        }
      }
    } catch (e) {
      debugPrint('[YouTubeApiService] Error: $e');
    }
    return null;
  }

  YouTubeVideo _mapSearchVideo(dynamic v) {
    if (v is Video) {
      final dur = v.duration;
      final durationStr = dur != null
          ? '${dur.inMinutes}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}'
          : '';

      return YouTubeVideo(
        id: v.id.value,
        title: v.title,
        description: v.description,
        thumbnailUrl: v.thumbnails.highResUrl,
        channelTitle: v.author,
        channelId: v.channelId.value,
        viewCount: v.engagement.viewCount,
        duration: durationStr,
        publishedAt: v.uploadDate,
      );
    }

    return YouTubeVideo(
      id: v.id?.toString() ?? '',
      title: v.title?.toString() ?? '',
      description: v.description?.toString() ?? '',
      thumbnailUrl: v.thumbnails?.highResUrl?.toString() ?? 'https://i.ytimg.com/vi/${v.id}/hqdefault.jpg',
      channelTitle: v.author?.toString() ?? '',
      channelId: '',
      viewCount: 0,
      duration: '',
      publishedAt: null,
    );
  }

  /// Fetch Trending / Explore videos
  Future<List<YouTubeVideo>> fetchTrendingVideos({String? categoryId}) async {
    final apiKey = await _getApiKey();

    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final Map<String, dynamic> queryParams = {
          'part': 'snippet,contentDetails,statistics',
          'chart': 'mostPopular',
          'maxResults': 30,
          'key': apiKey,
        };
        if (categoryId != null && categoryId.isNotEmpty) {
          queryParams['videoCategoryId'] = categoryId;
        }

        final response = await _dio.get(
          '${AppConstants.ytBaseApiUrl}/videos',
          queryParameters: queryParams,
        );

        if (response.statusCode == 200 && response.data != null) {
          final items = response.data['items'] as List? ?? [];
          final list = items.map((item) => YouTubeVideo.fromApiJson(item)).toList();
          if (list.isNotEmpty) return list;
        }
      } catch (e) {
        debugPrint('[YouTubeApiService] Error: $e');
      }
    }

    // Native fallback search for trending
    try {
      final yt = YoutubeExplode();
      final searchList = await yt.search.search('trending videos');
      yt.close();

      if (searchList.isNotEmpty) {
        return searchList.take(30).map((v) => _mapSearchVideo(v)).toList();
      }
    } catch (e) {
      debugPrint('[YouTubeApiService] Error: $e');
    }

    return _getFallbackTrendingVideos();
  }

  /// Fetch Related videos
  Future<List<YouTubeVideo>> fetchRelatedVideos(String videoId) async {
    try {
      final yt = YoutubeExplode();
      final videoObj = await yt.videos.get(videoId);
      final related = await yt.videos.getRelatedVideos(videoObj);
      yt.close();

      if (related != null && related.isNotEmpty) {
        return related.take(20).map((v) {
          final dur = v.duration;
          final durationStr = dur != null
              ? '${dur.inMinutes}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}'
              : '';

          return YouTubeVideo(
            id: v.id.value,
            title: v.title,
            description: '',
            thumbnailUrl: v.thumbnails.highResUrl,
            channelTitle: v.author,
            channelId: v.channelId.value,
            viewCount: 0,
            duration: durationStr,
            publishedAt: null,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[YouTubeApiService] Error: $e');
    }

    return _getCuratedMockVideos();
  }

  Future<Map<String, dynamic>> _fetchVideosDetails(List<String> ids, String apiKey) async {
    try {
      final response = await _dio.get(
        '${AppConstants.ytBaseApiUrl}/videos',
        queryParameters: {
          'part': 'contentDetails,statistics',
          'id': ids.join(','),
          'key': apiKey,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final items = response.data['items'] as List? ?? [];
        final Map<String, dynamic> result = {};
        for (final item in items) {
          final id = item['id']?.toString() ?? '';
          if (id.isNotEmpty) result[id] = item;
        }
        return result;
      }
    } catch (e) {
      debugPrint('[YouTubeApiService] Error: $e');
    }
    return {};
  }

  Future<({List<YouTubeVideo> videos, String? nextPageToken})> _fetchPublicSearchResults({
    required String query,
    String? pageToken,
  }) async {
    try {
      final response = await _dio.get(
        'https://invidious.privacydev.net/api/v1/search',
        queryParameters: {'q': query, 'type': 'video'},
      );

      if (response.statusCode == 200 && response.data is List) {
        final list = response.data as List;
        final videos = list.map((item) {
          final videoId = item['videoId'] ?? '';
          final durationSec = item['lengthSeconds'] ?? 0;
          final durationStr = durationSec > 0
              ? '${(durationSec ~/ 60)}:${(durationSec % 60).toString().padLeft(2, '0')}'
              : '';

          return YouTubeVideo(
            id: videoId,
            title: item['title'] ?? '',
            description: item['description'] ?? '',
            thumbnailUrl: item['videoThumbnails']?[0]?['url'] ??
                'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
            channelTitle: item['author'] ?? '',
            channelId: item['authorId'] ?? '',
            viewCount: item['viewCount'] ?? 0,
            duration: durationStr,
            publishedAt: item['published'] != null
                ? DateTime.fromMillisecondsSinceEpoch((item['published'] as int) * 1000)
                : null,
          );
        }).toList();

        return (videos: videos, nextPageToken: null);
      }
    } catch (e) {
      debugPrint('[YouTubeApiService] Error: $e');
    }

    final mockResults = _getCuratedMockVideos()
        .where((v) =>
            v.title.toLowerCase().contains(query.toLowerCase()) ||
            v.channelTitle.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return (videos: mockResults.isNotEmpty ? mockResults : _getCuratedMockVideos(), nextPageToken: null);
  }

  List<YouTubeVideo> _getFallbackTrendingVideos() {
    return _getCuratedMockVideos();
  }

  List<YouTubeVideo> _getCuratedMockVideos() {
    return [
      YouTubeVideo(
        id: 'dQw4w9WgXcQ',
        title: 'Rick Astley - Never Gonna Give You Up (Official Music Video)',
        description: 'The official video for “Never Gonna Give You Up” by Rick Astley',
        thumbnailUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        channelTitle: 'Rick Astley',
        channelId: 'UCuAXFkgsw1L7xaCfnd5JJOw',
        viewCount: 1540000000,
        likeCount: 17000000,
        duration: '3:33',
        publishedAt: DateTime(2009, 10, 25),
      ),
      YouTubeVideo(
        id: 'kXYiU_JCYtU',
        title: 'Linkin Park - Numb (Official Music Video) [4K Upgrade]',
        description: 'The official music video for Linkin Park\'s "Numb" from Meteora.',
        thumbnailUrl: 'https://i.ytimg.com/vi/kXYiU_JCYtU/hqdefault.jpg',
        channelTitle: 'Linkin Park',
        channelId: 'UCZU9T1ceaOgwfLRq7OKFU4Q',
        viewCount: 2200000000,
        likeCount: 15000000,
        duration: '3:07',
        publishedAt: DateTime(2007, 3, 5),
      ),
    ];
  }
}
