import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'doctor_appointment_details_screen.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/doctor_appointments_provider.dart';
import '../../appointments/models/appointment_model.dart';
import '../../doctors/models/patient_model.dart';

class DoctorAppointmentsTab extends StatefulWidget {
  const DoctorAppointmentsTab({super.key});

  @override
  State<DoctorAppointmentsTab> createState() => _DoctorAppointmentsTabState();
}

class _DoctorAppointmentsTabState extends State<DoctorAppointmentsTab> {
  String _selectedFilter = 'Tous';
  final List<String> _filters = ['Tous', 'En attente', 'Confirmés'];

  @override
  void initState() {
    super.initState();
    // Charger les rendez-vous au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAppointments();
    });
  }

  void _loadAppointments({bool forceRefresh = false}) {
    final appointmentsProvider = Provider.of<DoctorAppointmentsProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.isAuthenticated && authProvider.isDoctor) {
      appointmentsProvider.loadDoctorAppointments(forceRefresh: forceRefresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          _loadAppointments(forceRefresh: true);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Suppression de _buildHeader() car maintenant dans l'AppBar
              _buildFilterTabs(),
              const SizedBox(height: 24),
              _buildAppointmentsList(),
            ],
          ),
        ),
      ),
    );
  }

  // La méthode _buildHeader a été supprimée car son contenu a été déplacé dans l'AppBar

  Widget _buildFilterTabs() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children:
            _filters.map((filter) {
              final isSelected = _selectedFilter == filter;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? Color.fromARGB(255, 32, 160, 200)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(21),
                    ),
                    child: Center(
                      child: Text(
                        filter,
                        style: TextStyle(
                          color:
                              isSelected
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildAppointmentsList() {
    return Consumer<DoctorAppointmentsProvider>(
      builder: (context, appointmentsProvider, child) {
        if (appointmentsProvider.isLoading) {
          return _buildLoadingState();
        }

        if (appointmentsProvider.error != null) {
          return _buildErrorState(appointmentsProvider.error!);
        }

        final filteredAppointments = _getFilteredAppointments(
          appointmentsProvider.appointments,
        );

        if (filteredAppointments.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          children:
              filteredAppointments.map((appointment) {
                return _buildAppointmentCard(appointment);
              }).toList(),
        );
      },
    );
  }

  List<AppointmentModel> _getFilteredAppointments(
    List<AppointmentModel> appointments,
  ) {
    switch (_selectedFilter) {
      case 'En attente':
        return appointments.where((apt) => apt.status == 'pending').toList();
      case 'Confirmés':
        return appointments.where((apt) => apt.status == 'confirmed').toList();
      default:
        return appointments;
    }
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Color.fromARGB(255, 32, 160, 200),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAppointments,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromARGB(255, 32, 160, 200),
                foregroundColor: Colors.white,
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _getEmptyStateTitle(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getEmptyStateMessage(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  String _getEmptyStateTitle() {
    switch (_selectedFilter) {
      case 'En attente':
        return 'Aucun rendez-vous en attente';
      case 'Confirmés':
        return 'Aucun rendez-vous confirmé';
      default:
        return 'Aucun rendez-vous';
    }
  }

  String _getEmptyStateMessage() {
    switch (_selectedFilter) {
      case 'En attente':
        return 'Vous n\'avez aucun rendez-vous en attente de confirmation.';
      case 'Confirmés':
        return 'Vous n\'avez aucun rendez-vous confirmé pour le moment.';
      default:
        return 'Les rendez-vous réservés par vos patients apparaîtront ici.';
    }
  }

  String _getFullAvatarUrl(String? avatarPath) {
    if (avatarPath == null || avatarPath.isEmpty) {
      return '';
    }

    // Si l'URL est déjà complète, la retourner telle quelle
    if (avatarPath.startsWith('http')) {
      return avatarPath;
    }

    // Construire l'URL de base sans le segment '/api'
    final baseUrl = AppConfig.baseUrl.replaceAll('/api', '');
    
    // Si le chemin commence par '/', l'utiliser tel quel
    if (avatarPath.startsWith('/')) {
      return '$baseUrl$avatarPath';
    }
    
    // Si c'est juste le nom du fichier, ajouter le chemin uploads/avatars
    if (!avatarPath.contains('/')) {
      return '$baseUrl/uploads/avatars/$avatarPath';
    }

    // Correction pour extraire le chemin relatif si un chemin absolu Windows est fourni
    const marker = 'uploads';
    final index = avatarPath.indexOf(marker);
    if (index != -1) {
      avatarPath = avatarPath.substring(index).replaceAll('\\', '/');
    }

    return '$baseUrl/$avatarPath';
  }

  Widget _buildPatientAvatar(dynamic patient) {
    // Extraire le profilePicture du patient
    String? profilePicture;
    if (patient is PatientModel) {
      profilePicture = patient.profilePicture;
    } else if (patient is Map<String, dynamic>) {
      profilePicture = patient['profilePicture'];
    }
    
    final avatarUrl = _getFullAvatarUrl(profilePicture);
    if (avatarUrl.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder: (context, url) => CircleAvatar(
            radius: 24,
            backgroundColor: Color.fromARGB(255, 32, 160, 200).withValues(alpha: 0.1),
            child: Text(
              _getPatientInitials(patient),
              style: const TextStyle(
                color: Color.fromARGB(255, 32, 160, 200),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          errorWidget: (context, url, error) => CircleAvatar(
            radius: 24,
            backgroundColor: Color.fromARGB(255, 32, 160, 200).withValues(alpha: 0.1),
            child: Text(
              _getPatientInitials(patient),
              style: const TextStyle(
                color: Color.fromARGB(255, 32, 160, 200),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    } else {
      return CircleAvatar(
        radius: 24,
        backgroundColor: Color.fromARGB(255, 32, 160, 200).withValues(alpha: 0.1),
        child: Text(
          _getPatientInitials(patient),
          style: const TextStyle(
            color: Color.fromARGB(255, 32, 160, 200),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  Widget _buildAppointmentCard(AppointmentModel appointment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusBadge(appointment.status),
              Text(
                _formatDate(appointment.appointmentDate),
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPatientAvatar(appointment.patient),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getPatientName(appointment.patient),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${appointment.timeSlot} • ${appointment.consultationType}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (appointment.reason?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.note_outlined,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appointment.reason ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (appointment.status == 'pending') ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectAppointment(appointment),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _confirmAppointment(appointment),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2), // Couleur bleue similaire à celle du bouton "Votre santé est notre priorité"
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Confirmer'),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _viewAppointmentDetails(appointment),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Color.fromARGB(255, 32, 160, 200),
                      side: const BorderSide(
                        color: Color.fromARGB(255, 32, 160, 200),
                      ),
                    ),
                    child: const Text('Voir détails'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = 'En attente';
        break;
      case 'confirmed':
        color = Colors.green;
        text = 'Confirmé';
        break;
      case 'cancelled':
        color = Colors.red;
        text = 'Annulé';
        break;
      case 'completed':
        color = Colors.blue;
        text = 'Terminé';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference == 0) {
      return 'Aujourd\'hui';
    } else if (difference == 1) {
      return 'Demain';
    } else if (difference == -1) {
      return 'Hier';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _getPatientInitials(dynamic patient) {
    if (patient is PatientModel) {
      return patient.initials;
    }
    return '?';
  }

  String _getPatientName(dynamic patient) {
    if (patient is PatientModel) {
      return patient.fullName;
    }
    return 'Patient inconnu';
  }

  void _confirmAppointment(AppointmentModel appointment) {
    final appointmentsProvider = Provider.of<DoctorAppointmentsProvider>(
      context,
      listen: false,
    );
    appointmentsProvider.updateAppointmentStatus(appointment.id, 'confirmed');
  }

  void _rejectAppointment(AppointmentModel appointment) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Refuser le rendez-vous'),
            content: const Text(
              'Êtes-vous sûr de vouloir refuser ce rendez-vous ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  final appointmentsProvider =
                      Provider.of<DoctorAppointmentsProvider>(
                        context,
                        listen: false,
                      );
                  appointmentsProvider.updateAppointmentStatus(
                    appointment.id,
                    'cancelled',
                  );
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Refuser'),
              ),
            ],
          ),
    );
  }

  void _viewAppointmentDetails(AppointmentModel appointment) {
    // Naviguer vers l'écran de détails en passant l'objet rendez-vous
    GoRouter.of(
      context,
    ).push(DoctorAppointmentDetailsScreen.routeName, extra: appointment);
  }
}
