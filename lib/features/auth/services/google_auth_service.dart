import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/youtube.readonly',
    ],
  );

  static const String _userStorageKey = 'arak_google_user';

  Future<UserProfile?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_userStorageKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        return UserProfile.fromJson(jsonDecode(jsonStr));
      } catch (e) {
        debugPrint('[GoogleAuthService] Error: $e');
      }
    }
    return null;
  }

  Future<UserProfile?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        final profile = UserProfile(
          id: account.id,
          displayName: account.displayName ?? account.email.split('@').first,
          email: account.email,
          photoUrl: account.photoUrl ?? '',
        );
        await _saveUser(profile);
        return profile;
      }
    } catch (e) {
      debugPrint('[GoogleAuthService] Sign-in failed: $e');
      return null;
    }
    return null;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('[GoogleAuthService] Error: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userStorageKey);
  }

  Future<void> _saveUser(UserProfile user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userStorageKey, jsonEncode(user.toJson()));
  }
}
