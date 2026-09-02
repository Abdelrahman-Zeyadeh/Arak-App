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
  
  // YouTube API Configuration
  // يرجى إدخال مفتاح API الخاص بك من Google Cloud Console
  static const String defaultYouTubeApiKey = '';
  static const String ytBaseApiUrl = 'https://www.googleapis.com/youtube/v3';
  
  // Disclaimer
  static const String disclaimerAr = 
      'تطبيق Arak هو أداة شخصية وتجريبية مخصصة للاستخدام الفردي والتعلّمي فقط. '
      'المستخدم يتحمل المسؤولية الكاملة عن الامتثال لقوانين حقوق الملكية الفكرية وشروط استخدام المنصات المختلفة.';
  static const String disclaimerEn = 
      'Arak app is a personal and educational utility intended for individual use only. '
      'The user is solely responsible for respecting intellectual property rights and platform terms of service.';
}
