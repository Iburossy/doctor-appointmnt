import 'package:flutter/material.dart';
import '../models/doctor_stats_model.dart';
import '../services/doctor_stats_service.dart';

class DoctorStatsProvider with ChangeNotifier {
  final DoctorStatsService _statsService = DoctorStatsService();
  
  DoctorStatsModel? _stats;
  bool _isLoading = false;
  String? _error;

  DoctorStatsModel? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Charge les statistiques du médecin depuis l'API
  Future<void> loadDoctorStats() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final stats = await _statsService.getDoctorStats();
      _stats = stats;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('Erreur chargement stats: $_error');
    }
  }
}
