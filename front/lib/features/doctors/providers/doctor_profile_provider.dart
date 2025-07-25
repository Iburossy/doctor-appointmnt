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
      final response = await _apiService.get('/doctors/profile');
      
      if (response.isSuccess && response.data != null) {
        _doctorProfile = DoctorProfile.fromJson(response.data);
        notifyListeners();
        return true;
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
      final data = <String, dynamic>{};
      
      if (specialization != null) data['specialization'] = specialization;
      if (licenseNumber != null) data['licenseNumber'] = licenseNumber;
      if (experienceYears != null) data['experienceYears'] = experienceYears;
      if (education != null) data['education'] = education;
      if (bio != null) data['bio'] = bio;
      if (languages != null) data['languages'] = languages;
      if (consultationFee != null) data['consultationFee'] = consultationFee;
      if (clinicInfo != null) data['clinicInfo'] = clinicInfo.toJson();
      if (workingHours != null) {
        data['workingHours'] = workingHours.map((wh) => wh.toJson()).toList();
      }

      final response = await _apiService.put('/doctors/profile', data: data);
      
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

  // Refresh profile
  Future<bool> refreshProfile() async {
    return await getDoctorProfile();
  }

  // Check if profile is complete
  bool get isProfileComplete {
    if (_doctorProfile == null) return false;
    
    return _doctorProfile!.specialization != null &&
           _doctorProfile!.licenseNumber != null &&
           _doctorProfile!.experienceYears != null &&
           _doctorProfile!.education != null &&
           _doctorProfile!.clinicInfo != null &&
           _doctorProfile!.workingHours.isNotEmpty;
  }

  // Get completion percentage
  double get profileCompletionPercentage {
    if (_doctorProfile == null) return 0.0;
    
    int completedFields = 0;
    int totalFields = 8;
    
    if (_doctorProfile!.specialization != null) completedFields++;
    if (_doctorProfile!.licenseNumber != null) completedFields++;
    if (_doctorProfile!.experienceYears != null) completedFields++;
    if (_doctorProfile!.education != null) completedFields++;
    if (_doctorProfile!.bio != null && _doctorProfile!.bio!.isNotEmpty) completedFields++;
    if (_doctorProfile!.languages.isNotEmpty) completedFields++;
    if (_doctorProfile!.clinicInfo != null) completedFields++;
    if (_doctorProfile!.workingHours.isNotEmpty) completedFields++;
    
    return completedFields / totalFields;
  }
}
