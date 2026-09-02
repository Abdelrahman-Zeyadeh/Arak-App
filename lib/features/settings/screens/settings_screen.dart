import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../downloader/services/backend_extraction_service.dart';
import '../../downloader/services/download_queue_service.dart';
import '../../../core/constants/app_constants.dart';
import 'about_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _currentDownloadPath = '';
  final _backendUrlController = TextEditingController();
  final _backendApiKeyController = TextEditingController();
  bool _testingBackend = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _backendUrlController.text = SecureStorageService().getString(AppConstants.extractionBackendUrlKey) ?? '';
    _backendApiKeyController.text = SecureStorageService().getString(AppConstants.extractionBackendApiKeyKey) ?? '';
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
    _backendApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final path = await DownloadQueueService().getDefaultDownloadDirectory();
    if (mounted) {
      setState(() {
        _currentDownloadPath = path;
      });
    }
  }

  Future<void> _saveAndTestBackend() async {
    final url = _backendUrlController.text.trim();
    final apiKey = _backendApiKeyController.text.trim();

    await SecureStorageService().setString(AppConstants.extractionBackendUrlKey, url);
    await SecureStorageService().setString(AppConstants.extractionBackendApiKeyKey, apiKey);

    if (url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم مسح رابط الخادم — رجع التطبيق يعتمد على الطرق الاحتياطية')),
        );
      }
      return;
    }

    setState(() => _testingBackend = true);
    final ok = await BackendExtractionService().checkHealth();
    if (!mounted) return;
    setState(() => _testingBackend = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'تم الاتصال بالخادم بنجاح ✅'
            : 'تعذّر الوصول للخادم — تأكد من الرابط (قد يستغرق أول اتصال حتى دقيقة إذا كان الخادم نائمًا)'),
        backgroundColor: ok ? Colors.green : AppColors.error,
      ),
    );
  }

  Future<void> _pickDownloadDirectory() async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        await SecureStorageService().saveDownloadPath(selectedDirectory);
        setState(() {
          _currentDownloadPath = selectedDirectory;
        });
      }
    } catch (e) {
      debugPrint('[SettingsScreen] Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final authUser = ref.watch(authUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.translate('settings_title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // 1. Google Account Section
              _buildSectionHeader(l10n.translate('google_account')),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: authUser != null
                    ? Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    authUser.displayName.isNotEmpty
                                        ? authUser.displayName.characters.first.toUpperCase()
                                        : 'U',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      authUser.displayName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      authUser.email,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => ref.read(authUserProvider.notifier).signOut(),
                              icon: const Icon(LucideIcons.logOut, size: 16),
                              label: Text(l10n.translate('sign_out')),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(LucideIcons.user, size: 20, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.translate('google_account'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      locale.languageCode == 'ar'
                                          ? 'تسجيل الدخول لمزامنة الحساب (اختياري)'
                                          : 'Sign in to sync your YouTube account (Optional)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => ref.read(authUserProvider.notifier).signIn(),
                              icon: const Icon(LucideIcons.logIn, size: 18),
                              label: Text(l10n.translate('sign_in_google')),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),

              // 2. Downloads Destination Folder
              _buildSectionHeader(l10n.translate('downloads_folder')),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.folder, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.translate('downloads_folder'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currentDownloadPath.isNotEmpty ? _currentDownloadPath : 'Default storage directory',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickDownloadDirectory,
                        icon: const Icon(LucideIcons.folderOpen, size: 16),
                        label: Text(l10n.translate('change_folder')),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 3. Download Settings
              _buildSectionHeader(l10n.translate('download_settings')),
              _buildDownloadSettingsSection(isDark, l10n),
              const SizedBox(height: 24),

              // 3.5 Extraction Server (fixes Facebook/Instagram/Twitter downloads on mobile)
              _buildSectionHeader(locale.languageCode == 'ar' ? 'خادم الاستخراج' : 'Extraction Server'),
              _buildExtractionServerSection(isDark, locale.languageCode),
              const SizedBox(height: 24),

              // 4. Appearance & Language
              _buildSectionHeader(l10n.translate('appearance')),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Theme Switch
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isDark ? LucideIcons.moon : LucideIcons.sun,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(l10n.translate('theme_mode'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: Switch(
                        value: themeMode == ThemeMode.dark,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) {
                          ref.read(themeModeProvider.notifier).setTheme(
                                val ? ThemeMode.dark : ThemeMode.light,
                              );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    // Language Switch
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.globe, color: AppColors.primary, size: 20),
                      ),
                      title: Text(l10n.translate('language'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: DropdownButton<String>(
                        value: locale.languageCode,
                        underline: const SizedBox.shrink(),
                        onChanged: (lang) {
                          if (lang != null) {
                            ref.read(localeProvider.notifier).setLocale(lang);
                          }
                        },
                        items: [
                          DropdownMenuItem(
                            value: 'ar',
                            child: Text(l10n.translate('arabic')),
                          ),
                          DropdownMenuItem(
                            value: 'en',
                            child: Text(l10n.translate('english')),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 5. About App Link
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.info, color: AppColors.primary, size: 20),
                  ),
                  title: Text(l10n.translate('about_app'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 6, bottom: 10, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDownloadSettingsSection(bool isDark, AppLocalizations l10n) {
    final storage = SecureStorageService();
    final wifiOnly = storage.getBool('wifi_only_downloads');
    final maxConcurrent = DownloadQueueService().maxConcurrent;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // WiFi Only Toggle
          SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.wifi, color: Colors.white, size: 18),
            ),
            title: Text(
              l10n.translate('wifi_only'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              l10n.translate('wifi_only_desc'),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            value: wifiOnly,
            activeThumbColor: AppColors.primary,
            onChanged: (val) {
              storage.setBool('wifi_only_downloads', val);
              setState(() {});
            },
          ),
          const Divider(height: 1),
          // Max Concurrent Downloads
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.layers, color: Colors.white, size: 18),
            ),
            title: Text(
              l10n.translate('max_concurrent'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              l10n.translate('max_concurrent_desc'),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E283E) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButton<int>(
                value: maxConcurrent,
                underline: const SizedBox.shrink(),
                onChanged: (val) {
                  if (val != null) {
                    DownloadQueueService().setMaxConcurrent(val);
                    setState(() {});
                  }
                },
                items: [1, 2, 3, 4, 5].map((n) => DropdownMenuItem(
                  value: n,
                  child: Text('$n', style: const TextStyle(fontWeight: FontWeight.bold)),
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractionServerSection(bool isDark, String langCode) {
    final isAr = langCode == 'ar';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.server, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isAr
                      ? 'اربط خادم yt-dlp خاص بك لتحسين تحميل روابط فيسبوك/انستغرام/تويتر على الموبايل. اتركه فارغًا للاعتماد على الطرق الاحتياطية المدمجة.'
                      : 'Connect your own yt-dlp server to fix Facebook/Instagram/Twitter downloads on mobile. Leave empty to use the built-in fallback methods.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _backendUrlController,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: isAr ? 'رابط الخادم' : 'Server URL',
              hintText: 'https://your-app.onrender.com',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _backendApiKeyController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: isAr ? 'مفتاح API (اختياري)' : 'API Key (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _testingBackend ? null : _saveAndTestBackend,
              icon: _testingBackend
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(LucideIcons.checkCircle, size: 16),
              label: Text(isAr ? 'حفظ واختبار الاتصال' : 'Save & Test Connection'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
