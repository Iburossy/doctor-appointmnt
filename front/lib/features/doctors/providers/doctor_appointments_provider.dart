import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../../appointments/models/appointment_model.dart';

class DoctorAppointmentsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<AppointmentModel> _appointments = [];
  bool _isLoading = false;
  String? _error;

  List<AppointmentModel> get appointments => _appointments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool _hasBeenLoaded = false; // Flag pour optimiser le chargement

  /// Charger tous les rendez-vous du médecin connecté
  Future<void> loadDoctorAppointments({bool forceRefresh = false}) async {
    // Si les données ont déjà été chargées et qu'on ne force pas le refresh, on ne fait rien.
    if (_hasBeenLoaded && !forceRefresh) {
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      final response = await _apiService.get('/appointments/doctor/my-appointments');
      
      if (response.isSuccess && response.data != null) {
        final appointmentsData = response.data['appointments'] as List<dynamic>? ?? [];
        _appointments = appointmentsData.map((appointmentJson) {
          try {
            return AppointmentModel.fromJson(appointmentJson as Map<String, dynamic>);
          } catch (e) {
            // Log discret en cas d'erreur de parsing
            debugPrint('Could not parse an appointment: $e');
            return null;
          }
        }).where((appointment) => appointment != null).cast<AppointmentModel>().toList();
        
        // Tri d'abord par date de création (plus récent en haut)
        _appointments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        // Si besoin d'un tri secondaire par date de rendez-vous
        // _appointments.sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
        _hasBeenLoaded = true; // Marquer comme chargé
        debugPrint('Successfully loaded ${_appointments.length} appointments.');

      } else {
        _setError('Impossible de charger les rendez-vous');
        debugPrint('Failed to load appointments: ${response.message}');
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      debugPrint('Exception loading appointments: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Mettre à jour le statut d'un rendez-vous
  Future<void> updateAppointmentStatus(String appointmentId, String newStatus) async {
    try {

      
      final response = await _apiService.put(
        '/appointments/$appointmentId/status',
        data: {'status': newStatus},
      );

      if (response.isSuccess) {
        // Mettre à jour localement
        final index = _appointments.indexWhere((apt) => apt.id == appointmentId);
        if (index != -1) {
          _appointments[index] = _appointments[index].copyWith(status: newStatus);
          notifyListeners();
        }
        

      } else {
        _setError('Impossible de mettre à jour le rendez-vous');

      }
    } catch (e) {
      _setError('Erreur lors de la mise à jour: $e');

    }
  }

  /// Obtenir les rendez-vous par statut
  List<AppointmentModel> getAppointmentsByStatus(String status) {
    return _appointments.where((appointment) => appointment.status == status).toList();
  }

  /// Obtenir les rendez-vous d'aujourd'hui
  List<AppointmentModel> getTodayAppointments() {
    final today = DateTime.now();
    return _appointments.where((appointment) {
      return appointment.appointmentDate.year == today.year &&
             appointment.appointmentDate.month == today.month &&
             appointment.appointmentDate.day == today.day;
    }).toList();
  }

  /// Obtenir les rendez-vous de cette semaine
  List<AppointmentModel> getThisWeekAppointments() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    return _appointments.where((appointment) {
      return appointment.appointmentDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
             appointment.appointmentDate.isBefore(endOfWeek.add(const Duration(days: 1)));
    }).toList();
  }

  /// Obtenir les statistiques des rendez-vous
  Map<String, int> getAppointmentStats() {
    final stats = <String, int>{
      'total': _appointments.length,
      'pending': 0,
      'confirmed': 0,
      'cancelled': 0,
      'completed': 0,
    };

    for (final appointment in _appointments) {
      stats[appointment.status] = (stats[appointment.status] ?? 0) + 1;
    }

    return stats;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    if (error != null) {
      notifyListeners();
    }
  }

  /// Nettoyer les données
  void clear() {
    _appointments.clear();
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
