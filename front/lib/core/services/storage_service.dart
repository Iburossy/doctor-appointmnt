import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import '../config/app_config.dart';

class StorageService {
  static late SharedPreferences _prefs;
  static late Box _hiveBox;
  
  // Initialize storage services
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _hiveBox = await Hive.openBox('doctors_app');
  }
  
  // Token Management
  static Future<void> saveToken(String token) async {
    await _prefs.setString(AppConfig.tokenKey, token);
  }
  
  static Future<String?> getToken() async {
    return _prefs.getString(AppConfig.tokenKey);
  }
  
  static Future<void> clearToken() async {
    await _prefs.remove(AppConfig.tokenKey);
  }
  
  static Future<bool> hasToken() async {
    return _prefs.containsKey(AppConfig.tokenKey);
  }
  
  // User Data Management
  static Future<void> saveUser(Map<String, dynamic> userData) async {
    await _prefs.setString(AppConfig.userKey, jsonEncode(userData));
  }
  
  static Future<Map<String, dynamic>?> getUser() async {
    final userString = _prefs.getString(AppConfig.userKey);
    if (userString != null) {
      return jsonDecode(userString);
    }
    return null;
  }
  
  static Future<void> clearUser() async {
    await _prefs.remove(AppConfig.userKey);
  }
  
  // Language Management
  static Future<void> saveLanguage(String language) async {
    await _prefs.setString(AppConfig.languageKey, language);
  }
  
  static Future<String> getLanguage() async {
    return _prefs.getString(AppConfig.languageKey) ?? AppConfig.defaultLanguage;
  }
  
  // Theme Management
  static Future<void> saveTheme(String theme) async {
    await _prefs.setString(AppConfig.themeKey, theme);
  }
  
  static Future<String?> getTheme() async {
    return _prefs.getString(AppConfig.themeKey);
  }
  
  // Location Management
  static Future<void> saveLocation(Map<String, dynamic> location) async {
    await _prefs.setString(AppConfig.locationKey, jsonEncode(location));
  }
  
  static Future<Map<String, dynamic>?> getLocation() async {
    final locationString = _prefs.getString(AppConfig.locationKey);
    if (locationString != null) {
      return jsonDecode(locationString);
    }
    return null;
  }
  
  // Generic Methods for SharedPreferences
  static Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }
  
  static String? getString(String key) {
    return _prefs.getString(key);
  }
  
  static Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }
  
  static int? getInt(String key) {
    return _prefs.getInt(key);
  }
  
  static Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }
  
  static bool? getBool(String key) {
    return _prefs.getBool(key);
  }
  
  static Future<void> setDouble(String key, double value) async {
    await _prefs.setDouble(key, value);
  }
  
  static double? getDouble(String key) {
    return _prefs.getDouble(key);
  }
  
  static Future<void> setStringList(String key, List<String> value) async {
    await _prefs.setStringList(key, value);
  }
  
  static List<String>? getStringList(String key) {
    return _prefs.getStringList(key);
  }
  
  static Future<void> remove(String key) async {
    await _prefs.remove(key);
  }
  
  static bool containsKey(String key) {
    return _prefs.containsKey(key);
  }
  
  // Hive Methods for Complex Data
  static Future<void> putHive(String key, dynamic value) async {
    await _hiveBox.put(key, value);
  }
  
  static T? getHive<T>(String key) {
    return _hiveBox.get(key);
  }
  
  static Future<void> deleteHive(String key) async {
    await _hiveBox.delete(key);
  }
  
  static bool containsKeyHive(String key) {
    return _hiveBox.containsKey(key);
  }
  
  // Cache Management
  static Future<void> cacheData(String key, Map<String, dynamic> data, {Duration? expiry}) async {
    final cacheItem = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiry': expiry?.inMilliseconds,
    };
    await putHive(key, cacheItem);
  }
  
  static Map<String, dynamic>? getCachedData(String key) {
    final cacheItem = getHive<Map>(key);
    if (cacheItem == null) return null;
    
    final timestamp = cacheItem['timestamp'] as int;
    final expiry = cacheItem['expiry'] as int?;
    
    if (expiry != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - timestamp > expiry) {
        deleteHive(key); // Remove expired cache
        return null;
      }
    }
    
    return Map<String, dynamic>.from(cacheItem['data']);
  }
  
  // Clear all data
  static Future<void> clearAll() async {
    await _prefs.clear();
    await _hiveBox.clear();
  }
  
  // App Settings
  static Future<void> saveAppSettings(Map<String, dynamic> settings) async {
    await putHive('app_settings', settings);
  }
  
  static Map<String, dynamic>? getAppSettings() {
    final settings = getHive<Map>('app_settings');
    return settings != null ? Map<String, dynamic>.from(settings) : null;
  }
  
  // Search History
  static Future<void> addSearchHistory(String query) async {
    List<String> history = getStringList('search_history') ?? [];
    
    // Remove if already exists
    history.remove(query);
    
    // Add to beginning
    history.insert(0, query);
    
    // Keep only last 10 searches
    if (history.length > 10) {
      history = history.take(10).toList();
    }
    
    await setStringList('search_history', history);
  }
  
  static List<String> getSearchHistory() {
    return getStringList('search_history') ?? [];
  }
  
  static Future<void> clearSearchHistory() async {
    await remove('search_history');
  }
  
  // Recent Doctors
  static Future<void> addRecentDoctor(Map<String, dynamic> doctor) async {
    List<Map<String, dynamic>> recent = getRecentDoctors();
    
    // Remove if already exists
    recent.removeWhere((d) => d['id'] == doctor['id']);
    
    // Add to beginning
    recent.insert(0, doctor);
    
    // Keep only last 5
    if (recent.length > 5) {
      recent = recent.take(5).toList();
    }
    
    await putHive('recent_doctors', recent);
  }
  
  static List<Map<String, dynamic>> getRecentDoctors() {
    final recent = getHive<List>('recent_doctors');
    if (recent != null) {
      return recent.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }
  
  // Favorite Doctors
  static Future<void> addFavoriteDoctor(String doctorId) async {
    List<String> favorites = getFavoriteDoctors();
    if (!favorites.contains(doctorId)) {
      favorites.add(doctorId);
      await setStringList('favorite_doctors', favorites);
    }
  }
  
  static Future<void> removeFavoriteDoctor(String doctorId) async {
    List<String> favorites = getFavoriteDoctors();
    favorites.remove(doctorId);
    await setStringList('favorite_doctors', favorites);
  }
  
  static List<String> getFavoriteDoctors() {
    return getStringList('favorite_doctors') ?? [];
  }
  
  static bool isFavoriteDoctor(String doctorId) {
    return getFavoriteDoctors().contains(doctorId);
  }
}
