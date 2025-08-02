import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../../auth/models/user_model.dart';

class DoctorProfileProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  DoctorProfile? _doctorProfile;
  bool _isLoading = false;
  bool _isUpdating = false;
  String? _error;

  // Getters
  DoctorProfile? get doctorProfile => _doctorProfile;
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get error => _error;

  // Get current doctor profile
  Future<bool> getDoctorProfile() async {

    _setLoading(true);
    _clearError();
    
    try {
      // Ajouter un timestamp pour éviter le cache
      final response = await _apiService.get(
        '/doctors/profile', 
        queryParameters: {'_ts': DateTime.now().millisecondsSinceEpoch.toString()}
      );
      

      
      if (response.isSuccess && response.data != null) {
        try {

          _doctorProfile = DoctorProfile.fromJson(response.data);

          
          notifyListeners();
          return true;
        } catch (parseError) {

          _setError('Erreur lors du traitement des données du profil: $parseError');
          return false;
        }
      } else {

        _setError(response.message ?? 'Erreur lors de la récupération du profil');
        return false;
      }
    } catch (e) {

      _setError('Erreur de connexion: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update doctor profile
  Future<bool> updateDoctorProfile({
    String? specialization,
    String? licenseNumber,
    int? experienceYears,
    String? education,
    String? bio,
    List<String>? languages,
    double? consultationFee,
    ClinicInfo? clinicInfo,
    List<WorkingHours>? workingHours,
  }) async {
    _setUpdating(true);
    _clearError();
    
    try {
      // Adapter les noms des champs pour correspondre à ceux attendus par le backend
      final data = <String, dynamic>{};
      
      // Champs avec noms différents entre backend et frontend
      if (experienceYears != null) data['yearsOfExperience'] = experienceYears; // backend: yearsOfExperience, frontend: experienceYears
      
      // Conversion spéciale pour ClinicInfo : user_model.dart vers backend format
      if (clinicInfo != null) {
        // Convertir le format simple de user_model.dart vers le format attendu par le backend
        data['clinic'] = {
          'name': clinicInfo.name,
          'address': {
            'street': clinicInfo.address, // Utiliser l'adresse complète comme street
            'city': 'Dakar', // Valeur par défaut - à améliorer
            'region': 'Dakar', // Valeur par défaut
            'country': 'Sénégal', // Valeur par défaut
            'location': {
              'type': 'Point',
              'coordinates': [-17.4467, 14.6928] // Coordonnées par défaut de Dakar
            }
          },
          'phone': clinicInfo.phone,
          'description': null,
          'photos': []
        };
        // print('📊 Données clinic converties pour le backend: ${data['clinic']}'); // Pour débogage
      }
      
      if (specialization != null) data['specialties'] = [specialization]; // backend: specialties (array), frontend: specialization
      
      // Traitement spécial pour l'education (le backend attend un tableau d'objets)
      if (education != null) {
        // Créons une structure minimale valide pour l'education
        final educationData = [{
          'degree': education,
          'institution': 'Non spécifié',
          'year': DateTime.now().year,
          'country': 'Sénégal'
        }];
        // print('📊 Données education formatées: $educationData'); // Pour débogage
        data['education'] = educationData;
      }
      
      // Champs avec les mêmes noms
      if (licenseNumber != null) data['licenseNumber'] = licenseNumber;
      if (bio != null) data['bio'] = bio;
      if (languages != null) data['languages'] = languages;
      if (consultationFee != null) data['consultationFee'] = consultationFee;
      
      if (workingHours != null) {
        data['workingHours'] = workingHours.map((wh) => wh.toJson()).toList();
      }

      // La route correcte pour la mise à jour du profil n'existe pas dans le backend
      // Nous utilisons temporairement la route /doctors/me pour la mise à jour
      // Ajouter un log pour débugger la requête
      // print('ℹ️ Tentative de mise à jour du profil avec: $data');
      final response = await _apiService.put('/doctors/me', data: data);
      
      if (response.isSuccess && response.data != null) {
        _doctorProfile = DoctorProfile.fromJson(response.data);
        notifyListeners();
        return true;
      } else {
        _setError(response.message ?? 'Erreur lors de la mise à jour du profil');
        return false;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return false;
    } finally {
      _setUpdating(false);
    }
  }

  // Update working hours
  Future<bool> updateWorkingHours(List<WorkingHours> workingHours) async {
    _setUpdating(true);
    _clearError();
    
    try {
      final data = {
        'workingHours': workingHours.map((wh) => wh.toJson()).toList(),
      };

      final response = await _apiService.put('/doctors/profile/working-hours', data: data);
      
      if (response.isSuccess && response.data != null) {
        _doctorProfile = DoctorProfile.fromJson(response.data);
        notifyListeners();
        return true;
      } else {
        _setError(response.message ?? 'Erreur lors de la mise à jour des horaires');
        return false;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return false;
    } finally {
      _setUpdating(false);
    }
  }

  // Update clinic info
  Future<bool> updateClinicInfo(ClinicInfo clinicInfo) async {
    _setUpdating(true);
    _clearError();
    
    try {
      final data = {
        'clinicInfo': clinicInfo.toJson(),
      };

      final response = await _apiService.put('/doctors/profile/clinic', data: data);
      
      if (response.isSuccess && response.data != null) {
        _doctorProfile = DoctorProfile.fromJson(response.data);
        notifyListeners();
        return true;
      } else {
        _setError(response.message ?? 'Erreur lors de la mise à jour du cabinet');
        return false;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return false;
    } finally {
      _setUpdating(false);
    }
  }

  // Update availability status
  Future<bool> updateAvailabilityStatus(bool isAvailable) async {
    _setUpdating(true);
    _clearError();
    
    try {
      final data = {
        'isAvailable': isAvailable,
      };

      final response = await _apiService.put('/doctors/profile/availability', data: data);
      
      if (response.isSuccess && response.data != null) {
        _doctorProfile = DoctorProfile.fromJson(response.data);
        notifyListeners();
        return true;
      } else {
        _setError(response.message ?? 'Erreur lors de la mise à jour de la disponibilité');
        return false;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return false;
    } finally {
      _setUpdating(false);
    }
  }

  // Upload profile avatar
  Future<bool> uploadAvatar(String imagePath) async {
    _setUpdating(true);
    _clearError();
    
    try {
      final file = File(imagePath);
      final response = await _apiService.uploadFile('/doctors/profile/avatar', file);
      
      if (response.isSuccess && response.data != null) {
        // Refresh profile after avatar upload
        await getDoctorProfile();
        return true;
      } else {
        _setError(response.message ?? 'Erreur lors du téléchargement de l\'avatar');
        return false;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return false;
    } finally {
      _setUpdating(false);
    }
  }

  // Get doctor statistics
  Future<Map<String, dynamic>?> getDoctorStatistics() async {
    try {
      final response = await _apiService.get('/doctors/profile/statistics');
      
      if (response.isSuccess && response.data != null) {
        return response.data;
      } else {
        _setError(response.message ?? 'Erreur lors de la récupération des statistiques');
        return null;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return null;
    }
  }

  // Get appointments summary
  Future<Map<String, dynamic>?> getAppointmentsSummary() async {
    try {
      final response = await _apiService.get('/doctors/profile/appointments-summary');
      
      if (response.isSuccess && response.data != null) {
        return response.data;
      } else {
        _setError(response.message ?? 'Erreur lors de la récupération du résumé des rendez-vous');
        return null;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return null;
    }
  }

  // Request profile verification
  Future<bool> requestVerification() async {
    _setUpdating(true);
    _clearError();
    
    try {
      final response = await _apiService.post('/doctors/profile/request-verification');
      
      if (response.isSuccess) {
        // Refresh profile to get updated verification status
        await getDoctorProfile();
        return true;
      } else {
        _setError(response.message ?? 'Erreur lors de la demande de vérification');
        return false;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return false;
    } finally {
      _setUpdating(false);
    }
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setUpdating(bool updating) {
    _isUpdating = updating;
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

  // Clear profile data
  void clearProfile() {

    _doctorProfile = null;
    _clearError();
    notifyListeners();
  }
  
  // Force reload profile - completely clears cache and gets fresh data
  Future<bool> forceReloadProfile() async {

    // Clear current profile data
    _doctorProfile = null;
    // Don't notify listeners yet to avoid UI flickering
    
    // Get fresh profile data with timestamp to avoid any caching
    try {
      final response = await _apiService.get(
        '/doctors/profile', 
        queryParameters: {'_ts': DateTime.now().millisecondsSinceEpoch.toString(), 'nocache': 'true'}
      );
      

      
      if (response.isSuccess && response.data != null) {
        try {

          _doctorProfile = DoctorProfile.fromJson(response.data);

          
          notifyListeners();
          return true;
        } catch (parseError) {

          _setError('Erreur lors du traitement des données du profil: $parseError');
          notifyListeners();
          return false;
        }
      } else {

        _setError(response.message ?? 'Erreur lors de la récupération du profil');
        notifyListeners();
        return false;
      }
    } catch (e) {

      _setError('Erreur de connexion lors du rechargement: $e');
      notifyListeners();
      return false;
    }
  }

  // Refresh profile
  Future<bool> refreshProfile() async {
    return await getDoctorProfile();
  }

  // Check if profile is complete
  bool get isProfileComplete {
    if (_doctorProfile == null) return false;
    
    return _doctorProfile!.specialization != null &&
           _doctorProfile!.medicalLicenseNumber != null &&
           _doctorProfile!.yearsOfExperience != null &&
           _doctorProfile!.education != null &&
           _doctorProfile!.clinic != null &&
           _doctorProfile!.workingHours != null;
  }

  // Get completion percentage
  double get profileCompletionPercentage {
    if (_doctorProfile == null) return 0.0;
    
    int completedFields = 0;
    int totalFields = 8;
    
    if (_doctorProfile!.specialization != null) completedFields++;
    if (_doctorProfile!.medicalLicenseNumber != null) completedFields++;
    if (_doctorProfile!.yearsOfExperience != null) completedFields++;
    if (_doctorProfile!.education != null && _doctorProfile!.education!.isNotEmpty) completedFields++;
    if (_doctorProfile!.clinicDescription != null && _doctorProfile!.clinicDescription!.isNotEmpty) completedFields++;
    if (_doctorProfile!.languages != null && _doctorProfile!.languages!.isNotEmpty) completedFields++;
    if (_doctorProfile!.clinic != null) completedFields++;
    if (_doctorProfile!.workingHours != null) completedFields++;
    
    return completedFields / totalFields;
  }

  // SÉCURITÉ: Fonction pour nettoyer les données sensibles
  Map<String, dynamic> _sanitizeProfileData(Map<String, dynamic> data) {
    final cleanedData = Map<String, dynamic>.from(data);
    
    // Nettoyer le champ education pour supprimer les IDs MongoDB
    if (cleanedData['education'] != null && cleanedData['education'] is List) {
      final List educationList = cleanedData['education'];
      cleanedData['education'] = educationList.map((item) {
        if (item is Map<String, dynamic>) {
          // Garder seulement les champs sûrs, supprimer _id, id, etc.
          return {
            'degree': item['degree']?.toString()?.replaceAll(RegExp(r'[{}\[\]_id:,]'), '')?.trim() ?? '',
            'institution': item['institution']?.toString() ?? '',
            'year': item['year'],
            'country': item['country']?.toString() ?? ''
          };
        }
        return item;
      }).toList();
    }
    
    // Nettoyer d'autres champs potentiellement sensibles
    _removeMongoIds(cleanedData);
    
    return cleanedData;
  }
  
  // Fonction récursive pour supprimer tous les IDs MongoDB
  void _removeMongoIds(dynamic data) {
    if (data is Map<String, dynamic>) {
      data.removeWhere((key, value) => key == '_id' || key == 'id' || key.startsWith('_'));
      data.values.forEach(_removeMongoIds);
    } else if (data is List) {
      data.forEach(_removeMongoIds);
    }
  }
}
