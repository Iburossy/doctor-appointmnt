import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/patient_appointments_provider.dart';
import '../models/appointment_model.dart';

class PatientAppointmentsTab extends StatefulWidget {
  const PatientAppointmentsTab({super.key});

  @override
  State<PatientAppointmentsTab> createState() => _PatientAppointmentsTabState();
}

class _PatientAppointmentsTabState extends State<PatientAppointmentsTab> {
  String _selectedFilter = 'Tous';
  final List<String> _filters = ['Tous', 'À venir', 'Passés'];

  @override
  void initState() {
    super.initState();
    // Charger les rendez-vous au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAppointments();
    });
  }

  void _loadAppointments({bool forceRefresh = false}) {
    final appointmentsProvider = Provider.of<PatientAppointmentsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.isAuthenticated && !authProvider.isDoctor) {
      appointmentsProvider.loadPatientAppointments(forceRefresh: forceRefresh);
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
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildFilterTabs(),
              const SizedBox(height: 24),
              _buildAppointmentsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Mes rendez-vous',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        IconButton(
          onPressed: () => _loadAppointments(forceRefresh: true),
          icon: const Icon(
            Icons.refresh,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: _filters.map((filter) {
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
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(21),
                ),
                child: Center(
                  child: Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
    return Consumer<PatientAppointmentsProvider>(
      builder: (context, appointmentsProvider, child) {
        if (appointmentsProvider.isLoading) {
          return _buildLoadingState();
        }

        if (appointmentsProvider.error != null) {
          return _buildErrorState(appointmentsProvider.error!);
        }

        final filteredAppointments = _getFilteredAppointments(appointmentsProvider);

        if (filteredAppointments.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          children: filteredAppointments.map((appointment) {
            return _buildAppointmentCard(appointment);
          }).toList(),
        );
      },
    );
  }

  List<AppointmentModel> _getFilteredAppointments(PatientAppointmentsProvider provider) {
    switch (_selectedFilter) {
      case 'À venir':
        return provider.getUpcomingAppointments();
      case 'Passés':
        return provider.getPastAppointments();
      default:
        return provider.appointments;
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
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
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadAppointments(forceRefresh: true),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getEmptyStateMessage(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Naviguer vers la page de recherche des médecins
                context.push('/doctors');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text('Trouver un médecin'),
            ),
          ],
        ),
      ),
    );
  }

  String _getEmptyStateTitle() {
    switch (_selectedFilter) {
      case 'À venir':
        return 'Aucun rendez-vous à venir';
      case 'Passés':
        return 'Aucun rendez-vous passé';
      default:
        return 'Aucun rendez-vous';
    }
  }

  String _getEmptyStateMessage() {
    switch (_selectedFilter) {
      case 'À venir':
        return 'Vous n\'avez aucun rendez-vous à venir. Prenez rendez-vous avec un médecin dès maintenant !';
      case 'Passés':
        return 'Vous n\'avez aucun rendez-vous passé.';
      default:
        return 'Vous n\'avez pas encore pris de rendez-vous. Consultez notre liste de médecins pour en prendre un !';
    }
  }

  Widget _buildAppointmentCard(AppointmentModel appointment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _viewAppointmentDetails(appointment),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusBadge(appointment.status),
                    Text(
                      _formatDate(appointment.appointmentDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: appointment.doctorInfo?.avatar != null
                          ? null
                          : AppTheme.primaryColor.withValues(alpha: 0.1),
                      backgroundImage: appointment.doctorInfo?.avatar != null
                          ? NetworkImage(appointment.doctorInfo!.avatar!)
                          : null,
                      child: appointment.doctorInfo?.avatar == null
                          ? Text(
                              _getDoctorInitials(appointment),
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getDoctorName(appointment),
                            style: TextStyle(
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
                if (appointment.status == 'pending' || appointment.status == 'confirmed') ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _confirmCancelAppointment(appointment),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _viewAppointmentDetails(appointment),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Voir détails'),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _viewAppointmentDetails(appointment),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Voir détails'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
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

  String _getDoctorInitials(AppointmentModel appointment) {
    if (appointment.doctorInfo == null) {
      return '?';
    }
    
    final firstName = appointment.doctorInfo!.firstName;
    final lastName = appointment.doctorInfo!.lastName;
    
    if (firstName.isEmpty && lastName.isEmpty) {
      return '?';
    }
    
    String initials = '';
    if (firstName.isNotEmpty) {
      initials += firstName[0].toUpperCase();
    }
    if (lastName.isNotEmpty) {
      initials += lastName[0].toUpperCase();
    }
    
    return initials.isEmpty ? '?' : initials;
  }

  String _getDoctorName(AppointmentModel appointment) {
    if (appointment.doctorInfo == null) {
      return 'Médecin inconnu';
    }
    
    final firstName = appointment.doctorInfo!.firstName;
    final lastName = appointment.doctorInfo!.lastName;
    
    if (firstName.isEmpty && lastName.isEmpty) {
      return 'Médecin inconnu';
    }
    
    return '${firstName} ${lastName}'.trim();
  }

  void _confirmCancelAppointment(AppointmentModel appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler le rendez-vous'),
        content: const Text('Êtes-vous sûr de vouloir annuler ce rendez-vous ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelAppointment(appointment);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }

  void _cancelAppointment(AppointmentModel appointment) async {
    final appointmentsProvider = Provider.of<PatientAppointmentsProvider>(context, listen: false);
    final success = await appointmentsProvider.cancelAppointment(appointment.id);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rendez-vous annulé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _viewAppointmentDetails(AppointmentModel appointment) {
    // Naviguer vers l'écran de détails en passant l'objet rendez-vous
    context.push('/appointments/${appointment.id}', extra: appointment);
  }
}
