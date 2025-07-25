import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;
  bool _isOnboarded = false;
  
  // Getters
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;
  bool get isOnboarded => _isOnboarded;
  bool get isDoctor => _user?.role == 'doctor';
  bool get isPatient => _user?.role == 'patient';
  
  // Initialize auth state
  Future<void> initialize() async {
    _setLoading(true);
    
    try {
      // Check if user is onboarded
      _isOnboarded = StorageService.getBool('onboarded') ?? false;
      
      // Check if user has valid token
      final token = StorageService.getString('auth_token');
      if (token != null && token.isNotEmpty) {
        // Verify token and get user data
        await _getCurrentUser();
      }
    } catch (e) {
      _setError('Erreur d\'initialisation: $e');
      await logout(); // Clear invalid session
    } finally {
      _setLoading(false);
    }
  }
  
  // Register new user
  Future<bool> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    String? email,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final response = await _apiService.post('/auth/register', data: {
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'password': password,
        if (email != null && email.isNotEmpty) 'email': email,
      });
      
      if (response.isSuccess) {
        // Registration successful, phone verification needed
        return true;
      } else {
        _setError(response.message ?? 'Erreur lors de l\'inscription');
        return false;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Verify phone number with OTP
  Future<bool> verifyPhone({
    required String phone,
    required String code,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final response = await _apiService.post('/auth/verify-phone-registration', data: {
        'phone': phone,
        'code': code,
      });
      
      if (response.isSuccess && response.data != null) {
        // Save auth data
        await _saveAuthData(response.data);
        return true;
      } else {
        _setError(response.message ?? 'Code de vérification invalide');
        return false;
      }
    } catch (e) {
      _setError('Erreur de vérification: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Resend verification code
  Future<bool> resendVerificationCode(String phone) async {
    _setLoading(true);
    _clearError();
    
    try {
      final response = await _apiService.post('/auth/resend-code', data: {
        'phone': phone,
      });
      
      if (response.isSuccess) {
        return true;
      } else {
        _setError(response.message ?? 'Erreur lors de l\'envoi du code');
        return false;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Login user
  Future<bool> login({
    required String phone,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final response = await _apiService.post('/auth/login', data: {
        'phone': phone,
        'password': password,
      });
      
      if (response.isSuccess && response.data != null) {
        await _saveAuthData(response.data);
        return true;
      } else {
        _setError(response.message ?? 'Identifiants incorrects');
        return false;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Forgot password
  Future<bool> forgotPassword(String phone) async {
    _setLoading(true);
    _clearError();
    
    try {
      final response = await _apiService.post('/auth/forgot-password', data: {
        'phone': phone,
      });
      
      if (response.isSuccess) {
        return true;
      } else {
        _setError(response.message ?? 'Erreur lors de l\'envoi du code');
        return false;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Reset password
  Future<bool> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final response = await _apiService.post('/auth/reset-password', data: {
        'phone': phone,
        'code': code,
        'newPassword': newPassword,
      });
      
      if (response.isSuccess) {
        return true;
      } else {
        _setError(response.message ?? 'Erreur lors de la réinitialisation');
        return false;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Get current user data
  Future<void> _getCurrentUser() async {
    try {
      final response = await _apiService.get('/auth/me');
      
      if (response.isSuccess && response.data != null) {
        _user = UserModel.fromJson(response.data);
        _isAuthenticated = true;
        notifyListeners();
      } else {
        throw Exception('Invalid user data');
      }
    } catch (e) {
      await logout();
      rethrow;
    }
  }
  
  // Refresh user data
  Future<void> refreshUser() async {
    if (_isAuthenticated) {
      try {
        await _getCurrentUser();
      } catch (e) {
        if (kDebugMode) {
          print('Error refreshing user: $e');
        }
      }
    }
  }
  
  // Update user profile
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    _setLoading(true);
    _clearError();
    
    try {
      final response = await _apiService.put('/users/profile', data: data);
      
      if (response.isSuccess && response.data != null) {
        _user = UserModel.fromJson(response.data);
        notifyListeners();
        return true;
      } else {
        _setError(response.message ?? 'Erreur lors de la mise à jour');
        return false;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Change password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final response = await _apiService.put('/users/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      
      if (response.isSuccess) {
        return true;
      } else {
        _setError(response.message ?? 'Erreur lors du changement de mot de passe');
        return false;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Logout user
  Future<void> logout() async {
    _setLoading(true);
    
    try {
      // Call logout endpoint if authenticated
      if (_isAuthenticated) {
        await _apiService.post('/auth/logout', data: {});
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during logout: $e');
      }
    }
    
    // Clear local data
    await StorageService.clearToken();
    await StorageService.clearUser();
    await NotificationService.cancelAllNotifications();
    
    _user = null;
    _isAuthenticated = false;
    _clearError();
    _setLoading(false);
    
    notifyListeners();
  }
  
  // Delete account
  Future<bool> deleteAccount() async {
    _setLoading(true);
    _clearError();
    
    try {
      final response = await _apiService.delete('/users/account');
      
      if (response.isSuccess) {
        await logout();
        return true;
      } else {
        _setError(response.message ?? 'Erreur lors de la suppression du compte');
        return false;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Mark onboarding as completed
  void completeOnboarding() {
    _isOnboarded = true;
    StorageService.setBool('onboarded', true);
    notifyListeners();
  }
  
  // Save authentication data
  Future<void> _saveAuthData(Map<String, dynamic> data) async {
    final token = data['token'];
    final userData = data['user'];
    
    if (token != null && userData != null) {
      await StorageService.saveToken(token.toString());
      await StorageService.saveUser(userData);
      
      _user = UserModel.fromJson(userData);
      _isAuthenticated = true;
      
      // Initialize notifications
      await NotificationService.init();
      await NotificationService.requestPermissions();
      
      notifyListeners();
    } else {
      _setError('Données d\'authentification incomplètes');
    }
  }
  
  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }
  
  void _clearError() {
    _error = null;
    notifyListeners();
  }
  
  // Check if user can upgrade to doctor
  bool canUpgradeToDoctor() {
    return _user != null && _user!.role == 'patient';
  }
  
  // Check if user is verified doctor
  bool isVerifiedDoctor() {
    return _user != null && 
           _user!.role == 'doctor' && 
           _user!.doctorProfile?.isVerified == true;
  }
}
