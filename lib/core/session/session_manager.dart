import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user.dart';
import '../../repositories/user_repository.dart';

/// Holds the currently logged-in user in memory; persists the id in shared_preferences.
/// Initialised in main() before runApp — router guards can be synchronous.
class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  static const _key = 'session_user_id';

  User? _user;

  User? get currentUser => _user;
  bool get isLoggedIn => _user != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_key);
    if (id == null) return;
    _user = await UserRepository().getById(id);
    if (_user == null) await prefs.remove(_key);
  }

  Future<void> login(User user) async {
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, user.id!);
  }

  /// Call after updating the profile so the Drawer header reflects new data.
  Future<void> refresh() async {
    if (_user?.id != null) {
      _user = await UserRepository().getById(_user!.id!);
    }
  }

  Future<void> logout() async {
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
