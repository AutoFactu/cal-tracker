import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesStorage {
  AppPreferencesStorage({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  Future<String?> readString(String key) {
    return _preferences.getString(key);
  }

  Future<void> writeString(String key, String value) {
    return _preferences.setString(key, value);
  }

  Future<void> remove(String key) {
    return _preferences.remove(key);
  }
}
