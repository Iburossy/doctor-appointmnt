import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/doctor_appointments_provider.dart';
import '../../appointments/models/appointment_model.dart';
import '../models/patient_model.dart';
import '../../../core/theme/app_theme.dart';

class DoctorAppointmentDetailsScreen extends StatelessWidget {
  final AppointmentModel appointment;

  static const routeName = '/doctor-appointment-details';

  const DoctorAppointmentDetailsScreen({super.key, required this.appointment});

  // Helper pour obtenir la couleur du statut à partir du nom de couleur string
  Color _getStatusColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'red':
        return Colors.red;
      case 'orange':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du rendez-vous'),
        backgroundColor: const Color.fromARGB(255, 32, 160, 200),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildPatientInfoCard(),
            const SizedBox(height: 24),
            _buildAppointmentNotesCard(),
            const SizedBox(height: 24),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rendez-vous le ${appointment.formattedDate} à ${appointment.formattedTime}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
        ),
        const SizedBox(height: 8),
        _buildStatusChip(appointment.statusDisplay, _getStatusColorFromString(appointment.statusColor)),
      ],
    );
  }

  Widget _buildPatientInfoCard() {
    final PatientModel? patient = appointment.patient;
    if (patient == null) {
      // Affiche un message si les informations du patient ne sont pas disponibles
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Informations du patient non disponibles.'),
        ),
      );
    }

    final patientName = patient.fullName;
    final patientAge = patient.age?.toString() ?? 'N/A';
    final patientGender = patient.gender ?? 'N/A';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informations du Patient', style: AppTheme.titleStyle),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.person_outline, 'Nom', patientName),
            _buildDetailRow(Icons.cake_outlined, 'Âge', patientAge != 'N/A' ? '$patientAge ans' : 'N/A'),
            _buildDetailRow(Icons.transgender_outlined, 'Sexe', patientGender),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentNotesCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Détails du rendez-vous', style: AppTheme.titleStyle),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.help_outline, 'Motif', appointment.reason ?? 'Non spécifié'),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.notes_outlined, 'Notes du patient', appointment.notes?.isNotEmpty ?? false ? appointment.notes! : 'Aucune note fournie.'),

          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final provider = Provider.of<DoctorAppointmentsProvider>(context, listen: false);

    void handleUpdateStatus(String newStatus) async {
      String successMessage;
      switch (newStatus) {
        case 'confirmed':
          successMessage = 'Rendez-vous confirmé avec succès.';
          break;
        case 'rejected':
          successMessage = 'Rendez-vous rejeté avec succès.';
          break;
        case 'completed':
          successMessage = 'Rendez-vous marqué comme terminé.';
          break;
        default:
          successMessage = 'Statut mis à jour.';
      }

      try {
        await provider.updateAppointmentStatus(appointment.id, newStatus);

        if (context.mounted) {
          // Si le rendez-vous est terminé, forcer le rafraîchissement des données utilisateur (stats)
          if (newStatus == 'completed') {
            await Provider.of<AuthProvider>(context, listen: false).refreshUser(forceFullRefresh: true);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(successMessage), backgroundColor: AppTheme.successColor),
          );
          Navigator.of(context).pop(); // Revenir à l'écran précédent
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: ${provider.error ?? 'Une erreur est survenue'}'), backgroundColor: AppTheme.errorColor),
          );
        }
      }
    }

    if (appointment.status == 'pending') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => handleUpdateStatus('confirmed'),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirmer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => handleUpdateStatus('rejected'),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Rejeter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
              ),
            ),
          ),
        ],
      );
    } else if (appointment.status == 'confirmed') {
      return Center(
        child: ElevatedButton.icon(
          onPressed: () => handleUpdateStatus('completed'),
          icon: const Icon(Icons.task_alt_outlined),
          label: const Text('Terminer le RDV'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 32, 160, 200),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
          ),
        ),
      );
    }

    return const SizedBox.shrink(); // Ne rien montrer pour les autres statuts
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color.fromARGB(255, 32, 160, 200), size: 20),
          const SizedBox(width: 16),
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          Expanded(child: Text(value, style: TextStyle(color: AppTheme.textPrimaryColor))),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, Color color) {
    return Chip(
      label: Text(
        status, // Utilise statusDisplay qui est déjà traduit
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }
}
