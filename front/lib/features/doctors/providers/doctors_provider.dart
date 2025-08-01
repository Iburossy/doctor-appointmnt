import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../models/doctor_model.dart';

class DoctorsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  final List<DoctorModel> _doctors = [];
  List<DoctorModel> _searchResults = [];
  DoctorModel? _selectedDoctor;
  bool _isLoading = false;
  bool _isSearching = false;
  String? _error;
  String _searchQuery = '';
  Map<String, dynamic> _searchFilters = {};

  // Getters
  List<DoctorModel> get doctors => _doctors;
  List<DoctorModel> get searchResults => _searchResults;
  DoctorModel? get selectedDoctor => _selectedDoctor;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  Map<String, dynamic> get searchFilters => _searchFilters;
  bool get hasSearchResults => _searchResults.isNotEmpty;

  // Search doctors
  Future<void> searchDoctors({
    String? query,
    String? specialization,
    double? latitude,
    double? longitude,
    double? radius,
    bool? isAvailable,
    String? sortBy,
  }) async {
    _setSearching(true);
    _clearError();
    
    try {
      final params = <String, dynamic>{};
      
      if (query != null && query.isNotEmpty) {
        params['search'] = query;
        _searchQuery = query;
      }
      
      if (specialization != null && specialization.isNotEmpty) {
        params['specialization'] = specialization;
      }
      
      if (latitude != null && longitude != null) {
        params['latitude'] = latitude;
        params['longitude'] = longitude;
      }
      
      if (radius != null) {
        params['radius'] = radius;
      }
      
      if (isAvailable != null) {
        params['isAvailable'] = isAvailable;
      }
      
      if (sortBy != null) {
        params['sortBy'] = sortBy;
      }
      
      _searchFilters = Map.from(params);
      
      final response = await _apiService.get('/doctors/search', queryParameters: params);
      
      if (response.isSuccess && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;
        final List<dynamic> doctorsData = responseData['doctors'] ?? [];
        _searchResults = doctorsData
            .map((json) {
              // Fusion des données du médecin et des infos du médecin
              // Le backend utilise parfois un format où certaines infos du médecin
              // sont stockées dans un sous-objet 'doctor'
              final Map<String, dynamic> processedJson = Map<String, dynamic>.from(json);
              if (processedJson.containsKey('doctor') && processedJson['doctor'] is Map) {
                final doctorInfo = processedJson['doctor'] as Map;
                // Fusionner les informations du médecin dans l'objet principal
                doctorInfo.forEach((key, value) {
                  if (!processedJson.containsKey(key)) {
                    processedJson[key] = value;
                  }
                });
              }
              return DoctorModel.fromJson(processedJson);
            })
            .toList();
      } else {
        _setError(response.message ?? 'Erreur lors de la recherche');
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
    } finally {
      _setSearching(false);
    }
  }

  // Get doctor details
  Future<DoctorModel?> getDoctorDetails(String doctorId) async {
    _setLoading(true);
    _clearError();
    
    try {
      final response = await _apiService.get('/doctors/$doctorId');
      
      if (response.isSuccess && response.data != null) {
        final doctorData = response.data;
        // Pré-traitement des données du médecin pour gérer les différentes structures
        final Map<String, dynamic> processedData = 
            (doctorData is Map<String, dynamic>) 
            ? Map<String, dynamic>.from(doctorData)
            : <String, dynamic>{};
            
        // Fusionner les données du sous-objet doctor si elles existent
        if (processedData.containsKey('doctor') && processedData['doctor'] is Map) {
          final doctorInfo = processedData['doctor'] as Map;
          doctorInfo.forEach((key, value) {
            if (!processedData.containsKey(key)) {
              processedData[key] = value;
            }
          });
        }
        
        // S'assurer que l'id est correctement transmis
        if (!processedData.containsKey('id') && processedData.containsKey('_id')) {
          processedData['id'] = processedData['_id'];
        }
        
        _selectedDoctor = DoctorModel.fromJson(processedData);
        notifyListeners();
        return _selectedDoctor;
      } else {
        _setError(response.message ?? 'Médecin non trouvé');
        return null;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Get nearby doctors
  Future<void> getNearbyDoctors({
    required double latitude,
    required double longitude,
    double radius = 10.0,
  }) async {
    await searchDoctors(
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      sortBy: 'distance',
    );
  }

  // Get doctors by specialization
  Future<void> getDoctorsBySpecialization(String specialization) async {
    await searchDoctors(
      specialization: specialization,
      sortBy: 'rating',
    );
  }

  // Get available doctors
  Future<void> getAvailableDoctors() async {
    await searchDoctors(
      isAvailable: true,
      sortBy: 'rating',
    );
  }

  // Clear search results
  void clearSearch() {
    _searchResults.clear();
    _searchQuery = '';
    _searchFilters.clear();
    _clearError();
    notifyListeners();
  }

  // Refresh search with current filters
  Future<void> refreshSearch() async {
    if (_searchFilters.isNotEmpty) {
      await searchDoctors(
        query: _searchFilters['search'],
        specialization: _searchFilters['specialization'],
        latitude: _searchFilters['latitude'],
        longitude: _searchFilters['longitude'],
        radius: _searchFilters['radius'],
        isAvailable: _searchFilters['isAvailable'],
        sortBy: _searchFilters['sortBy'],
      );
    }
  }

  // Get doctor availability
  Future<Map<String, dynamic>?> getDoctorAvailability(String doctorId) async {
    try {
      final response = await _apiService.get('/doctors/$doctorId/availability');
      
      if (response.isSuccess) {
        return response.data;
      } else {
        _setError(response.message ?? 'Erreur lors de la récupération des disponibilités');
        return null;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return null;
    }
  }

  // Filter doctors by rating
  List<DoctorModel> filterByRating(double minRating) {
    return _searchResults.where((doctor) => doctor.rating >= minRating).toList();
  }

  // Filter doctors by distance
  List<DoctorModel> filterByDistance(double maxDistance) {
    return _searchResults.where((doctor) => 
        doctor.distance != null && doctor.distance! <= maxDistance).toList();
  }

  // Sort doctors
  void sortDoctors(String sortBy) {
    switch (sortBy) {
      case 'rating':
        _searchResults.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'distance':
        _searchResults.sort((a, b) {
          if (a.distance == null && b.distance == null) return 0;
          if (a.distance == null) return 1;
          if (b.distance == null) return -1;
          return a.distance!.compareTo(b.distance!);
        });
        break;
      case 'experience':
        _searchResults.sort((a, b) => 
            (b.experienceYears ?? 0).compareTo(a.experienceYears ?? 0));
        break;
      case 'price':
        _searchResults.sort((a, b) {
          if (a.consultationFee == null && b.consultationFee == null) return 0;
          if (a.consultationFee == null) return 1;
          if (b.consultationFee == null) return -1;
          return a.consultationFee!.compareTo(b.consultationFee!);
        });
        break;
      default:
        break;
    }
    notifyListeners();
  }

  // Get specializations list
  List<String> getSpecializations() {
    final specializations = <String>{};
    for (final doctor in _searchResults) {
      if (doctor.specialization != null) {
        specializations.add(doctor.specialization!);
      }
    }
    return specializations.toList()..sort();
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setSearching(bool searching) {
    _isSearching = searching;
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

  // Clear selected doctor
  void clearSelectedDoctor() {
    _selectedDoctor = null;
    notifyListeners();
  }

  // Add doctor to favorites (placeholder)
  Future<bool> addToFavorites(String doctorId) async {
    // TODO: Implement favorites functionality
    return true;
  }

  // Remove doctor from favorites (placeholder)
  Future<bool> removeFromFavorites(String doctorId) async {
    // TODO: Implement favorites functionality
    return true;
  }

  // Get statistics
  Map<String, dynamic> getSearchStatistics() {
    return {
      'totalResults': _searchResults.length,
      'averageRating': _searchResults.isEmpty 
          ? 0.0 
          : _searchResults.map((d) => d.rating).reduce((a, b) => a + b) / _searchResults.length,
      'specializations': getSpecializations().length,
      'availableDoctors': _searchResults.where((d) => d.isAvailable).length,
    };
  }
}
