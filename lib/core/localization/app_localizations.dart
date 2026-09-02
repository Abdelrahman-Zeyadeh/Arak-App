import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('ar'));
  }

  bool get isArabic => locale.languageCode == 'ar';

  static final Map<String, Map<String, String>> _localizedValues = {
    'ar': {
      'app_name': 'Arak',
      'nav_explore': 'استكشف',
      'nav_search': 'بحث',
      'nav_downloads': 'التحميلات',
      'nav_settings': 'الإعدادات',
      
      // Explore & Search
      'explore_title': 'استكشف يوتيوب',
      'explore_subtitle': 'أحدث وأبرز الفيديوهات الرائجة',
      'search_placeholder': 'ابحث عن فيديوهات، قنوات، أو الصق أي رابط...',
      'search_results': 'نتائج البحث',
      'trending_now': 'الأكثر رواجاً الآن',
      'music': 'موسيقى',
      'gaming': 'ألعاب',
      'technology': 'تقنية',
      'education': 'تعليم',
      'news': 'أخبار',
      'no_results': 'لم يتم العثور على نتائج',
      'views': 'مشاهدة',
      'ago': 'منذ',
      'subscribers': 'مشترك',
      'paste_link_to_download': 'الصق أي رابط للتحميل المباشر',
      
      // Watch Screen
      'watch_title': 'مشاهدة الفيديو',
      'download_btn': 'تحميل',
      'share_btn': 'مشاركة',
      'copy_link': 'نسخ الرابط',
      'link_copied': 'تم نسخ الرابط إلى الحافظة',
      'related_videos': 'فيديوهات مقترحة ذات صلة',
      'description': 'الوصف',
      'show_more': 'عرض المزيد',
      'show_less': 'عرض أقل',
      
      // Downloader
      'download_modal_title': 'خيارات التحميل',
      'probing_formats': 'جاري استخراج الجودات والصيغ المتاحة...',
      'fetching_info': 'جاري فحص الرابط...',
      'video_with_audio': 'فيديو مع صوت',
      'audio_only': 'صوت فقط (MP3 / M4A)',
      'best_quality': 'أفضل جودة متاحة',
      'download_now': 'بدء التحميل الآن',
      'download_started': 'تمت إضافة التحميل إلى قائمة الانتظار',
      'active_downloads': 'التحميلات النشطة',
      'download_speed': 'السرعة',
      'time_remaining': 'الوقت المتبقي',
      'cancel': 'إلغاء',
      'retry': 'إعادة المحاولة',
      'open_folder': 'فتح المجلد',
      'delete_file': 'حذف',
      'rename_file': 'إعادة تسمية',
      
      // Downloads Tab
      'downloads_title': 'سجل التحميلات',
      'all': 'الكل',
      'videos': 'فيديوهات',
      'audios': 'صوتيات',
      'no_downloads_yet': 'لا توجد تحميلات حتى الآن',
      'no_downloads_sub': 'الملفات التي تقوم بتحميلها ستظهر هنا للاستماع والمشاهدة بدون إنترنت',
      'play_now': 'تشغيل',
      
      // Settings
      'settings_title': 'الإعدادات والتخصيص',
      'general': 'عام',
      'appearance': 'المظهر',
      'theme_mode': 'الوضع المظلم',
      'language': 'اللغة',
      'arabic': 'العربية',
      'english': 'English',
      'api_key_title': 'مفتاح YouTube Data API Key',
      'api_key_desc': 'يُستخدم للبحث واستعراض الفيديوهات الرسمية',
      'api_key_placeholder': 'ألصق مفتاح AIzaSy... هنا',
      'save': 'حفظ',
      'api_key_saved': 'تم حفظ مفتاح API بنجاح',
      'google_account': 'حساب Google',
      'sign_in_google': 'تسجيل الدخول بحساب Google',
      'sign_out': 'تسجيل الخروج',
      'signed_in_as': 'مسجل الدخول كـ',
      'downloads_folder': 'مجلد حفظ التنزيلات',
      'change_folder': 'تغيير المجلد',
      'about_app': 'حول التطبيق',
      'version': 'الإصدار',
      'disclaimer_title': 'إخلاء المسؤولية القانوني',
      'quick_download': 'تحميل سريع برابط',
      'recent_searches': 'عمليات البحث الأخيرة',
      'clear_all': 'مسح الكل',
    },
    'en': {
      'app_name': 'Arak',
      'nav_explore': 'Explore',
      'nav_search': 'Search',
      'nav_downloads': 'Downloads',
      'nav_settings': 'Settings',
      
      // Explore & Search
      'explore_title': 'Explore YouTube',
      'explore_subtitle': 'Discover what is trending and popular',
      'search_placeholder': 'Search videos, channels, or paste any video link...',
      'search_results': 'Search Results',
      'trending_now': 'Trending Now',
      'music': 'Music',
      'gaming': 'Gaming',
      'technology': 'Technology',
      'education': 'Education',
      'news': 'News',
      'no_results': 'No results found',
      'views': 'views',
      'ago': 'ago',
      'subscribers': 'subscribers',
      'paste_link_to_download': 'Paste any link for direct download',
      
      // Watch Screen
      'watch_title': 'Watch Video',
      'download_btn': 'Download',
      'share_btn': 'Share',
      'copy_link': 'Copy Link',
      'link_copied': 'Link copied to clipboard',
      'related_videos': 'Related Videos',
      'description': 'Description',
      'show_more': 'Show more',
      'show_less': 'Show less',
      
      // Downloader
      'download_modal_title': 'Download Options',
      'probing_formats': 'Extracting available formats and qualities...',
      'fetching_info': 'Analyzing link...',
      'video_with_audio': 'Video with Audio',
      'audio_only': 'Audio Only (MP3 / M4A)',
      'best_quality': 'Best Available Quality',
      'download_now': 'Start Download Now',
      'download_started': 'Download added to queue',
      'active_downloads': 'Active Downloads',
      'download_speed': 'Speed',
      'time_remaining': 'ETA',
      'cancel': 'Cancel',
      'retry': 'Retry',
      'open_folder': 'Open Folder',
      'delete_file': 'Delete',
      'rename_file': 'Rename',
      
      // Downloads Tab
      'downloads_title': 'Download Library',
      'all': 'All',
      'videos': 'Videos',
      'audios': 'Audio',
      'no_downloads_yet': 'No downloads yet',
      'no_downloads_sub': 'Files you download will appear here for offline playback',
      'play_now': 'Play',
      
      // Settings
      'settings_title': 'Settings & Preferences',
      'general': 'General',
      'appearance': 'Appearance',
      'theme_mode': 'Dark Mode',
      'language': 'Language',
      'arabic': 'العربية',
      'english': 'English',
      'api_key_title': 'YouTube Data API Key',
      'api_key_desc': 'Used for official YouTube search & video metadata',
      'api_key_placeholder': 'Paste AIzaSy... key here',
      'save': 'Save',
      'api_key_saved': 'API key saved successfully',
      'google_account': 'Google Account',
      'sign_in_google': 'Sign in with Google',
      'sign_out': 'Sign Out',
      'signed_in_as': 'Signed in as',
      'downloads_folder': 'Download Destination Folder',
      'change_folder': 'Change Directory',
      'about_app': 'About App',
      'version': 'Version',
      'disclaimer_title': 'Legal Disclaimer',
      'quick_download': 'Quick Link Download',
      'recent_searches': 'Recent Searches',
      'clear_all': 'Clear All',
    }
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? 
           _localizedValues['en']?[key] ?? 
           key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
