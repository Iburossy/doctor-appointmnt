import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Helper pour la gestion du stockage local
class StorageHelper {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _settingsKey = 'app_settings';

  // ==================== GESTION DU TOKEN ====================

  /// Sauvegarde le token d'authentification
  static Future<bool> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_tokenKey, token);
    } catch (e) {
      print('❌ Erreur sauvegarde token: $e');
      return false;
    }
  }

  /// Récupère le token d'authentification
  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      print('❌ Erreur récupération token: $e');
      return null;
    }
  }

  /// Supprime le token d'authentification
  static Future<bool> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_tokenKey);
    } catch (e) {
      print('❌ Erreur suppression token: $e');
      return false;
    }
  }

  /// Vérifie si un token existe
  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ==================== GESTION DES DONNÉES UTILISATEUR ====================

  /// Sauvegarde les données utilisateur
  static Future<bool> saveUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(userData);
      return await prefs.setString(_userKey, jsonString);
    } catch (e) {
      print('❌ Erreur sauvegarde données utilisateur: $e');
      return false;
    }
  }

  /// Récupère les données utilisateur
  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_userKey);
      if (jsonString != null) {
        return json.decode(jsonString) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('❌ Erreur récupération données utilisateur: $e');
      return null;
    }
  }

  /// Supprime les données utilisateur
  static Future<bool> clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_userKey);
    } catch (e) {
      print('❌ Erreur suppression données utilisateur: $e');
      return false;
    }
  }

  // ==================== GESTION DES PARAMÈTRES ====================

  /// Sauvegarde les paramètres de l'application
  static Future<bool> saveSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(settings);
      return await prefs.setString(_settingsKey, jsonString);
    } catch (e) {
      print('❌ Erreur sauvegarde paramètres: $e');
      return false;
    }
  }

  /// Récupère les paramètres de l'application
  static Future<Map<String, dynamic>?> getSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_settingsKey);
      if (jsonString != null) {
        return json.decode(jsonString) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('❌ Erreur récupération paramètres: $e');
      return null;
    }
  }

  /// Met à jour un paramètre spécifique
  static Future<bool> updateSetting(String key, dynamic value) async {
    try {
      final currentSettings = await getSettings() ?? <String, dynamic>{};
      currentSettings[key] = value;
      return await saveSettings(currentSettings);
    } catch (e) {
      print('❌ Erreur mise à jour paramètre: $e');
      return false;
    }
  }

  /// Récupère un paramètre spécifique
  static Future<T?> getSetting<T>(String key, [T? defaultValue]) async {
    try {
      final settings = await getSettings();
      return settings?[key] as T? ?? defaultValue;
    } catch (e) {
      print('❌ Erreur récupération paramètre: $e');
      return defaultValue;
    }
  }

  // ==================== GESTION GÉNÉRALE ====================

  /// Supprime toutes les données stockées
  static Future<bool> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.clear();
    } catch (e) {
      print('❌ Erreur suppression toutes données: $e');
      return false;
    }
  }

  /// Supprime seulement les données d'authentification
  static Future<bool> clearAuthData() async {
    try {
      final tokenCleared = await clearToken();
      final userDataCleared = await clearUserData();
      return tokenCleared && userDataCleared;
    } catch (e) {
      print('❌ Erreur suppression données auth: $e');
      return false;
    }
  }

  // ==================== MÉTHODES UTILITAIRES ====================

  /// Vérifie si l'utilisateur est connecté
  static Future<bool> isLoggedIn() async {
    final hasToken = await StorageHelper.hasToken();
    final userData = await getUserData();
    return hasToken && userData != null;
  }

  /// Obtient la taille totale des données stockées (approximative)
  static Future<int> getStorageSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      int totalSize = 0;
      
      for (String key in keys) {
        final value = prefs.get(key);
        if (value is String) {
          totalSize += value.length;
        }
      }
      
      return totalSize;
    } catch (e) {
      print('❌ Erreur calcul taille stockage: $e');
      return 0;
    }
  }

  /// Liste toutes les clés stockées (pour debug)
  static Future<Set<String>> getAllKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getKeys();
    } catch (e) {
      print('❌ Erreur récupération clés: $e');
      return <String>{};
    }
  }

  /// Affiche les informations de debug sur le stockage
  static Future<void> printDebugInfo() async {
    try {
      final keys = await getAllKeys();
      final size = await getStorageSize();
      final isLoggedIn = await StorageHelper.isLoggedIn();
      
      print('\n💾 === INFORMATIONS STOCKAGE ===');
      print('🔐 Utilisateur connecté: $isLoggedIn');
      print('🔑 Nombre de clés: ${keys.length}');
      print('📊 Taille approximative: ${size} octets');
      print('🗝️ Clés: ${keys.join(', ')}');
      print('💾 === FIN INFORMATIONS STOCKAGE ===\n');
    } catch (e) {
      print('❌ Erreur affichage debug stockage: $e');
    }
  }
}
