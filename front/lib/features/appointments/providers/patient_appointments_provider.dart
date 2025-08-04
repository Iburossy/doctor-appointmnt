import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../models/appointment_model.dart';

class PatientAppointmentsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<AppointmentModel> _appointments = [];
  bool _isLoading = false;
  String? _error;

  List<AppointmentModel> get appointments => _appointments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool _hasBeenLoaded = false; // Flag pour optimiser le chargement

  /// Charger tous les rendez-vous du patient connecté
  Future<void> loadPatientAppointments({bool forceRefresh = false}) async {
    // Si les données ont déjà été chargées et qu'on ne force pas le refresh, on ne fait rien.
    if (_hasBeenLoaded && !forceRefresh) {
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      final response = await _apiService.get('/appointments/patient/my-appointments');
      
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
        
        _hasBeenLoaded = true; // Marquer comme chargé
        debugPrint('Successfully loaded ${_appointments.length} patient appointments.');

      } else {
        _setError('Impossible de charger les rendez-vous');
        debugPrint('Failed to load patient appointments: ${response.message}');
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      debugPrint('Exception loading patient appointments: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Annuler un rendez-vous
  Future<bool> cancelAppointment(String appointmentId) async {
    try {
      final response = await _apiService.put(
        '/appointments/$appointmentId/status',
        data: {'status': 'cancelled'},
      );

      if (response.isSuccess) {
        // Mettre à jour localement
        final index = _appointments.indexWhere((apt) => apt.id == appointmentId);
        if (index != -1) {
          _appointments[index] = _appointments[index].copyWith(status: 'cancelled');
          notifyListeners();
        }
        return true;
      } else {
        _setError('Impossible d\'annuler le rendez-vous');
        return false;
      }
    } catch (e) {
      _setError('Erreur lors de l\'annulation: $e');
      return false;
    }
  }

  /// Obtenir les rendez-vous par statut
  List<AppointmentModel> getAppointmentsByStatus(String status) {
    return _appointments.where((appointment) => appointment.status == status).toList();
  }

  /// Obtenir les rendez-vous à venir (confirmés et en attente)
  List<AppointmentModel> getUpcomingAppointments() {
    final now = DateTime.now();
    return _appointments.where((appointment) => 
      (appointment.status == 'confirmed' || appointment.status == 'pending') && 
      appointment.appointmentDate.isAfter(now)
    ).toList();
  }

  /// Obtenir les rendez-vous passés (terminés ou annulés)
  AppointmentModel? _selectedAppointment;
  AppointmentModel? get selectedAppointment => _selectedAppointment;

  /// Récupérer les détails d'un rendez-vous spécifique
  Future<bool> getAppointmentDetails(String appointmentId) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await _apiService.get('/appointments/$appointmentId');

      if (response.isSuccess && response.data != null) {
        final appointmentData = response.data['appointment'] as Map<String, dynamic>?;
        if (appointmentData != null) {
          _selectedAppointment = AppointmentModel.fromJson(appointmentData);
          debugPrint('Successfully loaded details for appointment $appointmentId');
          _setLoading(false);
          return true;
        } else {
          _setError('Les données du rendez-vous sont invalides.');
          _setLoading(false);
          return false;
        }
      } else {
        _setError('Impossible de charger les détails du rendez-vous: ${response.message}');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      debugPrint('Exception loading appointment details: $e');
      _setLoading(false);
      return false;
    }
  }

  List<AppointmentModel> getPastAppointments() {
    final now = DateTime.now();
    return _appointments.where((appointment) => 
      appointment.status == 'completed' || 
      appointment.status == 'cancelled' ||
      (appointment.appointmentDate.isBefore(now) && appointment.status != 'pending')
    ).toList();
  }
  
  /// Méthode privée pour mettre à jour l'état de chargement
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Méthode privée pour mettre à jour l'erreur
  void _setError(String? errorMessage) {
    _error = errorMessage;
    if (errorMessage != null) {
      debugPrint('Error in PatientAppointmentsProvider: $errorMessage');
    }
    notifyListeners();
  }
}
