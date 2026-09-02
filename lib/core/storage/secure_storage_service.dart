import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- YouTube Data API Key (Sensitive - uses flutter_secure_storage) ---
  Future<void> saveApiKey(String apiKey) async {
    try {
      await _secureStorage.write(key: AppConstants.apiKeyStorageKey, value: apiKey.trim());
    } catch (e) {
      debugPrint('[SecureStorage] Failed to save API key: $e');
    }
  }

  Future<String?> getApiKey() async {
    try {
      return await _secureStorage.read(key: AppConstants.apiKeyStorageKey);
    } catch (e) {
      debugPrint('[SecureStorage] Failed to read API key: $e');
      return null;
    }
  }

  Future<void> deleteApiKey() async {
    try {
      await _secureStorage.delete(key: AppConstants.apiKeyStorageKey);
    } catch (e) {
      debugPrint('[SecureStorage] Failed to delete API key: $e');
    }
  }

  // --- Theme Mode (Non-sensitive - uses SharedPreferences) ---
  Future<void> saveThemeMode(String mode) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(AppConstants.themeModeStorageKey, mode);
  }

  String getThemeMode() {
    return _prefs?.getString(AppConstants.themeModeStorageKey) ?? 'light';
  }

  // --- Locale (Non-sensitive - uses SharedPreferences) ---
  Future<void> saveLocale(String langCode) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(AppConstants.localeStorageKey, langCode);
  }

  String getLocale() {
    return _prefs?.getString(AppConstants.localeStorageKey) ?? 'ar';
  }

  // --- Download Directory (Non-sensitive - uses SharedPreferences) ---
  Future<void> saveDownloadPath(String path) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(AppConstants.downloadPathStorageKey, path);
  }

  String? getDownloadPath() {
    return _prefs?.getString(AppConstants.downloadPathStorageKey);
  }

  // --- Generic Key-Value (Non-sensitive - uses SharedPreferences) ---
  Future<void> setString(String key, String value) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(key, value);
  }

  String? getString(String key) {
    return _prefs?.getString(key);
  }

  // --- Boolean settings ---
  Future<void> setBool(String key, bool value) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(key, value);
  }

  bool getBool(String key, {bool defaultValue = false}) {
    return _prefs?.getBool(key) ?? defaultValue;
  }

  // --- Int settings ---
  Future<void> setInt(String key, int value) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt(key, value);
  }

  int getInt(String key, {int defaultValue = 2}) {
    return _prefs?.getInt(key) ?? defaultValue;
  }
}
