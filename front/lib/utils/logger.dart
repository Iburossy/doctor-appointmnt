import 'package:flutter/foundation.dart';

/// Utilitaire de logging pour l'application
class Logger {
  /// Active ou désactive les logs
  static bool enableLogging = true;

  /// Log un message d'information
  static void log(String message) {
    if (enableLogging) {
      debugPrint('📝 $message');
    }
  }

  /// Log un message de succès
  static void success(String message) {
    if (enableLogging) {
      debugPrint('✅ $message');
    }
  }

  /// Log un message d'erreur
  static void error(String message) {
    if (enableLogging) {
      debugPrint('❌ $message');
    }
  }

  /// Log un message d'avertissement
  static void warning(String message) {
    if (enableLogging) {
      debugPrint('⚠️ $message');
    }
  }

  /// Log un message de débogage
  static void debug(String message) {
    if (enableLogging && kDebugMode) {
      debugPrint('🔍 $message');
    }
  }

  /// Log une requête HTTP
  static void request(String method, String path, {dynamic data}) {
    if (enableLogging) {
      debugPrint('🚀 REQUEST: $method $path');
      if (data != null) {
        debugPrint('📤 Data: $data');
      }
    }
  }

  /// Log une réponse HTTP
  static void response(int? statusCode, String path, {dynamic data}) {
    if (enableLogging) {
      debugPrint('✅ RESPONSE: $statusCode $path');
      if (data != null) {
        debugPrint('📥 Data: $data');
      }
    }
  }

  /// Log une erreur HTTP
  static void httpError(int? statusCode, String? path, String message, {dynamic data}) {
    if (enableLogging) {
      debugPrint('❌ ERROR: $statusCode $path');
      debugPrint('💥 Message: $message');
      if (data != null) {
        debugPrint('📄 Error Data: $data');
      }
    }
  }
}
