# Arak App - Comprehensive Fix & Feature Prompt

## Context
This is a Flutter app called "Arak" for browsing, watching, and downloading videos from YouTube, Instagram, TikTok, and Vimeo. The app uses Flutter + Riverpod 2.0 + Dio + YoutubeExplode + SharedPreferences. The codebase is at `C:\Users\abood\OneDrive\Desktop\ProjectsClaude\Arak app`.

You are an expert Flutter developer. Execute ALL the tasks below in order. Each task has a priority level. Complete them all.

---

## PART 1: CRITICAL BUG FIXES (Must fix first)

### 1.1 Remove exposed YouTube API key
**File:** `lib/core/constants/app_constants.dart:17`
The YouTube API key `AIzaSyDuUe1uGVXZfb-qjl6e186p9TIg-t8uCHI` is hardcoded. Remove it completely. Replace with:
```dart
static const String defaultYouTubeApiKey = ''; // User must provide their own key
```
Add a setting in SettingsScreen that lets the user enter their own YouTube API key. Use `SecureStorageService` to save it.

### 1.2 Fix Google Auth demo session on failure
**File:** `lib/features/auth/services/google_auth_service.dart:44-53`
Currently when Google Sign-In fails, it creates a fake demo user and saves it. This is dangerous. Fix it:
- Remove the catch block that creates `demoProfile`
- Instead, rethrow the error or return `null`
- The `signIn()` method should return `null` on failure, not a fake profile

### 1.3 Fix `setState(() {})` on every keystroke in search
**File:** `lib/features/explore_search/screens/search_screen.dart:84-86`
Currently `onChanged: (val) { setState(() {}); }` rebuilds the entire widget tree on every character typed. Fix:
- Use a `ValueNotifier<bool>` for the clear button visibility
- Wrap only the `suffixIcon` with `ValueListenableBuilder`
- Remove the `setState` from `onChanged`

### 1.4 Fix `nextPageToken` not updating in loadMore
**File:** `lib/features/explore_search/providers/explore_search_provider.dart:170-176`
The `loadMore()` method never updates `nextPageToken`. Fix by capturing it from the API response:
```dart
final moreVideos = await _apiService.loadMoreSearchResults(
  query: state.query,
  nextPageToken: state.nextPageToken,
  sortBy: state.sortBy,
);
// You need to also capture the new nextPageToken from the response
// Assuming searchVideos returns a result with nextPageToken:
state = state.copyWith(
  videos: [...state.videos, ...moreVideos],
  nextPageToken: newNextPageToken, // <-- ADD THIS
  isLoadingMore: false,
  hasMore: moreVideos.isNotEmpty,
);
```
Check the `YouTubeApiService.loadMoreSearchResults` method - it likely already returns a token but the provider ignores it. Make sure the provider captures and passes it.

### 1.5 Fix _isUrl validation
**File:** `lib/features/explore_search/screens/search_screen.dart:55-58`
The `_isUrl` method uses `contains('youtube.com')` which matches any text containing those words. Fix to check if it's actually a URL:
```dart
bool _isUrl(String text) {
  final t = text.trim();
  final urlPattern = RegExp(
    r'^(https?:\/\/)?(www\.)?(youtube\.com|youtu\.be|instagram\.com|tiktok\.com|vimeo\.com|facebook\.com|twitter\.com|x\.com)\/',
    caseSensitive: false,
  );
  return urlPattern.hasMatch(t);
}
```

---

## PART 2: SECURITY FIXES

### 2.1 Replace SharedPreferences with flutter_secure_storage for sensitive data
**File:** `lib/core/storage/secure_storage_service.dart`

Add `flutter_secure_storage: ^9.0.0` to pubspec.yaml. Rewrite `SecureStorageService`:
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> init() async {}

  // YouTube API Key
  Future<void> saveApiKey(String apiKey) async {
    await _storage.write(key: AppConstants.apiKeyStorageKey, value: apiKey);
  }

  Future<String?> getApiKey() async {
    return await _storage.read(key: AppConstants.apiKeyStorageKey);
  }

  Future<void> deleteApiKey() async {
    await _storage.delete(key: AppConstants.apiKeyStorageKey);
  }

  // Theme Mode
  Future<void> saveThemeMode(String mode) async {
    await _storage.write(key: AppConstants.themeModeStorageKey, value: mode);
  }

  String getThemeMode() {
    // For theme, SharedPreferences is fine since it's not sensitive
    // But for consistency, we use secure storage
    // Note: This is a sync method - keep using SharedPreferences for non-sensitive prefs
    return 'light'; // Will be loaded async in theme_provider
  }

  // Keep SharedPreferences for non-sensitive data (theme, locale, download path)
  // Use _storage only for sensitive data (API keys, user tokens)
}
```

Actually, the best approach: Keep SharedPreferences for non-sensitive settings (theme, locale, download path). Use flutter_secure_storage ONLY for sensitive data (API keys, auth tokens). Update `main.dart` init accordingly.

### 2.2 Remove fake Instagram User-Agent
**File:** `lib/features/downloader/services/ytdlp_engine.dart:501`
Change `'User-Agent': 'Instagram 219.0.0.12.117 Android'` to a standard browser User-Agent:
```dart
'User-Agent': 'Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
```

---

## PART 3: PERFORMANCE FIXES

### 3.1 Add image caching with cached_network_image
**File:** `lib/features/explore_search/screens/widgets/video_card.dart:99-108`

Add `cached_network_image: ^3.4.1` to pubspec.yaml.

Replace all `Image.network()` calls in video_card.dart with `CachedNetworkImage()`:
```dart
CachedNetworkImage(
  imageUrl: widget.video.thumbnailUrl,
  fit: BoxFit.cover,
  placeholder: (context, url) => Container(
    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
  ),
  errorWidget: (_, _, _) => Container(
    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
    child: const Center(child: Icon(LucideIcons.video, size: 32, color: Colors.grey)),
  ),
)
```

Do the same for `download_modal_sheet.dart` thumbnail if applicable.

### 3.2 Add AutomaticKeepAliveClientMixin to screens
**File:** `lib/shared/widgets/app_scaffold.dart`

Replace `IndexedStack` with a `PageView` that keeps pages alive, or add `AutomaticKeepAliveClientMixin` to each screen. The simplest fix:

In `explore_screen.dart` and `search_screen.dart`, add the mixin:
```dart
class _ExploreScreenState extends ConsumerState<ExploreScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    // ... rest of build
  }
}
```

### 3.3 Fix YoutubeExplode not being reused
**File:** `lib/features/explore_search/services/youtube_api_service.dart`

Create a single reusable `YoutubeExplode` instance instead of creating/destroying in each call:
```dart
class YouTubeApiService {
  static final YouTubeApiService _instance = YouTubeApiService._internal();
  factory YouTubeApiService() => _instance;
  YouTubeApiService._internal();

  final _yt = YoutubeExplode(); // Single instance
  
  // Use _yt in all methods instead of creating new instances
  // Make sure to handle cleanup properly
}
```

---

## PART 4: NEW FEATURES - SnapTube-style

### 4.1 Built-in Browser (WebView)
Create a new screen: `lib/features/browser/screens/in_app_browser_screen.dart`

Requirements:
- Use `webview_flutter: ^4.10.0` package
- WebView that loads YouTube/mobile sites
- When user navigates to a video page, show a floating download button
- Auto-detect video URLs and show DownloadModalSheet
- Add a tab in the bottom nav or as a button in ExploreScreen
- Add a "Browser" tab to the bottom navigation in `app_scaffold.dart` (make it 5 tabs)

Add to `app_scaffold.dart`:
```dart
// Add browser tab at index 1, shift others:
// 0: Explore, 1: Browser, 2: Search, 3: Downloads, 4: Settings
```

### 4.2 Share Intent - Open app from share menu
Add `receive_sharing_intent: ^1.8.0` to pubspec.yaml.

Modify `lib/main.dart`:
```dart
// In main(), after SecureStorageService init:
// Handle share intent on app start

class ArakApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ... existing MaterialApp
    
    // Add a wrapper widget that listens for share intents
    return MaterialApp(
      // ...
      home: ShareIntentHandler(child: const AppScaffold()),
    );
  }
}

// Create: lib/shared/widgets/share_intent_handler.dart
class ShareIntentHandler extends StatefulWidget {
  final Widget child;
  const ShareIntentHandler({required this.child});
  
  @override
  State<ShareIntentHandler> createState() => _ShareIntentHandlerState();
}

class _ShareIntentHandlerState extends State<ShareIntentHandler> {
  @override
  void initState() {
    super.initState();
    // Listen for initial share intent
    ReceiveSharingIntent.getInitialText().then((String? text) {
      if (text != null && text.isNotEmpty) {
        _handleSharedUrl(text);
      }
    });
    
    // Listen for share intents while app is running
    ReceiveSharingIntent.getTextStream().listen((String? text) {
      if (text != null && text.isNotEmpty) {
        _handleSharedUrl(text);
      }
    });
  }
  
  void _handleSharedUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      DownloadModalSheet.show(context, url: url);
    }
  }
  
  @override
  Widget build(BuildContext context) => widget.child;
}
```

### 4.3 Playlist Download
**File:** `lib/features/downloader/services/ytdlp_engine.dart` and `lib/features/downloader/services/download_queue_service.dart`

Add a method to probe playlists:
```dart
// In YtDlpEngine, add:
Future<List<VideoMetadata>> probePlaylist(String url) async {
  final ytId = _extractYouTubeId(url);
  // Check if it's a playlist URL
  if (url.contains('list=')) {
    try {
      final yt = YoutubeExplode();
      final playlistId = _extractPlaylistId(url);
      if (playlistId != null) {
        final playlist = await yt.playlists.get(playlistId);
        final List<VideoMetadata> videos = [];
        
        await for (final video in yt.playlists.getVideos(playlistId)) {
          videos.add(VideoMetadata(
            id: video.id.value,
            title: video.title,
            uploader: video.author,
            thumbnail: video.thumbnails.highResUrl,
            duration: video.duration?.inSeconds ?? 0,
            webpageUrl: 'https://www.youtube.com/watch?v=${video.id.value}',
            formats: [], // Will be probed on demand
          ));
        }
        yt.close();
        return videos;
      }
    } catch (e) {
      debugPrint('Playlist probe error: $e');
    }
  }
  return [];
}

String? _extractPlaylistId(String url) {
  final match = RegExp(r'[?&]list=([a-zA-Z0-9_-]+)').firstMatch(url);
  return match?.group(1);
}
```

Add playlist download to `DownloadQueueService`:
```dart
Future<void> enqueuePlaylist({
  required String url,
  required String title,
  required String thumbnailUrl,
  required DownloadFormat format,
}) async {
  final videos = await YtDlpEngine().probePlaylist(url);
  for (final video in videos) {
    await enqueueDownload(
      url: video.webpageUrl,
      title: video.title,
      thumbnailUrl: video.thumbnail,
      format: format,
    );
  }
}
```

Update `DownloadModalSheet` to detect playlist URLs and show a "Download All" button.

### 4.4 Download Complete Notification
Add `flutter_local_notifications: ^18.0.0` to pubspec.yaml.

**File:** `lib/features/downloader/services/download_queue_service.dart`

In the `completed` handler (around line 116-145), add notification:
```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// At class level:
final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

// Init in a method:
Future<void> initNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await _notifications.initialize(initSettings);
}

// When download completes, show notification:
Future<void> _showDownloadCompleteNotification(String title, String filePath) async {
  const androidDetails = AndroidNotificationDetails(
    'arak_downloads',
    'Arak Downloads',
    channelDescription: 'Notifications for completed downloads',
    importance: Importance.max,
    priority: Priority.high,
  );
  const details = NotificationDetails(android: androidDetails);
  await _notifications.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    'Download Complete',
    '$title has been downloaded successfully',
    details,
  );
}
```

Call this in the download completed handler.

### 4.5 Pause/Resume Downloads
**File:** `lib/features/downloader/models/download_task.dart`

The model already has `DownloadStatus.paused`. Now implement the logic:

**File:** `lib/features/downloader/services/download_queue_service.dart`

Add pause/resume methods:
```dart
void pauseTask(String taskId) {
  final index = _tasks.indexWhere((t) => t.id == taskId);
  if (index != -1 && _tasks[index].status == DownloadStatus.downloading) {
    _activeSubscriptions[taskId]?.cancel();
    _activeSubscriptions.remove(taskId);
    _tasks[index] = _tasks[index].copyWith(status: DownloadStatus.paused);
    _notify();
    _processQueue(); // Start next pending task
  }
}

void resumeTask(String taskId) {
  final index = _tasks.indexWhere((t) => t.id == taskId);
  if (index != -1 && _tasks[index].status == DownloadStatus.paused) {
    _tasks[index] = _tasks[index].copyWith(
      status: DownloadStatus.pending,
      progress: _tasks[index].progress, // Keep current progress
    );
    _notify();
    _processQueue();
  }
}
```

Note: For true resume (continuing from byte offset), you'd need to modify `YtDlpEngine._downloadYouTubeNative` to accept a `startByte` parameter and use HTTP Range headers. For now, re-downloading from the beginning on resume is acceptable.

### 4.6 Private Vault
Create new files:
- `lib/features/downloads_library/screens/private_vault_screen.dart`
- `lib/features/downloads_library/providers/private_vault_provider.dart`

Requirements:
- PIN/password protection using `local_auth: ^2.3.0`
- Fingerprint/biometric unlock
- Move items from main library to vault
- Hide vault tab behind a long-press or secret gesture

Add to SettingsScreen:
```dart
// Add a "Private Vault" option
ListTile(
  leading: const Icon(LucideIcons.lock),
  title: Text('Private Vault'),
  onTap: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => const PrivateVaultScreen(),
  )),
)
```

### 4.7 Quick Share Buttons after Download
**File:** `lib/features/downloads_library/widgets/download_item_tile.dart`

Add share buttons to each downloaded item:
```dart
// In the trailing/action area of each tile, add:
Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    IconButton(
      icon: const Icon(LucideIcons.share2, size: 16),
      onPressed: () => Share.shareXFiles(
        [XFile(item.filePath)],
        text: item.title,
      ),
    ),
    IconButton(
      icon: const Icon(LucideIcons.play, size: 16),
      onPressed: () => _playFile(item),
    ),
  ],
)
```

Add `share_plus: ^10.0.0` to pubspec.yaml.

### 4.8 Smart Download Settings
**File:** `lib/features/settings/screens/settings_screen.dart`

Add these settings:
```dart
// WiFi Only Toggle
SwitchListTile(
  title: const Text('WiFi Only Downloads'),
  subtitle: const Text('Only download when connected to WiFi'),
  value: _wifiOnly,
  onChanged: (val) {
    setState(() => _wifiOnly = val);
    // Save to preferences
  },
)

// Max Concurrent Downloads
 ListTile(
  title: const Text('Max Concurrent Downloads'),
  trailing: DropdownButton<int>(
    value: _maxConcurrent,
    items: [1, 2, 3, 4, 5].map((n) => DropdownMenuItem(
      value: n,
      child: Text('$n'),
    )).toList(),
    onChanged: (val) {
      if (val != null) {
        setState(() => _maxConcurrent = val);
        // Update DownloadQueueService max concurrent
      }
    },
  ),
)
```

### 4.9 Background Audio Playback
Add `just_audio: ^0.9.42` and `audio_service: ^0.18.1` to pubspec.yaml.

This is complex. Create:
- `lib/features/player/services/audio_handler.dart`

For now, implement a simple version: When user is on WatchScreen and presses home, keep audio playing using `audio_service`. This requires platform-specific setup (Android manifest, iOS entitlements).

Simplified approach: Add a toggle in WatchScreen that says "Play in background". When enabled, extract audio stream and play via `just_audio` while app is in background.

### 4.10 Explore Screen Category Tabs
**File:** `lib/features/explore_search/screens/explore_screen.dart`

Replace the simple `CategoryChips` with a proper TabBar:
```dart
// Add a TabBar below the search bar:
DefaultTabController(
  length: 6,
  child: Column(
    children: [
      TabBar(
        isScrollable: true,
        tabs: [
          Tab(text: 'All'),
          Tab(text: 'Music'),
          Tab(text: 'Gaming'),
          Tab(text: 'Tech'),
          Tab(text: 'Education'),
          Tab(text: 'News'),
        ],
        onTap: (index) {
          final categories = [null, '10', '20', '28', '27', '25'];
          ref.read(selectedCategoryProvider.notifier).state = categories[index];
        },
      ),
    ],
  ),
)
```

---

## PART 5: ARCHITECTURE IMPROVEMENTS

### 5.1 Add logging instead of silent catch blocks
Everywhere there's `catch (_) {}` or `catch (_)`, replace with:
```dart
catch (e, stackTrace) {
  debugPrint('[ERROR] ${runtimeType}: $e');
  debugPrintStack(stackTrace: stackTrace);
}
```

This applies to ALL files in the project. Search for `catch (_)` and fix every instance.

### 5.2 Split ytdlp_engine.dart (868 lines)
Split into:
- `lib/features/downloader/services/ytdlp_engine.dart` - Main class with download methods
- `lib/features/downloader/services/social_media_resolver.dart` - `_resolveSocialMediaStreamUrl` and related social media logic
- `lib/features/downloader/services/ytdlp_parser.dart` - `_parseYtDlpOutput` and binary management

### 5.3 Add download speed and ETA as numeric values to DownloadTask
**File:** `lib/features/downloader/models/download_task.dart`

Add numeric fields:
```dart
final double currentSpeedBytesPerSec; // Raw speed in bytes/sec
final int remainingSeconds; // Raw ETA in seconds

// Keep the string versions for display:
final String speedStr; // Formatted: "1.5 MB/s"
final String etaStr; // Formatted: "3:45"
```

### 5.4 Use a proper error model
Create `lib/core/models/failure.dart`:
```dart
class Failure {
  final String message;
  final String? code;
  final dynamic originalError;

  const Failure({
    required this.message,
    this.code,
    this.originalError,
  });
}
```

Use this in providers instead of `String? errorMessage`.

---

## PART 6: UI/UX IMPROVEMENTS

### 6.1 Add "File size preview" in download modal
**File:** `lib/features/downloader/widgets/download_modal_sheet.dart`

Already shows size in format list. Make sure it's prominent:
- Show estimated file size next to each format option (already done)
- Add a summary at the bottom: "Estimated size: XX MB"

### 6.2 Add "Download Complete" animation
When a download finishes in the downloads screen, show a brief celebration animation (checkmark with color).

### 6.3 Add sorting to downloads library
**File:** `lib/features/downloads_library/screens/downloads_screen.dart`

Add sort options:
- By date (newest/oldest)
- By name (A-Z/Z-A)
- By size (largest/smallest)

### 6.4 Add "Clear All" button for downloads
Already exists in the UI (`Clear finished` button). Make sure it works properly.

### 6.5 Add confirmation dialog before deleting downloads
**File:** `lib/features/downloads_library/widgets/download_item_tile.dart`

Before deleting, show:
```dart
showDialog(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Text('Delete Download'),
    content: const Text('Are you sure you want to delete this file?'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      ElevatedButton(
        onPressed: () {
          Navigator.pop(ctx);
          // Delete file
        },
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
        child: const Text('Delete'),
      ),
    ],
  ),
);
```

---

## EXECUTION ORDER

1. **First**: Fix critical bugs (1.1 - 1.5)
2. **Second**: Security fixes (2.1 - 2.2)
3. **Third**: Performance fixes (3.1 - 3.3)
4. **Fourth**: Architecture improvements (5.1 - 5.4)
5. **Fifth**: New features (4.1 - 4.10) - Start with 4.3, 4.4, 4.5, 4.8 as they're most impactful
6. **Sixth**: UI/UX improvements (6.1 - 6.5)

After each major change, run `flutter analyze` to check for errors.

## NEW DEPENDENCIES TO ADD TO pubspec.yaml
```yaml
dependencies:
  # Existing...
  
  # New:
  flutter_secure_storage: ^9.0.0
  cached_network_image: ^3.4.1
  receive_sharing_intent: ^1.8.0
  flutter_local_notifications: ^18.0.0
  share_plus: ^10.0.0
  local_auth: ^2.3.0
  just_audio: ^0.9.42
  audio_service: ^0.18.1
  webview_flutter: ^4.10.0
```
