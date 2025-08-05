import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../doctors/providers/doctors_provider.dart';
import '../providers/appointments_provider.dart';
import '../../doctors/models/doctor_model.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';

class AppointmentBookingScreen extends StatefulWidget {
  final String doctorId;

  const AppointmentBookingScreen({
    super.key,
    required this.doctorId,
  });

  @override
  State<AppointmentBookingScreen> createState() => _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  int _currentStep = 0;
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  DoctorModel? _doctor;
  bool _isLoading = false;
  
  // Créneaux horaires disponibles basés sur les horaires réels du médecin
  List<String> _availableTimeSlots = [];
  
  @override
  void initState() {
    super.initState();
    _loadDoctorDetails();
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  // Génère les créneaux horaires disponibles pour une date donnée
  void _generateAvailableTimeSlots(DateTime selectedDate) {
    if (_doctor == null) {
      _availableTimeSlots = [];
      return;
    }

    // Obtenir le jour de la semaine (en anglais)
    final dayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final dayName = dayNames[selectedDate.weekday - 1];

    // Trouver les horaires de travail pour ce jour
    final workingHoursForDay = _doctor!.workingHours.firstWhere(
      (wh) => wh.day.toLowerCase() == dayName,
      orElse: () => WorkingHours(day: dayName, startTime: '', endTime: '', isAvailable: false),
    );

    if (!workingHoursForDay.isAvailable) {
      _availableTimeSlots = [];
      return;
    }

    // Parser les heures de début et fin
    final startTime = _parseTime(workingHoursForDay.startTime);
    final endTime = _parseTime(workingHoursForDay.endTime);

    if (startTime == null || endTime == null) {
      _availableTimeSlots = [];
      return;
    }

    // Générer les créneaux de 30 minutes
    final slots = <String>[];
    var currentTime = startTime;

    while (currentTime.isBefore(endTime)) {
      // Formater l'heure au format HH:mm
      final formattedTime = '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}';
      slots.add(formattedTime);
      
      // Ajouter 30 minutes
      currentTime = currentTime.add(const Duration(minutes: 30));
    }

    _availableTimeSlots = slots;
  }

  // Parse une chaîne de temps (ex: "09:00") en DateTime
  DateTime? _parseTime(String timeString) {
    if (timeString.isEmpty) return null;
    
    try {
      final parts = timeString.split(':');
      if (parts.length != 2) return null;
      
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
      
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadDoctorDetails() async {
    setState(() => _isLoading = true);
    
    try {
      final doctorsProvider = Provider.of<DoctorsProvider>(context, listen: false);
      final doctor = await doctorsProvider.getDoctorDetails(widget.doctorId);
      
      if (doctor != null) {
        setState(() {
          _doctor = doctor;
          // Générer les créneaux pour la date sélectionnée si elle existe
          if (_selectedDate != null) {
            _generateAvailableTimeSlots(_selectedDate!);
          }
        });
      } else {
        _showErrorDialog('Impossible de charger les informations du médecin');
      }
    } catch (e) {
      _showErrorDialog('Erreur lors du chargement: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  Future<void> _bookAppointment() async {
    if (_selectedDate == null || _selectedTimeSlot == null) {
      _showErrorDialog('Veuillez sélectionner une date et un créneau horaire');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final appointmentsProvider = Provider.of<AppointmentsProvider>(context, listen: false);
      
      final success = await appointmentsProvider.createAppointment(
        doctorId: widget.doctorId,
        appointmentDate: _selectedDate!,
        appointmentTime: _selectedTimeSlot!,
        reason: _reasonController.text.trim().isEmpty ? 'Consultation générale' : _reasonController.text.trim(),
        patientNotes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      
      if (success) {
        _showSuccessDialog();
      } else {
        _showErrorDialog(appointmentsProvider.error ?? 'Erreur lors de la réservation');
      }
    } catch (e) {
      _showErrorDialog('Erreur lors de la réservation: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erreur'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Rendez-vous confirmé'),
        content: const Text('Votre rendez-vous a été réservé avec succès. Vous recevrez une confirmation par SMS.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Fermer le dialog
              Navigator.of(context).pop(); // Retourner à l'écran précédent
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text(
              'Prendre rendez-vous',
              style: TextStyle(
                color: Color.fromARGB(255, 255, 255, 255),
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: const Color.fromARGB(255, 33, 150, 243), 
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
            iconTheme: const IconThemeData(
              color: Color.fromARGB(255, 255, 255, 255),
            ),
            elevation: 1,
            shadowColor: Colors.grey.withValues(alpha: 0.1),
          ),
          body: _doctor == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Stepper indicator
                    _buildStepperIndicator(),
                    
                    // Page content
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildDateSelectionStep(),
                          _buildAppointmentDetailsStep(),
                          _buildConfirmationStep(),
                        ],
                      ),
                    ),
                    
                    // Navigation buttons
                    _buildNavigationButtons(),
                  ],
                ),
          bottomNavigationBar: const AppBottomNavigation(
            currentIndex: 1, // Index pour "Médecins" car on réserve un RDV avec un médecin
            selectedItemColor: Color.fromARGB(255, 33, 150, 243),
          ),
        ),
        // Loading overlay
        if (_isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
  
  Widget _buildStepperIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= _currentStep;
          final isCompleted = index < _currentStep;
          
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? const Color.fromARGB(255, 33, 150, 243) : Colors.grey[300],
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                if (index < 3)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted ? const Color.fromARGB(255, 33, 150, 243) : Colors.grey[300],
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
  

  
  Widget _buildDateSelectionStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choisir une date',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 24),
          
          // Calendar
          Card(
            elevation: 2,
            child: CalendarDatePicker(
              initialDate: DateTime.now().add(const Duration(days: 1)),
              firstDate: DateTime.now().add(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 30)),
              onDateChanged: (date) {
                setState(() {
                  _selectedDate = date;
                  _selectedTimeSlot = null; // Reset time slot when date changes
                  _generateAvailableTimeSlots(date); // Générer les créneaux pour la nouvelle date
                });
              },
            ),
          ),
          
          if (_selectedDate != null) ...[
            const SizedBox(height: 24),
            Text(
              'Créneaux disponibles - ${DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_selectedDate!)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 16),
            
            // Time slots
          _availableTimeSlots.isEmpty
              ? Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Aucun créneau disponible pour cette date.',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableTimeSlots.map((timeSlot) {
                final isSelected = _selectedTimeSlot == timeSlot;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedTimeSlot = timeSlot);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Color.fromARGB(255, 33, 150, 243) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Color.fromARGB(255, 33, 150, 243) : Colors.grey[300]!,
                      ),
                    ),
                    child: Text(
                      timeSlot,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildAppointmentDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Détails du rendez-vous',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 24),
          
          // Reason field
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: 'Motif de consultation (optionnel)',
              hintText: 'Ex: Consultation générale, douleur abdominale...',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          
          const SizedBox(height: 16),
          
          // Notes field
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes supplémentaires (optionnel)',
              hintText: 'Informations complémentaires pour le médecin...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          
          const SizedBox(height: 24),
          
          // Summary card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Résumé',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildSummaryRow('Médecin', _doctor!.displayName),
                  _buildSummaryRow('Spécialité', _doctor!.displaySpecialization),
                  if (_selectedDate != null)
                    _buildSummaryRow('Date', DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_selectedDate!)),
                  if (_selectedTimeSlot != null)
                    _buildSummaryRow('Heure', _selectedTimeSlot!),
                  _buildSummaryRow('Tarif', _doctor!.formattedFee),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildConfirmationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confirmation',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 24),
          
          // Confirmation card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Color.fromARGB(255, 33, 150, 243),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Confirmer votre rendez-vous',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vous êtes sur le point de réserver un rendez-vous. Une confirmation vous sera envoyée par SMS.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Final summary
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow('Médecin', _doctor!.displayName),
                        _buildSummaryRow('Spécialité', _doctor!.displaySpecialization),
                        if (_selectedDate != null)
                          _buildSummaryRow('Date', DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_selectedDate!)),
                        if (_selectedTimeSlot != null)
                          _buildSummaryRow('Heure', _selectedTimeSlot!),
                        _buildSummaryRow('Motif', _reasonController.text.trim().isEmpty ? 'Consultation générale' : _reasonController.text.trim()),
                        const Divider(),
                        _buildSummaryRow('Total à payer', _doctor!.formattedFee, isTotal: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 16 : 14,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.visible,
              softWrap: true,
              style: TextStyle(
                fontSize: isTotal ? 16 : 14,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                color: isTotal ? Color.fromARGB(255, 33, 150, 243) : AppTheme.textPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                child: const Text('Précédent'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _currentStep == 2 ? _bookAppointment : _canProceedToNextStep() ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromARGB(255, 33, 150, 243),
                foregroundColor: Colors.white,
              ),
              child: Text(_currentStep == 2 ? 'Confirmer' : 'Suivant'),
            ),
          ),
        ],
      ),
    );
  }
  
  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 0:
        return _selectedDate != null && _selectedTimeSlot != null; // Sélection de date
      case 1:
        return true; // Motif optionnel pour simplifier l'expérience utilisateur
      default:
        return false;
    }
  }
}
