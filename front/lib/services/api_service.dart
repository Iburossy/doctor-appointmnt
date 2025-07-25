import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import '../config/app_config.dart';
import '../models/user.dart';
import '../models/doctor.dart';
import '../utils/storage_helper.dart';
import '../utils/logger.dart';

/// Service API principal pour toutes les communications avec le backend
class ApiService {
  static ApiService? _instance;
  static ApiService get instance => _instance ??= ApiService._internal();
  
  late Dio _dio;
  final AppConfig _config = AppConfig.instance;
  
  ApiService._internal() {
    _initializeDio();
  }

  /// Initialise la configuration Dio
  void _initializeDio() {
    _dio = Dio(BaseOptions(
      baseUrl: _config.apiBaseUrl,
      connectTimeout: Duration(milliseconds: _config.apiTimeout),
      receiveTimeout: Duration(milliseconds: _config.apiTimeout),
      sendTimeout: Duration(milliseconds: _config.apiTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Intercepteurs pour les logs et l'authentification
    _dio.interceptors.add(_createLoggingInterceptor());
    _dio.interceptors.add(_createAuthInterceptor());
    _dio.interceptors.add(_createErrorInterceptor());
  }

  /// Intercepteur pour les logs (uniquement en mode debug)
  Interceptor _createLoggingInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_config.enableLogging) {
          Logger.request(options.method, options.path);
          Logger.log('Headers: ${options.headers}');
          if (options.data != null && options.data is! FormData) {
            Logger.log('Data: ${options.data}');
          } else if (options.data is FormData) {
            Logger.log('Data: FormData avec ${(options.data as FormData).files.length} fichier(s)');
          }
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (_config.enableLogging) {
          Logger.response(response.statusCode, response.requestOptions.path, data: response.data);
        }
        handler.next(response);
      },
      onError: (error, handler) {
        if (_config.enableLogging) {
          Logger.httpError(error.response?.statusCode, error.requestOptions.path, error.message ?? 'Unknown error', data: error.response?.data);
        }
        handler.next(error);
      },
    );
  }

  /// Intercepteur pour l'authentification automatique
  Interceptor _createAuthInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Ajouter le token d'authentification si disponible
        final token = await StorageHelper.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    );
  }

  /// Intercepteur pour la gestion des erreurs
  Interceptor _createErrorInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) async {
        // Gestion des erreurs 401 (non autorisé)
        if (error.response?.statusCode == 401) {
          await _handleUnauthorized();
        }
        handler.next(error);
      },
    );
  }

  /// Gère les erreurs d'authentification
  Future<void> _handleUnauthorized() async {
    if (_config.enableLogging) {
      // print('🔐 Token expiré ou invalide, déconnexion...');
    }
    await StorageHelper.clearToken();
    // TODO: Rediriger vers la page de connexion
  }

  // ==================== MÉTHODES D'AUTHENTIFICATION ====================

  /// Connexion utilisateur
  Future<ApiResponse<User>> login(String phone, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'phone': phone,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          // Sauvegarder le token
          await StorageHelper.saveToken(data['token']);
          
          // Créer l'objet User
          final user = User.fromJson(data['user']);
          
          return ApiResponse.success(user, data['message']);
        } else {
          return ApiResponse.error(data['error'] ?? 'Erreur de connexion');
        }
      } else {
        return ApiResponse.error('Erreur de connexion: ${response.statusCode}');
      }
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Erreur inattendue: $e');
    }
  }

  /// Inscription utilisateur
  Future<ApiResponse<User>> register(Map<String, dynamic> userData) async {
    try {
      final response = await _dio.post('/auth/register', data: userData);

      if (response.statusCode == 201) {
        final data = response.data;
        if (data['success'] == true) {
          final user = User.fromJson(data['user']);
          return ApiResponse.success(user, data['message']);
        } else {
          return ApiResponse.error(data['error'] ?? 'Erreur d\'inscription');
        }
      } else {
        return ApiResponse.error('Erreur d\'inscription: ${response.statusCode}');
      }
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Erreur inattendue: $e');
    }
  }

  /// Déconnexion
  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (e) {
      if (_config.enableLogging) {
        // print('⚠️ Erreur lors de la déconnexion: $e');
      }
    } finally {
      await StorageHelper.clearToken();
    }
  }

  // ==================== MÉTHODES MÉDECIN ====================

  /// Demande d'upgrade vers médecin (sans fichiers)
  Future<ApiResponse<Doctor>> requestDoctorUpgrade(Map<String, dynamic> doctorData) async {
    try {
      final response = await _dio.post('/doctors/upgrade', data: doctorData);

      if (response.statusCode == 201) {
        final data = response.data;
        final doctor = Doctor.fromJson(data['doctor'] ?? data['request'] ?? {});
        return ApiResponse.success(doctor, data['message']);
      } else {
        return ApiResponse.error('Erreur lors de la demande: ${response.statusCode}');
      }
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Erreur inattendue: $e');
    }
  }
  
  /// Demande d'upgrade vers médecin avec fichiers (en une seule requête)
  Future<ApiResponse<Doctor>> requestDoctorUpgradeWithFiles({
    required Map<String, dynamic> doctorData,
    required Map<String, File> files,
    Function(int, int)? onProgress,
  }) async {
    try {
      // Vérifications des fichiers
      for (final entry in files.entries) {
        final file = entry.value;
        if (!_config.isFileSizeAllowed(await file.length())) {
          return ApiResponse.error(
            'Fichier ${entry.key} trop volumineux. Taille maximale: ${_config.maxFileSizeMB.toStringAsFixed(1)}MB'
          );
        }
        
        final extension = file.path.split('.').last;
        if (!_config.isFileTypeAllowed(extension)) {
          return ApiResponse.error(
            'Type de fichier ${entry.key} non autorisé. Types acceptés: ${_config.allowedFileTypes.join(', ')}'
          );
        }
      }
      
      // Création du FormData
      final formData = FormData();
      
      // 1. Ajouter les données JSON dans un champ 'data'
      formData.fields.add(MapEntry('data', jsonEncode(doctorData)));
      
      // 2. Ajouter chaque fichier avec son type MIME correct
      for (final entry in files.entries) {
        final file = entry.value;
        final String mimeType = _getMimeType(file.path);
        
        formData.files.add(
          MapEntry(
            entry.key,
            await MultipartFile.fromFile(
              file.path,
              filename: file.path.split('/').last,
              contentType: MediaType.parse(mimeType),
            ),
          ),
        );
      }
      
      if (_config.enableLogging) {
        Logger.log('📄 Upload de ${files.length} fichiers avec données JSON');
      }
      
      // Envoi de la requête
      final response = await _dio.post(
        '/doctors/upgrade',
        data: formData,
        onSendProgress: onProgress,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );
      
      if (response.statusCode == 201) {
        final data = response.data;
        final doctor = Doctor.fromJson(data['doctor'] ?? data['request'] ?? {});
        return ApiResponse.success(doctor, data['message']);
      } else {
        return ApiResponse.error('Erreur lors de la demande: ${response.statusCode}');
      }
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Erreur inattendue: $e');
    }
  }

  /// Upload d'un document pour un médecin
  Future<ApiResponse<Map<String, dynamic>>> uploadDoctorDocument({
    required String doctorId,
    required File file,
    required String documentType,
    Function(int, int)? onProgress,
  }) async {
    try {
      // Vérifications de sécurité
      if (!_config.isFileSizeAllowed(await file.length())) {
        return ApiResponse.error(
          'Fichier trop volumineux. Taille maximale: ${_config.maxFileSizeMB.toStringAsFixed(1)}MB'
        );
      }

      final extension = file.path.split('.').last;
      if (!_config.isFileTypeAllowed(extension)) {
        return ApiResponse.error(
          'Type de fichier non autorisé. Types acceptés: ${_config.allowedFileTypes.join(', ')}'
        );
      }

      // Préparation du FormData avec type MIME explicite
      final String mimeType = _getMimeType(file.path);
      
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
          contentType: MediaType.parse(mimeType),
        ),
        'documentType': documentType,
      });
      
      if (_config.enableLogging) {
        // print('📄 Upload avec type MIME: $mimeType');
      }

      // Upload avec suivi de progression
      final response = await _dio.post(
        '/upload/doctor/$doctorId/documents',
        data: formData,
        onSendProgress: onProgress,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return ApiResponse.success(data['data'], data['message']);
        } else {
          return ApiResponse.error(data['error'] ?? 'Erreur lors de l\'upload');
        }
      } else {
        return ApiResponse.error('Erreur d\'upload: ${response.statusCode}');
      }
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Erreur inattendue: $e');
    }
  }

  /// Upload multiple de documents
  Future<List<ApiResponse<Map<String, dynamic>>>> uploadMultipleDoctorDocuments({
    required String doctorId,
    required List<FileUpload> files,
    Function(int, int)? onProgress,
  }) async {
    final results = <ApiResponse<Map<String, dynamic>>>[];
    
    for (int i = 0; i < files.length; i++) {
      final fileUpload = files[i];
      
      if (_config.enableLogging) {
        // print('📤 Upload ${i + 1}/${files.length}: ${fileUpload.file.path}');
      }
      
      final result = await uploadDoctorDocument(
        doctorId: doctorId,
        file: fileUpload.file,
        documentType: fileUpload.documentType,
        onProgress: (sent, total) {
          // Calcul de la progression globale
          final fileProgress = (sent / total);
          final globalProgress = ((i + fileProgress) / files.length);
          onProgress?.call((globalProgress * 100).round(), 100);
        },
      );
      
      results.add(result);
      
      // Arrêter en cas d'erreur critique
      if (!result.success && fileUpload.isRequired) {
        break;
      }
    }
    
    return results;
  }

  // ==================== MÉTHODES UTILITAIRES ====================

  /// Gère les erreurs Dio et retourne un message d'erreur approprié
  String _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Délai d\'attente dépassé. Vérifiez votre connexion internet.';
      
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final message = error.response?.data?['error'] ?? error.response?.data?['message'];
        
        switch (statusCode) {
          case 400:
            return message ?? 'Données invalides';
          case 401:
            return 'Non autorisé. Veuillez vous reconnecter.';
          case 403:
            return 'Accès interdit';
          case 404:
            return 'Ressource non trouvée';
          case 500:
            return message ?? 'Erreur serveur. Veuillez réessayer plus tard.';
          default:
            return message ?? 'Erreur de communication avec le serveur';
        }
      
      case DioExceptionType.cancel:
        return 'Requête annulée';
        
      case DioExceptionType.badCertificate:
        return 'Certificat de sécurité invalide';
        
      case DioExceptionType.connectionError:
        return 'Erreur de connexion. Vérifiez votre connexion internet.';
      
      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          return 'Pas de connexion internet';
        }
        return 'Erreur de communication: ${error.message}';
    }
  }

  /// Détermine le type MIME d'un fichier en fonction de son extension
  String _getMimeType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    
    // Map des extensions vers les types MIME
    final mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    };
    
    // Utiliser le package mime si disponible, sinon utiliser notre map
    final mimeType = lookupMimeType(filePath) ?? mimeTypes[extension] ?? 'application/octet-stream';
    
    // Pour les images, toujours forcer image/jpeg ou image/png
    if (extension == 'jpg' || extension == 'jpeg') {
      return 'image/jpeg';
    } else if (extension == 'png') {
      return 'image/png';
    }
    
    return mimeType;
  }
  
  /// Obtient les informations de configuration pour debug
  Map<String, dynamic> getDebugInfo() {
    return {
      'baseUrl': _config.apiBaseUrl,
      'timeout': _config.apiTimeout,
      'environment': _config.environment,
      'maxFileSize': _config.maxFileSizeMB,
      'allowedTypes': _config.allowedFileTypes,
    };
  }
}

// ==================== CLASSES DE SUPPORT ====================

/// Classe pour encapsuler les réponses API
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? error;

  ApiResponse.success(this.data, [this.message]) : success = true, error = null;
  ApiResponse.error(this.error) : success = false, data = null, message = null;
}

/// Classe pour les uploads de fichiers
class FileUpload {
  final File file;
  final String documentType;
  final bool isRequired;

  FileUpload({
    required this.file,
    required this.documentType,
    this.isRequired = false,
  });
}
