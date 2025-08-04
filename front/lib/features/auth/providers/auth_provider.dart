import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  // Mécanisme anti-boucle infinie
  DateTime? _lastRefreshTime;
  static const _minimumRefreshInterval = Duration(seconds: 3); // empêcher les rafraîchissements fréquents
  late final ApiService _apiService;
  
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;
  bool _isOnboarded = false;
  bool _isInitialized = false;
  
  // Getters
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;
  bool get isOnboarded => _isOnboarded;
  bool get isInitialized => _isInitialized;
  bool get isDoctor => _user?.role == 'doctor';
  bool get isPatient => _user?.role == 'patient';
  
  // Constructor
  AuthProvider() {
    _apiService = ApiService(onUnauthorized: logout);
    // Auto-initialisation sans splash screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initialize();
    });
  }
  
  // Méthode publique pour déclencher la notification
  void triggerNotification() {
    notifyListeners();
  }
  
  // Initialize auth state
  Future<void> initialize() async {
    if (_isInitialized) return; // Empêcher les initialisations multiples
    
    // Démarrer le loading sans notifier immédiatement
    _isLoading = true;
    
    try {
      // Check if user is onboarded
      _isOnboarded = StorageService.getBool('onboarded') ?? false;
      
      // Check if user has valid token
      final token = StorageService.getString('auth_token');
      
      if (token != null && token.isNotEmpty) {
        // Verify token and get user data
        await _getCurrentUser();
      } else {
        _isAuthenticated = false;
      }
    } catch (e) {
      _error = 'Erreur d\'initialisation: $e';
      await logout(); // Clear invalid session
    } finally {
      _isLoading = false;
      _isInitialized = true; // Marquer comme initialisé pour éviter les boucles
      notifyListeners();
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
        // Sauvegarder les données d'authentification
        if (response.data != null && response.data['token'] != null) {
          // Sauvegarder le token et les données utilisateur
          await _saveAuthData(response.data);
          // Utilisateur connecté mais pas vérifié
          _isAuthenticated = true;
          notifyListeners();
        }
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
        
        // Vérifier si l'utilisateur est un médecin et recharger son profil
        if (_user?.role == 'doctor') {
          notifyListeners();
        }
        
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
  
  Future<void> _getCurrentUser({bool forceFullRefresh = false}) async {
    try {
      final response = await _apiService.get(
        '/auth/me', 
        queryParameters: forceFullRefresh ? {'_nocache': DateTime.now().millisecondsSinceEpoch.toString()} : null
      );
      
      if (response.isSuccess && response.data != null) {
        final userData = response.data['user'] as Map<String, dynamic>;
        try {
          
          // Gestion spéciale pour les profils médecin avec structure différente
          if (userData['role'] == 'doctor' && userData.containsKey('doctorProfile')) {
            // Le backend peut renvoyer une structure différente pour doctorProfile
            // On laisse UserModel.fromJson gérer la conversion avec gestion d'erreur
          }
          
          _user = UserModel.fromJson(userData);
          // print('DEBUG: UserModel created successfully');
          // print('DEBUG: Parsed user data:');
          // print('  - Phone: ${_user?.phone}');
          // print('  - Email: ${_user?.email}');
          // print('  - Role: ${_user?.role}');
          // print('  - DateOfBirth: ${_user?.dateOfBirth}');
          // print('  - Gender: ${_user?.gender}');
          // print('  - Address: ${_user?.address}');
          // print('  - Avatar: ${_user?.profilePicture}');
          if (_user?.role == 'doctor') {
            
          }
          _isAuthenticated = true;
          // Ne pas notifier ici, sera fait par la méthode appelante
        } catch (e) {
          
          // Pour les erreurs de parsing des profils médecin, on essaie de continuer
          // avec les données de base si possible
          if (userData['role'] == 'doctor') {
            try {
              // Créer un utilisateur de base sans le profil médecin problématique
              final basicUserData = Map<String, dynamic>.from(userData);
              basicUserData.remove('doctorProfile'); // Supprimer le profil problématique
              _user = UserModel.fromJson(basicUserData);
              _isAuthenticated = true;
              // Ne pas notifier ici, sera fait par la méthode appelante
              return; // Sortir de la méthode avec succès partiel
            } catch (e2) {
            }
          }
          
          throw Exception('Erreur de parsing des données utilisateur: $e');
        }
      } else {
        throw Exception('Invalid user data');
      }
    } catch (e) {
      // Au lieu de déconnecter l'utilisateur, on garde les données de base
      // et on définit juste _isAuthenticated à true si l'utilisateur a déjà un token
      if (_user == null && StorageService.getString('auth_token') != null) {
        _isAuthenticated = true;
        // Ne pas notifier ici, sera fait par la méthode appelante
      }
      // On ne propage pas l'erreur pour éviter d'autres problèmes
    }
  }
  
  // Refresh user data with improved role synchronization
  Future<void> refreshUser({bool forceFullRefresh = false}) async {
    if (_isAuthenticated) {
      // Vérifier si un rafraîchissement a été effectué récemment
      final now = DateTime.now();
      if (_lastRefreshTime != null) {
        final timeSinceLastRefresh = now.difference(_lastRefreshTime!);
        if (timeSinceLastRefresh < _minimumRefreshInterval) {
          return; // Ignorer cette requête de rafraîchissement
        }
      }
      
      // Mettre à jour le timestamp du dernier rafraîchissement
      _lastRefreshTime = now;
      _setLoading(true);
      
      try {
        if (forceFullRefresh) {
          await _getCurrentUser(forceFullRefresh: true);
          return;
        }
        
        // Vérifier d'abord explicitement le rôle actuel via l'endpoint dédié
        final roleCheck = await _apiService.checkCurrentRole();
        if (roleCheck.isSuccess && roleCheck.data != null) {
          final serverRole = roleCheck.data['role'];
          final localRole = _user?.role;
          
          if (serverRole != localRole) {
            await _getCurrentUser(forceFullRefresh: true);
            return;
          }
        }
        
        // Récupération normale des données utilisateur
        await _getCurrentUser();
      } catch (e) {
        if (kDebugMode) {
          print('Error refreshing user: $e');
        }
      } finally {
        _setLoading(false);
      }
    }
  }
  
  // Vérifier explicitement le rôle utilisateur depuis le serveur
  Future<String?> checkCurrentRole() async {
    try {
      final response = await _apiService.checkCurrentRole();
      if (response.isSuccess && response.data != null) {
        return response.data['role'];
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking role: $e');
      }
      return null;
    }
  }
  
  // Update user profile - supports both Map and named parameters
  Future<bool> updateUserProfile({
    // Paramètres pour l'appel avec Map
    Map<String, dynamic>? data,
    File? avatar,
    // Paramètres nommés pour la compatibilité avec l'ancien code
    String? firstName,
    String? lastName,
    String? email,
    DateTime? dateOfBirth,
    String? gender,
    String? address,
    String? street,
    String? city,
    File? avatarFile,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Construire les données du profil à partir des paramètres nommés ou du Map
      final Map<String, dynamic> profileData = data ?? {};
      
      // Ajouter les paramètres nommés s'ils sont fournis
      if (firstName != null) profileData['firstName'] = firstName;
      if (lastName != null) profileData['lastName'] = lastName;
      if (email != null) profileData['email'] = email;
      if (dateOfBirth != null) profileData['dateOfBirth'] = dateOfBirth.toIso8601String();
      if (gender != null) profileData['gender'] = gender;
      
      // Gérer l'adresse correctement
      print('🏠 FRONTEND - Paramètres d\'adresse reçus:');
      print('  - address: $address');
      print('  - street: $street');
      print('  - city: $city');
      
      if (address != null) {
        // Ancien format - chaîne simple
        profileData['address'] = {'street': address};
        print('🏠 FRONTEND - Utilisation ancien format address: ${profileData['address']}');
      } else if ((street != null || city != null) || 
                (profileData.containsKey('street') || profileData.containsKey('city'))) {
        // Nouveau format - objet avec street et city
        final addressObj = {
          'street': street ?? profileData.remove('street'),
          'city': city ?? profileData.remove('city'),
        };
        print('🏠 FRONTEND - Objet adresse avant nettoyage: $addressObj');
        // Supprimer les valeurs nulles ou vides
        addressObj.removeWhere((key, value) => value == null || value.toString().isEmpty);
        if (addressObj.isNotEmpty) {
          profileData['address'] = addressObj;
          print('🏠 FRONTEND - Objet adresse final: ${profileData['address']}');
        } else {
          print('🏠 FRONTEND - Objet adresse vide, non ajouté');
        }
      }
      
      print('🚀 FRONTEND - Données finales à envoyer: $profileData');

      // Étape 1: Mettre à jour les informations textuelles
      if (profileData.isNotEmpty) {
        final response = await _apiService.put('/users/profile', data: profileData);
        if (!response.isSuccess) {
          _error = response.message ?? 'Erreur lors de la mise à jour du profil';
          return false;
        }
      }

      // Étape 2: Mettre à jour la photo de profil si une nouvelle est fournie
      final fileToUpload = avatar ?? avatarFile;
      if (fileToUpload != null) {
        final avatarResponse = await _apiService.uploadFile(
          '/users/upload-avatar',
          fileToUpload,
          fieldName: 'avatar'
        );
        if (!avatarResponse.isSuccess) {
          _error = avatarResponse.message ?? 'Erreur lors de l\'upload de l\'avatar';
          return false;
        }
      }

      // Étape 3: Recharger les données de l'utilisateur pour mettre à jour l'interface
      await _getCurrentUser();
      return true;

    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
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
    
    // Avec JWT, pas besoin d'appel API pour la déconnexion
    // Il suffit de supprimer le token côté client
    
    try {
      // Clear local data
      await StorageService.clearToken();
      await StorageService.clearUser();
      await NotificationService.cancelAllNotifications();
      
      // Déterminer si l'utilisateur était un médecin avant déconnexion
      final wasDoctor = _user?.role == 'doctor';
      
      _user = null;
      _isAuthenticated = false;
      _clearError();
      
      // Publier une notification pour que DoctorProfileProvider puisse réagir
      
    } catch (e) {
      if (kDebugMode) {
        print('Error during logout cleanup: $e');
      }
    } finally {
      _setLoading(false);
      notifyListeners();
    }
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
    try {
      _isLoading = true;
      notifyListeners(); // Informe l'UI qu'un chargement est en cours

      final String token = data['token'];
      final Map<String, dynamic> userJson = data['user'];

      // 1. Sauvegarde du token et des données utilisateur
      await StorageService.saveToken(token.toString());
      await StorageService.saveUser(userJson);
      // Le token est déjà sauvegardé et sera utilisé automatiquement par les intercepteurs de Dio

      // 2. Création de l'objet User de base
      _user = UserModel.fromJson(userJson);
      _isAuthenticated = true;

      // 3. Attendre le chargement du profil spécifique (médecin ou patient)
      // Cela garantit que le rôle et les données associées sont entièrement chargés.
      // Chargement du profil spécifique en fonction du rôle
      if (_user!.role == 'doctor') {
        try {
          // Attendre explicitement le chargement du profil médecin
          // Cette requête doit être complétée avant de notifier les écouteurs
          final response = await _apiService.get('/doctors/profile');
          if (response.isSuccess && response.data != null) {
            // Le profil médecin est maintenant disponible
          } else {
          }
        } catch (e) {
          // Ne pas échouer complètement si le profil ne peut pas être chargé
        }
      } else if (_user!.role == 'patient') {
        try {
          // Attendre explicitement le chargement du profil patient
          final response = await _apiService.get('/patients/profile');
          if (response.isSuccess && response.data != null) {
            // Le profil patient est maintenant disponible
          } else {
          }
        } catch (e) {
          // Ne pas échouer complètement si le profil ne peut pas être chargé
        }
      }
      
      // 4. Initialisation des services post-authentification
      await NotificationService.init();
      await NotificationService.requestPermissions();

    } catch (e) {
      _setError('Erreur lors de la sauvegarde des données: $e');
      await logout(); // En cas d'erreur, déconnecter pour éviter un état incohérent
    } finally {
      _isLoading = false;
      // 6. Notifier les listeners SEULEMENT à la fin de tout le processus.
      // GoRouter va maintenant se déclencher avec l'état complet et correct.
      notifyListeners();
    }
  }
  


  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String? error) {
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
  
  // Refresh user data
  Future<void> refreshUserData() async {
    if (_isAuthenticated) {
      await _getCurrentUser(forceFullRefresh: true);
      notifyListeners();
    }
  }
}
