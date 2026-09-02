import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../services/google_auth_service.dart';

final authUserProvider = StateNotifierProvider<AuthNotifier, UserProfile?>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<UserProfile?> {
  AuthNotifier() : super(null) {
    _loadUser();
  }

  final _service = GoogleAuthService();

  Future<void> _loadUser() async {
    final user = await _service.getCurrentUser();
    state = user;
  }

  Future<void> signIn() async {
    final user = await _service.signIn();
    state = user;
  }

  Future<void> signOut() async {
    await _service.signOut();
    state = null;
  }
}
