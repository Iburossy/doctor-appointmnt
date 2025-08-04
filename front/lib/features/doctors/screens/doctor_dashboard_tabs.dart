import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/doctor_stats_provider.dart';
import '../providers/doctor_appointments_provider.dart';
import '../../appointments/models/appointment_model.dart';

// Classe pour l'onglet d'accueil
class DoctorHomeTab extends StatefulWidget {
  final VoidCallback? onViewAllAppointments;
  
  const DoctorHomeTab({
    super.key,
    this.onViewAllAppointments,
  });

  @override
  State<DoctorHomeTab> createState() => _DoctorHomeTabState();
}

class _DoctorHomeTabState extends State<DoctorHomeTab> {
  bool _hasTriggeredRefresh = false;

  @override
  void initState() {
    super.initState();
    _loadDoctorProfileOnce();
    
    // Charger les rendez-vous au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAppointments();
    });
  }
  
  void _loadAppointments({bool forceRefresh = false}) {
    final appointmentsProvider = Provider.of<DoctorAppointmentsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.isAuthenticated && authProvider.isDoctor) {
      appointmentsProvider.loadDoctorAppointments(forceRefresh: forceRefresh);
    }
  }
  
  Future<void> _loadDoctorProfileOnce() async {
    // S'assurer que cette méthode n'est exécutée qu'une seule fois par cycle de vie du widget
    if (!_hasTriggeredRefresh) {
      setState(() => _hasTriggeredRefresh = true);
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated && authProvider.isDoctor) {
        await authProvider.refreshUser(forceFullRefresh: true);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        
        final user = authProvider.user;
        final doctorProfile = user?.doctorProfile;

        return RefreshIndicator(
          onRefresh: () async {
            await _loadDoctorProfileOnce();
            _loadAppointments(forceRefresh: true);
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildDoctorHeader(
                  user?.displayName ?? 'Docteur',
                  (doctorProfile?.specialization?.isNotEmpty ?? false)
                      ? doctorProfile!.specialization!.first as String?
                      : 'Spécialiste',
                ),

                const SizedBox(height: 32),

                // Statistiques rapides
                _buildQuickStats(),

                const SizedBox(height: 32),

                // Prochains rendez-vous
                _buildUpcomingAppointments(),

                const SizedBox(height: 32),

                // Actions rapides
                _buildQuickActions(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDoctorHeader(String doctorName, String? specialization) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bonjour,',
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          doctorName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        // Toujours afficher une spécialité, même générique si celle du médecin est manquante
        const SizedBox(height: 4),
        Text(
          specialization ?? 'Médecin',
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
        
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color.fromARGB(255, 12, 106, 173),
                const Color.fromARGB(255, 32, 160, 200),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.medical_services,
                color: Colors.white,
                size: 24,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Votre expertise au service de vos patients',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    // Utiliser Consumer pour accéder au provider et recharger automatiquement
    return Consumer<DoctorStatsProvider>(
      builder: (context, statsProvider, child) {
        // Charger les stats si ce n'est pas déjà fait
        if (statsProvider.stats == null && !statsProvider.isLoading) {
          // Appel asynchrone pour charger les données
          Future.microtask(() => statsProvider.loadDoctorStats());
        }
        
        // Si chargement en cours, afficher un indicateur
        if (statsProvider.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // Si erreur, afficher un message
        if (statsProvider.error != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Statistiques rapides',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(height: 8),
                      Text('Impossible de charger les statistiques',
                          style: TextStyle(color: Colors.red.shade800)),
                      TextButton(
                        onPressed: () => statsProvider.loadDoctorStats(),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        
        // Données disponibles, les afficher
        final stats = statsProvider.stats;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistiques rapides',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Patients aujourd\'hui',
                    '${stats?.patientsCount ?? 0}',
                    Icons.people,
                    const Color.fromARGB(255, 32, 160, 200),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Rendez-vous',
                    '${stats?.todaysAppointments ?? 0}',
                    Icons.calendar_today,
                    AppTheme.secondaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Revenus du mois',
                    stats?.formattedMonthlyIncome ?? '0 XOF',
                    Icons.monetization_on,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Satisfaction',
                    stats?.ratingText ?? '0.0/5',
                    Icons.star,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAppointments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'RV confirmés à venir',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            // TextButton(
            //   onPressed: widget.onViewAllAppointments,
            //   child: const Text('Voir tout'),
            // ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Consumer<DoctorAppointmentsProvider>(
            builder: (context, appointmentsProvider, child) {
              if (appointmentsProvider.isLoading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: Color.fromARGB(255, 32, 160, 200)),
                  ),
                );
              }
              
              if (appointmentsProvider.error != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'Erreur de chargement',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            if (mounted) {
                              _loadAppointments(forceRefresh: true);
                            }
                          },
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              // Filtrer pour obtenir uniquement les rendez-vous confirmés à venir
              final upcomingAppointments = appointmentsProvider.appointments
                  .where((apt) => apt.status == 'confirmed' && apt.appointmentDate.isAfter(DateTime.now()))
                  .toList();
              
              // Trier par date (les plus proches d'abord)
              upcomingAppointments.sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));
              
              // Limiter à 3 rendez-vous maximum
              final displayAppointments = upcomingAppointments.take(3).toList();
              
              if (displayAppointments.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(Icons.calendar_today_outlined, color: Colors.grey, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          'Aucun rendez-vous à venir',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              return Column(
                children: displayAppointments.map((appointment) => _buildAppointmentItem(appointment)).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions rapides',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Nouveau patient',
                Icons.person_add,
                AppTheme.primaryColor,
                () {
                  // TODO: Navigation vers ajout patient
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                'Statistiques',
                Icons.analytics,
                AppTheme.secondaryColor,
                () {
                  // TODO: Navigation vers statistiques
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAppointmentItem(AppointmentModel appointment) {
    // Formater la date et l'heure
    final dateFormat = appointment.appointmentDate.day == DateTime.now().day
        ? 'Aujourd\'hui à ${_formatTime(appointment.appointmentDate)}'
        : '${_formatDate(appointment.appointmentDate)} à ${_formatTime(appointment.appointmentDate)}';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.calendar_today, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.patient?.fullName ?? 'Patient',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  dateFormat,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return 'Aujourd\'hui';
    } else if (date.day == tomorrow.day && date.month == tomorrow.month && date.year == tomorrow.year) {
      return 'Demain';
    } else {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    }
  }
  
  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// L'onglet des rendez-vous est maintenant dans un fichier séparé : doctor_appointments_tab.dart
// L'onglet des patients est maintenant dans un fichier séparé : doctor_patients_tab.dart
