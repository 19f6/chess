import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local player identity + bonus Story Mode progress. Persisted on-device
/// only (no account system is required by the spec).
class UserProvider extends ChangeNotifier {
  String? username;
  bool loaded = false;
  Set<int> completedStoryLevels = {};

  Future<void> loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString('username');
    completedStoryLevels =
        (prefs.getStringList('completedStoryLevels') ?? const []).map(int.parse).toSet();
    loaded = true;
    notifyListeners();
  }

  Future<void> setUsername(String name) async {
    username = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', name);
    notifyListeners();
  }

  Future<void> clearUsername() async {
    username = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    notifyListeners();
  }

  Future<void> markStoryLevelComplete(int level) async {
    if (!completedStoryLevels.add(level)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'completedStoryLevels',
      completedStoryLevels.map((e) => e.toString()).toList(),
    );
    notifyListeners();
  }
}
