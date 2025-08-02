import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../models/patient_model.dart';

class DoctorPatientsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<PatientModel> _patients = [];
  List<PatientModel> _filteredPatients = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  // Getters
  List<PatientModel> get patients => _filteredPatients;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalPatients => _patients.length;
  String get searchQuery => _searchQuery;

  // Charger les patients du médecin
  Future<void> loadPatients() async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.get('/doctors/me/patients');
      
      if (response.isSuccess && response.data != null) {
        final List<dynamic> patientsData = response.data['patients'] ?? [];
        _patients = patientsData.map((data) => PatientModel.fromJson(data)).toList();
        _applySearchFilter();
      } else {
        _setError(response.message ?? 'Erreur lors du chargement des patients');
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Rechercher des patients
  void searchPatients(String query) {
    _searchQuery = query.toLowerCase().trim();
    _applySearchFilter();
    notifyListeners();
  }

  // Appliquer le filtre de recherche
  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredPatients = List.from(_patients);
    } else {
      _filteredPatients = _patients.where((patient) {
        final fullName = patient.fullName.toLowerCase();
        final phone = patient.phone?.toLowerCase() ?? '';
        final email = patient.email?.toLowerCase() ?? '';
        
        return fullName.contains(_searchQuery) ||
               phone.contains(_searchQuery) ||
               email.contains(_searchQuery);
      }).toList();
    }
  }

  // Obtenir un patient par ID
  PatientModel? getPatientById(String id) {
    try {
      return _patients.firstWhere((patient) => patient.id == id);
    } catch (e) {
      return null;
    }
  }

  // Obtenir les statistiques des patients
  Map<String, int> getPatientStats() {
    int newPatients = 0;
    int regularPatients = 0;

    for (final patient in _patients) {
      if (patient.totalAppointments == 1) {
        newPatients++;
      } else if (patient.totalAppointments > 1) {
        regularPatients++;
      }
    }

    return {
      'total': _patients.length,
      'new': newPatients,
      'regular': regularPatients,
    };
  }

  // Rafraîchir les données
  Future<void> refresh() async {
    await loadPatients();
  }

  // Méthodes utilitaires privées
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
  }

  // Nettoyer les données
  void clear() {
    _patients.clear();
    _filteredPatients.clear();
    _searchQuery = '';
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
