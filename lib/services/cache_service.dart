import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static CacheService? _instance;
  SharedPreferences? _prefs;

  CacheService._();

  factory CacheService() {
    _instance ??= CacheService._();
    return _instance!;
  }

  Future<SharedPreferences> get _getPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Save a list of objects to local storage
  Future<void> saveList<T>(
    String key,
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    try {
      final prefs = await _getPrefs;
      final jsonList = items.map((item) => toJson(item)).toList();
      final jsonString = jsonEncode(jsonList);
      await prefs.setString(key, jsonString);
    } catch (_) {
      // Ignore write errors
    }
  }

  /// Retrieve a list of objects from local storage
  Future<List<T>?> getList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final prefs = await _getPrefs;
      final jsonString = prefs.getString(key);
      if (jsonString == null || jsonString.isEmpty) return null;

      final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
      return decoded
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Save a single object or map to local storage
  Future<void> saveMap(String key, Map<String, dynamic> data) async {
    try {
      final prefs = await _getPrefs;
      await prefs.setString(key, jsonEncode(data));
    } catch (_) {}
  }

  /// Retrieve a single map from local storage
  Future<Map<String, dynamic>? Function()?> getMap(String key) async {
    try {
      final prefs = await _getPrefs;
      final jsonString = prefs.getString(key);
      if (jsonString == null || jsonString.isEmpty) return null;
      return () => jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Remove a specific cache key
  Future<void> remove(String key) async {
    try {
      final prefs = await _getPrefs;
      await prefs.remove(key);
    } catch (_) {}
  }

  /// Clear all cached data (e.g. on user sign out)
  Future<void> clearAllCache() async {
    try {
      final prefs = await _getPrefs;
      await prefs.clear();
    } catch (_) {}
  }
}
