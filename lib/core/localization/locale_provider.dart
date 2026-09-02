import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage_service.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('ar')) {
    _loadLocale();
  }

  void _loadLocale() {
    final langCode = SecureStorageService().getLocale();
    state = Locale(langCode);
  }

  void setLocale(String langCode) {
    state = Locale(langCode);
    SecureStorageService().saveLocale(langCode);
  }

  void toggleLocale() {
    if (state.languageCode == 'ar') {
      setLocale('en');
    } else {
      setLocale('ar');
    }
  }
}
