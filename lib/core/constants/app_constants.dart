class AppConstants {
  static const String appName = 'Arak';
  static const String appTaglineAr = 'تصفح، مشاهدة، وتحميل الفيديوهات بذكاء وأناقة';
  static const String appTaglineEn = 'Browse, watch, and download videos with elegance';
  static const String appVersion = '1.0.0';
  
  // Storage Keys
  static const String apiKeyStorageKey = 'arak_yt_api_key';
  static const String downloadPathStorageKey = 'arak_download_path';
  static const String themeModeStorageKey = 'arak_theme_mode';
  static const String localeStorageKey = 'arak_locale';
  static const String downloadsDbKey = 'arak_downloads_history';
  static const String maxConcurrentDownloadsKey = 'arak_max_concurrent_downloads';
  static const String extractionBackendUrlKey = 'arak_extraction_backend_url';
  static const String extractionBackendApiKeyKey = 'arak_extraction_backend_api_key';
  static const String googleAccessTokenStorageKey = 'arak_google_access_token';
  static const String downloadQueueStateKey = 'arak_download_queue_state';

  // Shared yt-dlp extraction backend (see /backend in this repo).
  // Baked in so every installed copy of the app works out of the box for
  // Facebook/Instagram/Twitter downloads on mobile without each user having
  // to deploy and configure their own server. Users can still override this
  // in Settings → Extraction Server to point at their own instance — that
  // saved value always takes priority over these defaults.
  // Moved off Render: YouTube blocks Render's datacenter IP range outright
  // ("Failed to extract any player response" on every video, confirmed via
  // direct testing — not fixed by a PO Token provider or cookies, since
  // it's an IP-level block, not a per-request check). Railway's IP range
  // isn't currently blocked; same Dockerfile, just a different host.
  static const String defaultExtractionBackendUrl = 'https://arak-extraction-production.up.railway.app';
  static const String defaultExtractionBackendApiKey = 'arak-9f3k7d2m5x8q1z';

  // YouTube API Configuration
  // Shared key, restricted in Google Cloud Console to the YouTube Data API v3
  // + this app's Android package/SHA-1 fingerprint. Users can still override
  // it with their own key in Settings (SecureStorageService.saveApiKey).
  static const String defaultYouTubeApiKey = 'AIzaSyBhgK3tk6c73HkpXZ4C4iAiOIjxhxg3Zzw';
  static const String ytBaseApiUrl = 'https://www.googleapis.com/youtube/v3';
  
  // Disclaimer
  static const String disclaimerAr = 
      'تطبيق Arak هو أداة شخصية وتجريبية مخصصة للاستخدام الفردي والتعلّمي فقط. '
      'المستخدم يتحمل المسؤولية الكاملة عن الامتثال لقوانين حقوق الملكية الفكرية وشروط استخدام المنصات المختلفة.';
  static const String disclaimerEn = 
      'Arak app is a personal and educational utility intended for individual use only. '
      'The user is solely responsible for respecting intellectual property rights and platform terms of service.';
}
