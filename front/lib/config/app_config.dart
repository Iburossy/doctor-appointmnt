import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service de configuration de l'application
/// Gère les variables d'environnement et la configuration globale
class AppConfig {
  static AppConfig? _instance;
  static AppConfig get instance => _instance ??= AppConfig._internal();
  
  AppConfig._internal();

  /// Initialise la configuration en chargeant le fichier d'environnement approprié
  static Future<void> initialize({String? environment}) async {
    try {
      String envFile = '.env';
      
      // Détermine le fichier d'environnement à charger
      if (environment != null) {
        envFile = '.env.$environment';
      } else {
        // Détection automatique basée sur le mode de compilation
        const bool isProduction = bool.fromEnvironment('dart.vm.product');
        envFile = isProduction ? '.env.production' : '.env.development';
      }
      
      // print('🔧 Chargement de la configuration: $envFile');
      await dotenv.load(fileName: envFile);
      // print('✅ Configuration chargée avec succès');
      
      // Validation des variables critiques
      _validateConfiguration();
      
    } catch (e) {
      // print('❌ Erreur lors du chargement de la configuration: $e');
      // Fallback vers .env par défaut
      try {
        await dotenv.load(fileName: '.env');
        // print('⚠️ Utilisation de la configuration par défaut');
      } catch (fallbackError) {
        // print('❌ Impossible de charger la configuration par défaut: $fallbackError');
        rethrow;
      }
    }
  }

  /// Valide que les variables d'environnement critiques sont présentes
  static void _validateConfiguration() {
    final requiredVars = [
      'APP_NAME',
      'API_BASE_URL',
      'ENVIRONMENT'
    ];
    
    for (String varName in requiredVars) {
      if (!dotenv.env.containsKey(varName) || dotenv.env[varName]!.isEmpty) {
        throw Exception('Variable d\'environnement manquante: $varName');
      }
    }
    
    // print('✅ Validation de la configuration réussie');
  }

  // ==================== CONFIGURATION GÉNÉRALE ====================
  
  /// Nom de l'application
  String get appName => dotenv.env['APP_NAME'] ?? 'Doctors App';
  
  /// Version de l'application
  String get appVersion => dotenv.env['APP_VERSION'] ?? '1.0.0';
  
  /// Environnement actuel (development, production)
  String get environment => dotenv.env['ENVIRONMENT'] ?? 'development';
  
  /// Indique si l'application est en mode développement
  bool get isDevelopment => environment == 'development';
  
  /// Indique si l'application est en mode production
  bool get isProduction => environment == 'production';

  // ==================== CONFIGURATION API ====================
  
  /// URL de base de l'API
  String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5000/api';
  
  /// Timeout des requêtes API en millisecondes
  int get apiTimeout => int.tryParse(dotenv.env['API_TIMEOUT'] ?? '30000') ?? 30000;
  
  /// URL complète pour une route API
  String getApiUrl(String endpoint) {
    final baseUrl = apiBaseUrl.endsWith('/') ? apiBaseUrl.substring(0, apiBaseUrl.length - 1) : apiBaseUrl;
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return '$baseUrl$cleanEndpoint';
  }

  // ==================== CONFIGURATION UPLOAD ====================
  
  /// Taille maximale des fichiers en octets
  int get maxFileSize => int.tryParse(dotenv.env['MAX_FILE_SIZE'] ?? '10485760') ?? 10485760;
  
  /// Taille maximale des fichiers en MB (pour affichage)
  double get maxFileSizeMB => maxFileSize / (1024 * 1024);
  
  /// Types de fichiers autorisés
  List<String> get allowedFileTypes => 
      (dotenv.env['ALLOWED_FILE_TYPES'] ?? 'jpg,jpeg,png,pdf,doc,docx')
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .toList();
  
  /// Nombre maximum de fichiers par upload
  int get maxFilesPerUpload => int.tryParse(dotenv.env['MAX_FILES_PER_UPLOAD'] ?? '5') ?? 5;
  
  /// Vérifie si un type de fichier est autorisé
  bool isFileTypeAllowed(String extension) {
    return allowedFileTypes.contains(extension.toLowerCase().replaceAll('.', ''));
  }
  
  /// Vérifie si la taille du fichier est autorisée
  bool isFileSizeAllowed(int sizeInBytes) {
    return sizeInBytes <= maxFileSize;
  }

  // ==================== CONFIGURATION FEATURES ====================
  
  /// Active/désactive les logs
  bool get enableLogging => dotenv.env['ENABLE_LOGGING']?.toLowerCase() == 'true';
  
  /// Active/désactive le mode debug
  bool get enableDebugMode => dotenv.env['ENABLE_DEBUG_MODE']?.toLowerCase() == 'true';
  
  /// Active/désactive le reporting de crash
  bool get enableCrashReporting => dotenv.env['ENABLE_CRASH_REPORTING']?.toLowerCase() == 'true';

  // ==================== CONFIGURATION UI ====================
  
  /// Langue par défaut
  String get defaultLanguage => dotenv.env['DEFAULT_LANGUAGE'] ?? 'fr';
  
  /// Langues supportées
  List<String> get supportedLanguages => 
      (dotenv.env['SUPPORTED_LANGUAGES'] ?? 'fr,wo,ar')
          .split(',')
          .map((e) => e.trim())
          .toList();

  // ==================== CONFIGURATION CACHE ====================
  
  /// Durée de cache par défaut en millisecondes
  int get cacheDuration => int.tryParse(dotenv.env['CACHE_DURATION'] ?? '3600000') ?? 3600000;
  
  /// Durée de cache des images en millisecondes
  int get imageCacheDuration => int.tryParse(dotenv.env['IMAGE_CACHE_DURATION'] ?? '86400000') ?? 86400000;

  // ==================== CONFIGURATION NOTIFICATIONS ====================
  
  /// Active/désactive les notifications push
  bool get enablePushNotifications => dotenv.env['ENABLE_PUSH_NOTIFICATIONS']?.toLowerCase() == 'true';
  
  /// Son de notification par défaut
  String get notificationSound => dotenv.env['NOTIFICATION_SOUND'] ?? 'default';

  // ==================== MÉTHODES UTILITAIRES ====================
  
  /// Affiche la configuration actuelle (pour debug)
  void printConfiguration() {
    if (!enableDebugMode) return;
    
    // print('\n🔧 === CONFIGURATION ACTUELLE ===');
    // print('📱 App: $appName v$appVersion');
    // print('🌍 Environnement: $environment');
    // print('🌐 API Base URL: $apiBaseUrl');
    // print('⏱️ API Timeout: ${apiTimeout}ms');
    // print('📁 Taille max fichier: ${maxFileSizeMB.toStringAsFixed(1)}MB');
    // print('📄 Types autorisés: ${allowedFileTypes.join(', ')}');
    // print('🔢 Max fichiers/upload: $maxFilesPerUpload');
    // print('🗣️ Langue par défaut: $defaultLanguage');
    // print('🌐 Langues supportées: ${supportedLanguages.join(', ')}');
    // print('📝 Logs activés: $enableLogging');
    // print('🐛 Debug activé: $enableDebugMode');
    // print('💥 Crash reporting: $enableCrashReporting');
    // print('🔔 Notifications: $enablePushNotifications');
    // print('🔧 === FIN CONFIGURATION ===\n');
  }
  
  /// Obtient une variable d'environnement personnalisée
  String? getCustomVar(String key, [String? defaultValue]) {
    return dotenv.env[key] ?? defaultValue;
  }
  
  /// Vérifie si une variable d'environnement existe
  bool hasVar(String key) {
    return dotenv.env.containsKey(key) && dotenv.env[key]!.isNotEmpty;
  }
}
