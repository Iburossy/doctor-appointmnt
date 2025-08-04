import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/appointments_provider.dart';
import '../models/appointment_model.dart';
import '../../../shared/widgets/loading_overlay.dart';

class AppointmentDetailScreen extends StatefulWidget {
  final String appointmentId;

  const AppointmentDetailScreen({super.key, required this.appointmentId});

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  AppointmentModel? _appointment;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAppointmentDetails();
  }

  Future<void> _loadAppointmentDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final appointmentsProvider = context.read<AppointmentsProvider>();
      final appointment = await appointmentsProvider.getAppointmentDetails(
        widget.appointmentId,
      );

      if (mounted) {
        setState(() {
          _appointment = appointment;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur lors du chargement: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Détails du rendez-vous'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_appointment != null && _appointment!.isUpcoming)
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'reschedule',
                      child: Row(
                        children: [
                          Icon(Icons.schedule, size: 20),
                          SizedBox(width: 8),
                          Text('Reprogrammer'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Row(
                        children: [
                          Icon(Icons.cancel, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Annuler', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
            ),
        ],
      ),
      body: LoadingOverlay(isLoading: _isLoading, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _buildErrorState();
    }

    if (_appointment == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          _buildStatusCard(),

          const SizedBox(height: 16),

          // Doctor Info Card
          _buildDoctorInfoCard(),

          const SizedBox(height: 16),

          // Appointment Details Card
          _buildAppointmentDetailsCard(),

          const SizedBox(height: 16),

          // Medical Info Card (if available)
          if (_appointment!.diagnosis != null ||
              _appointment!.prescription.isNotEmpty)
            _buildMedicalInfoCard(),

          const SizedBox(height: 16),

          // Payment Info Card (if available)
          if (_appointment!.paymentInfo != null) _buildPaymentInfoCard(),

          const SizedBox(height: 24),

          // Action Buttons
          _buildActionButtons(),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (_appointment!.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        statusText = 'En attente de confirmation';
        break;
      case 'confirmed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Rendez-vous confirmé';
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusIcon = Icons.done_all;
        statusText = 'Consultation terminée';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Rendez-vous annulé';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
        statusText = 'Statut inconnu';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorInfoCard() {
    final doctor = _appointment!.doctorInfo;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Médecin',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              // Doctor Avatar
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color.fromARGB(255, 33, 150, 243).withValues(alpha: 0.1),
                backgroundImage:
                    doctor?.avatar != null
                        ? NetworkImage(doctor!.avatar!)
                        : null,
                child:
                    doctor?.avatar == null
                        ? Text(
                          doctor != null
                              ? doctor.firstName[0] + doctor.lastName[0]
                              : 'Dr',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color.fromARGB(255, 33, 150, 243),
                          ),
                        )
                        : null,
              ),

              const SizedBox(width: 16),

              // Doctor Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor?.displayName ?? 'Dr Médecin',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),

                    if (doctor != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        doctor.displaySpecialization,
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color.fromARGB(255, 33, 150, 243),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        if (doctor?.isVerified == true) ...[
                          Icon(Icons.verified, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            'Vérifié',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],

                        if (doctor != null) ...[
                          Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            doctor.formattedRating,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Call Button
              if (doctor?.phone != null)
                IconButton(
                  onPressed: () => _callDoctor(doctor!.phone),
                  icon: Icon(Icons.phone, color: AppTheme.primaryColor),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor.withValues(
                      alpha: 0.1,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Détails du rendez-vous',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),

          const SizedBox(height: 16),

          // Date and Time
          _buildDetailRow(
            Icons.calendar_today,
            'Date',
            DateFormat(
              'EEEE d MMMM yyyy',
              'fr_FR',
            ).format(_appointment!.appointmentDate),
          ),

          const SizedBox(height: 12),

          _buildDetailRow(Icons.access_time, 'Heure', _appointment!.timeSlot),

          // Reason
          if (_appointment!.reason != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.medical_services,
              'Motif',
              _appointment!.reason!,
            ),
          ],

          // Notes
          if (_appointment!.notes != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(Icons.note, 'Notes', _appointment!.notes!),
          ],

          // Clinic Info
          if (_appointment!.doctorInfo?.clinicInfo != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.location_on,
              'Lieu',
              _appointment!.doctorInfo!.clinicInfo!.name,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicalInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informations médicales',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),

          const SizedBox(height: 16),

          // Diagnosis
          if (_appointment!.diagnosis != null) ...[
            _buildDetailRow(
              Icons.local_hospital,
              'Diagnostic',
              _appointment!.diagnosis!,
            ),
            const SizedBox(height: 12),
          ],

          // Prescription
          if (_appointment!.prescription.isNotEmpty)
            _buildDetailRow(
              Icons.medication,
              'Prescription',
              _appointment!.prescription.join(', '),
            ),

          // Doctor Notes
          if (_appointment!.doctorNotes != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.note_alt,
              'Notes du médecin',
              _appointment!.doctorNotes!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentInfoCard() {
    final payment = _appointment!.paymentInfo!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informations de paiement',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),

          const SizedBox(height: 16),

          _buildDetailRow(
            Icons.payment,
            'Montant',
            '${payment.amount.toStringAsFixed(0)} FCFA',
          ),

          const SizedBox(height: 12),

          _buildDetailRow(
            Icons.credit_card,
            'Méthode',
            payment.method ?? 'Non spécifié',
          ),

          const SizedBox(height: 12),

          _buildDetailRow(
            Icons.check_circle,
            'Statut',
            payment.status == 'paid' ? 'Payé' : 'En attente',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (!_appointment!.isUpcoming) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Primary Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _rescheduleAppointment,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color.fromARGB(255, 33, 150, 243),
                  side: BorderSide(color: const Color.fromARGB(255, 33, 150, 243)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Reprogrammer'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _cancelAppointment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Annuler'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Secondary Action
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addToCalendar,
            icon: const Icon(Icons.calendar_month),
            label: const Text('Ajouter au calendrier'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              side: BorderSide(color: Colors.grey[300]!),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Erreur de chargement',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadAppointmentDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'reschedule':
        _rescheduleAppointment();
        break;
      case 'cancel':
        _cancelAppointment();
        break;
    }
  }

  void _callDoctor(String? phoneNumber) async {
    if (phoneNumber == null) return;
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir l\'application téléphone'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _rescheduleAppointment() {
    // TODO: Navigate to reschedule screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reprogrammation - À implémenter'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _cancelAppointment() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Annuler le rendez-vous'),
            content: const Text(
              'Êtes-vous sûr de vouloir annuler ce rendez-vous ?\n\n'
              'Cette action ne peut pas être annulée.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Non'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();

                  final appointmentsProvider =
                      context.read<AppointmentsProvider>();
                  final success = await appointmentsProvider.cancelAppointment(
                    _appointment!.id,
                  );

                  if (mounted) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Rendez-vous annulé avec succès'),
                          backgroundColor: Colors.green,
                        ),
                      );

                      // Reload appointment details
                      _loadAppointmentDetails();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Erreur lors de l\'annulation'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Oui, annuler'),
              ),
            ],
          ),
    );
  }

  void _addToCalendar() {
    // TODO: Add to device calendar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ajout au calendrier - À implémenter'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }
}
