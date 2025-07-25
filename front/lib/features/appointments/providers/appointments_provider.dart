import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/notification_service.dart';
import '../models/appointment_model.dart';

class AppointmentsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<AppointmentModel> _appointments = [];
  List<AppointmentModel> _upcomingAppointments = [];
  List<AppointmentModel> _pastAppointments = [];
  AppointmentModel? _selectedAppointment;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<AppointmentModel> get appointments => _appointments;
  List<AppointmentModel> get upcomingAppointments => _upcomingAppointments;
  List<AppointmentModel> get pastAppointments => _pastAppointments;
  AppointmentModel? get selectedAppointment => _selectedAppointment;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasAppointments => _appointments.isNotEmpty;

  // Load user appointments
  Future<void> loadAppointments() async {
    _setLoading(true);
    _clearError();
    
    try {
      final response = await _apiService.get('/users/appointments');
      
      if (response.isSuccess && response.data != null) {
        final List<dynamic> appointmentsData = response.data ?? [];
        _appointments = appointmentsData
            .map((json) => AppointmentModel.fromJson(json))
            .toList();
        
        _categorizeAppointments();
      } else {
        _setError(response.message ?? 'Erreur lors du chargement des rendez-vous');
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Create new appointment
  Future<bool> createAppointment({
    required String doctorId,
    required DateTime appointmentDate,
    required String timeSlot,
    String? reason,
    String? notes,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final response = await _apiService.post('/appointments', data: {
        'doctorId': doctorId,
        'appointmentDate': appointmentDate.toIso8601String(),
        'timeSlot': timeSlot,
        'reason': reason,
        'notes': notes,
      });
      
      if (response.isSuccess && response.data != null) {
        final appointmentData = response.data;
        final newAppointment = AppointmentModel.fromJson(appointmentData);
        
        _appointments.add(newAppointment);
        _categorizeAppointments();
        
        // Schedule notification reminder
        await _scheduleAppointmentReminder(newAppointment);
        
        return true;
      } else {
        _setError(response.message ?? 'Erreur lors de la création du rendez-vous');
        return false;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Get appointment details
  Future<AppointmentModel?> getAppointmentDetails(String appointmentId) async {
    _setLoading(true);
    _clearError();
    
    try {
      final response = await _apiService.get('/appointments/$appointmentId');
      
      if (response.isSuccess && response.data != null) {
        final appointmentData = response.data;
        _selectedAppointment = AppointmentModel.fromJson(appointmentData);
        notifyListeners();
        return _selectedAppointment;
      } else {
        _setError(response.message ?? 'Rendez-vous non trouvé');
        return null;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Cancel appointment
  Future<bool> cancelAppointment(String appointmentId, {String? reason}) async {
    _setLoading(true);
    _clearError();
    
    try {
      final response = await _apiService.put('/appointments/$appointmentId/cancel', data: {
        'reason': reason,
      });
      
      if (response.isSuccess) {
        // Update local appointment
        final index = _appointments.indexWhere((a) => a.id == appointmentId);
        if (index != -1) {
          _appointments[index] = _appointments[index].copyWith(
            status: 'cancelled',
            cancellationReason: reason,
          );
          _categorizeAppointments();
        }
        
        // Cancel notification
        await NotificationService.cancelNotification(appointmentId.hashCode);
        
        return true;
      } else {
        _setError(response.message ?? 'Erreur lors de l\'annulation');
        return false;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Reschedule appointment
  Future<bool> rescheduleAppointment({
    required String appointmentId,
    required DateTime newDate,
    required String newTimeSlot,
    String? reason,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final response = await _apiService.put('/appointments/$appointmentId/reschedule', data: {
        'newDate': newDate.toIso8601String(),
        'newTimeSlot': newTimeSlot,
        'reason': reason,
      });
      
      if (response.isSuccess) {
        // Update local appointment
        final index = _appointments.indexWhere((a) => a.id == appointmentId);
        if (index != -1) {
          _appointments[index] = _appointments[index].copyWith(
            appointmentDate: newDate,
            timeSlot: newTimeSlot,
          );
          _categorizeAppointments();
          
          // Reschedule notification
          await _scheduleAppointmentReminder(_appointments[index]);
        }
        
        return true;
      } else {
        _setError(response.message ?? 'Erreur lors de la reprogrammation');
        return false;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Confirm appointment (for doctors)
  Future<bool> confirmAppointment(String appointmentId) async {
    _setLoading(true);
    _clearError();
    
    try {
      final response = await _apiService.put('/appointments/$appointmentId/confirm', data: {});
      
      if (response.isSuccess) {
        // Update local appointment
        final index = _appointments.indexWhere((a) => a.id == appointmentId);
        if (index != -1) {
          _appointments[index] = _appointments[index].copyWith(
            status: 'confirmed',
          );
          _categorizeAppointments();
        }
        
        return true;
      } else {
        _setError(response.message ?? 'Erreur lors de la confirmation');
        return false;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Complete appointment (for doctors)
  Future<bool> completeAppointment({
    required String appointmentId,
    String? diagnosis,
    String? prescription,
    String? notes,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final response = await _apiService.put('/appointments/$appointmentId/complete', data: {
        'diagnosis': diagnosis,
        'prescription': prescription,
        'notes': notes,
      });
      
      if (response.isSuccess) {
        // Update local appointment
        final index = _appointments.indexWhere((a) => a.id == appointmentId);
        if (index != -1) {
          _appointments[index] = _appointments[index].copyWith(
            status: 'completed',
            diagnosis: diagnosis,
            prescription: prescription,
            doctorNotes: notes,
          );
          _categorizeAppointments();
        }
        
        return true;
      } else {
        _setError(response.message ?? 'Erreur lors de la finalisation');
        return false;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Add review to appointment
  Future<bool> addReview({
    required String appointmentId,
    required int rating,
    String? comment,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final response = await _apiService.post('/appointments/$appointmentId/review', data: {
        'rating': rating,
        'comment': comment,
      });
      
      if (response.isSuccess) {
        // Update local appointment
        final index = _appointments.indexWhere((a) => a.id == appointmentId);
        if (index != -1) {
          _appointments[index] = _appointments[index].copyWith(
            review: ReviewModel(
              rating: rating,
              comment: comment,
              createdAt: DateTime.now(),
            ),
          );
          notifyListeners();
        }
        
        return true;
      } else {
        _setError(response.message ?? 'Erreur lors de l\'ajout de l\'avis');
        return false;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Get available time slots for a doctor
  Future<List<String>> getAvailableTimeSlots({
    required String doctorId,
    required DateTime date,
  }) async {
    try {
      final response = await _apiService.get(
        '/doctors/$doctorId/availability',
        queryParameters: {
          'date': date.toIso8601String().split('T')[0],
        },
      );
      
      if (response.isSuccess && response.data != null) {
        final List<dynamic> slots = response.data['availableSlots'] ?? [];
        return slots.cast<String>();
      } else {
        _setError(response.message ?? 'Erreur lors de la récupération des créneaux');
        return [];
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return [];
    }
  }

  // Categorize appointments
  void _categorizeAppointments() {
    final now = DateTime.now();
    
    _upcomingAppointments = _appointments
        .where((a) => a.appointmentDate.isAfter(now) && 
                     a.status != 'cancelled' && 
                     a.status != 'completed')
        .toList()
        ..sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));
    
    _pastAppointments = _appointments
        .where((a) => a.appointmentDate.isBefore(now) || 
                     a.status == 'completed' || 
                     a.status == 'cancelled')
        .toList()
        ..sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
    
    notifyListeners();
  }

  // Schedule appointment reminder notification
  Future<void> _scheduleAppointmentReminder(AppointmentModel appointment) async {
    if (appointment.doctorInfo != null) {
      await NotificationService.scheduleAppointmentReminder(
        appointmentId: appointment.id,
        doctorName: appointment.doctorInfo!.displayName,
        appointmentDate: appointment.appointmentDate,
        clinicName: appointment.doctorInfo!.clinicInfo?.name ?? 'Clinique',
      );
    }
  }

  // Get appointments by status
  List<AppointmentModel> getAppointmentsByStatus(String status) {
    return _appointments.where((a) => a.status == status).toList();
  }

  // Get appointments for today
  List<AppointmentModel> getTodayAppointments() {
    final today = DateTime.now();
    return _appointments.where((a) => 
        a.appointmentDate.year == today.year &&
        a.appointmentDate.month == today.month &&
        a.appointmentDate.day == today.day).toList();
  }

  // Get next appointment
  AppointmentModel? getNextAppointment() {
    if (_upcomingAppointments.isEmpty) return null;
    return _upcomingAppointments.first;
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

  // Clear selected appointment
  void clearSelectedAppointment() {
    _selectedAppointment = null;
    notifyListeners();
  }

  // Refresh appointments
  Future<void> refreshAppointments() async {
    await loadAppointments();
  }

  // Get statistics
  Map<String, dynamic> getStatistics() {
    return {
      'total': _appointments.length,
      'upcoming': _upcomingAppointments.length,
      'past': _pastAppointments.length,
      'completed': getAppointmentsByStatus('completed').length,
      'cancelled': getAppointmentsByStatus('cancelled').length,
      'pending': getAppointmentsByStatus('pending').length,
    };
  }
}
