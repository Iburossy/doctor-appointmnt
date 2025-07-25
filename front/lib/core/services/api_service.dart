import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import 'storage_service.dart';

class ApiService {
  late Dio _dio;
  
  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: Duration(milliseconds: AppConfig.connectionTimeout),
      receiveTimeout: Duration(milliseconds: AppConfig.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    _setupInterceptors();
  }
  
  void _setupInterceptors() {
    // Request Interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add auth token if available
        final token = await StorageService.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        
        if (kDebugMode) {
          print('🚀 REQUEST: ${options.method} ${options.path}');
          print('📤 Headers: ${options.headers}');
          if (options.data != null) {
            print('📦 Data: ${options.data}');
          }
        }
        
        handler.next(options);
      },
      
      onResponse: (response, handler) {
        if (kDebugMode) {
          print('✅ RESPONSE: ${response.statusCode} ${response.requestOptions.path}');
          print('📥 Data: ${response.data}');
        }
        handler.next(response);
      },
      
      onError: (error, handler) {
        if (kDebugMode) {
          print('❌ ERROR: ${error.response?.statusCode} ${error.requestOptions.path}');
          print('💥 Message: ${error.message}');
          print('📄 Response: ${error.response?.data}');
        }
        
        // Handle token expiration
        if (error.response?.statusCode == 401) {
          _handleUnauthorized();
        }
        
        handler.next(error);
      },
    ));
  }
  
  void _handleUnauthorized() async {
    await StorageService.clearToken();
    await StorageService.clearUser();
    // TODO: Navigate to login screen
  }
  
  // Generic GET request
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParameters,
      );
      
      return ApiResponse<T>.success(
        data: fromJson != null ? fromJson(response.data) : response.data,
        message: response.data['message'],
      );
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }
  
  // Generic POST request
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.post(
        endpoint,
        data: data,
      );
      
      return ApiResponse<T>.success(
        data: fromJson != null ? fromJson(response.data) : response.data,
        message: response.data['message'],
      );
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }
  
  // Generic PUT request
  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.put(
        endpoint,
        data: data,
      );
      
      return ApiResponse<T>.success(
        data: fromJson != null ? fromJson(response.data) : response.data,
        message: response.data['message'],
      );
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }
  
  // Generic DELETE request
  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.delete(endpoint);
      
      return ApiResponse<T>.success(
        data: fromJson != null ? fromJson(response.data) : response.data,
        message: response.data['message'],
      );
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }
  
  // File upload
  Future<ApiResponse<T>> uploadFile<T>(
    String endpoint,
    File file, {
    String fieldName = 'file',
    Map<String, dynamic>? additionalData,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final formData = FormData();
      
      // Add file
      formData.files.add(MapEntry(
        fieldName,
        await MultipartFile.fromFile(file.path),
      ));
      
      // Add additional data
      if (additionalData != null) {
        additionalData.forEach((key, value) {
          formData.fields.add(MapEntry(key, value.toString()));
        });
      }
      
      final response = await _dio.post(
        endpoint,
        data: formData,
      );
      
      return ApiResponse<T>.success(
        data: fromJson != null ? fromJson(response.data) : response.data,
        message: response.data['message'],
      );
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }
  
  // Error handler
  ApiResponse<T> _handleError<T>(DioException error) {
    String message = 'Une erreur est survenue';
    List<String>? details;
    
    if (error.response != null) {
      final responseData = error.response!.data;
      
      if (responseData is Map<String, dynamic>) {
        message = responseData['error'] ?? message;
        
        if (responseData['details'] is List) {
          details = List<String>.from(
            responseData['details'].map((detail) => 
              detail is Map ? detail['msg'] ?? detail.toString() : detail.toString()
            )
          );
        }
      }
      
      switch (error.response!.statusCode) {
        case 400:
          message = responseData['error'] ?? 'Données invalides';
          break;
        case 401:
          message = 'Session expirée. Veuillez vous reconnecter';
          break;
        case 403:
          message = 'Accès refusé';
          break;
        case 404:
          message = 'Ressource non trouvée';
          break;
        case 429:
          message = 'Trop de requêtes. Veuillez patienter';
          break;
        case 500:
          message = 'Erreur serveur. Veuillez réessayer plus tard';
          break;
      }
    } else if (error.type == DioExceptionType.connectionTimeout) {
      message = 'Délai de connexion dépassé';
    } else if (error.type == DioExceptionType.receiveTimeout) {
      message = 'Délai de réception dépassé';
    } else if (error.type == DioExceptionType.unknown) {
      message = 'Vérifiez votre connexion internet';
    }
    
    return ApiResponse<T>.error(
      message: message,
      details: details,
    );
  }
}

// API Response wrapper
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final List<String>? details;
  
  ApiResponse._({
    required this.success,
    this.data,
    this.message,
    this.details,
  });
  
  factory ApiResponse.success({
    T? data,
    String? message,
  }) {
    return ApiResponse._(
      success: true,
      data: data,
      message: message,
    );
  }
  
  factory ApiResponse.error({
    required String message,
    List<String>? details,
  }) {
    return ApiResponse._(
      success: false,
      message: message,
      details: details,
    );
  }
  
  bool get isSuccess => success;
  bool get isError => !success;
}
