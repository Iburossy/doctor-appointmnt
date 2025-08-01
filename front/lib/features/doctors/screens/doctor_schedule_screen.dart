import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:go_router/go_router.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class DoctorScheduleScreen extends StatefulWidget {
  const DoctorScheduleScreen({super.key});

  @override
  State<DoctorScheduleScreen> createState() => _DoctorScheduleScreenState();
}

class _DoctorScheduleScreenState extends State<DoctorScheduleScreen> {
  bool _isLoading = false;
  final List<String> _daysOfWeek = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  // Valeurs par défaut qui seront remplacées par les données du backend si disponibles
  final Map<String, Map<String, dynamic>> _schedule = {
    'Lundi': {'isAvailable': true, 'startTime': '08:00', 'endTime': '17:00'},
    'Mardi': {'isAvailable': true, 'startTime': '08:00', 'endTime': '17:00'},
    'Mercredi': {'isAvailable': true, 'startTime': '08:00', 'endTime': '17:00'},
    'Jeudi': {'isAvailable': true, 'startTime': '08:00', 'endTime': '17:00'},
    'Vendredi': {'isAvailable': true, 'startTime': '08:00', 'endTime': '17:00'},
    'Samedi': {'isAvailable': false, 'startTime': '08:00', 'endTime': '12:00'},
    'Dimanche': {'isAvailable': false, 'startTime': '08:00', 'endTime': '12:00'},
  };
  
  @override
  void initState() {
    super.initState();
    _ensureDoctorProfileLoaded();
    _loadDoctorSchedule();
  }
  
  void _ensureDoctorProfileLoaded() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user?.doctorProfile == null && authProvider.isAuthenticated) {
      authProvider.refreshUser().then((_) {
        // Recharger les horaires après que le profil soit chargé
        _loadDoctorSchedule();
      });
    }
  }
  
  void _loadDoctorSchedule() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    
    if (user != null && user.doctorProfile != null && 
        user.doctorProfile!.workingHours != null) {
      
      // Mapping des jours anglais vers français
      final dayMapping = {
        'monday': 'Lundi',
        'tuesday': 'Mardi',
        'wednesday': 'Mercredi',
        'thursday': 'Jeudi',
        'friday': 'Vendredi',
        'saturday': 'Samedi',
        'sunday': 'Dimanche'
      };
      
      // Conversion du format backend vers le format frontend
      final workingHours = user.doctorProfile!.workingHours;
      
      if (workingHours != null) {
        workingHours.forEach((englishDay, dayData) {
          final frenchDay = dayMapping[englishDay];
          if (frenchDay != null && _schedule.containsKey(frenchDay)) {
            // Vérifier si nous avons les données nécessaires
            final bool isWorking = dayData['isWorking'] ?? false;
            final String startTime = dayData['startTime'] ?? '08:00';
            final String endTime = dayData['endTime'] ?? '17:00';
            
            setState(() {
              _schedule[frenchDay] = {
                'isAvailable': isWorking,
                'startTime': startTime,
                'endTime': endTime
              };
            });
          }
        });
      }
      
      debugPrint('Horaires chargés: $_schedule');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gérer mes horaires'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 20.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            TextButton(
              onPressed: _saveSchedule,
              child: const Text(
                'Enregistrer',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Définissez vos horaires de consultation pour chaque jour de la semaine',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Schedule for each day
                ..._daysOfWeek.map((day) => _buildDaySchedule(day)),

                const SizedBox(height: 32),

                // Quick actions
                _buildQuickActions(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDaySchedule(String day) {
    final daySchedule = _schedule[day]!;
    final isAvailable = daySchedule['isAvailable'] as bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header with toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                day,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              Switch(
                value: isAvailable,
                onChanged: (value) {
                  setState(() {
                    _schedule[day]!['isAvailable'] = value;
                  });
                },
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),

          if (isAvailable) ...[
            const SizedBox(height: 16),
            
            // Time selection
            Row(
              children: [
                Expanded(
                  child: _buildTimeSelector(
                    label: 'Début',
                    value: daySchedule['startTime'] as String,
                    onChanged: (time) {
                      setState(() {
                        _schedule[day]!['startTime'] = time;
                      });
                    },
                  ),
                ),
                
                const SizedBox(width: 16),
                
                Expanded(
                  child: _buildTimeSelector(
                    label: 'Fin',
                    value: daySchedule['endTime'] as String,
                    onChanged: (time) {
                      setState(() {
                        _schedule[day]!['endTime'] = time;
                      });
                    },
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Jour de repos',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeSelector({
    required String label,
    required String value,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        
        const SizedBox(height: 4),
        
        GestureDetector(
          onTap: () => _selectTime(context, value, onChanged),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                Icon(
                  Icons.access_time,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions rapides',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.work,
                title: 'Jours ouvrables',
                subtitle: 'Lun-Ven 8h-17h',
                onTap: _setWeekdaySchedule,
              ),
            ),
            
            const SizedBox(width: 16),
            
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.clear_all,
                title: 'Tout désactiver',
                subtitle: 'Fermer tous les jours',
                onTap: _clearAllSchedule,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: AppTheme.primaryColor,
              size: 24,
            ),
            
            const SizedBox(height: 8),
            
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            
            const SizedBox(height: 4),
            
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, String currentTime, Function(String) onChanged) async {
    final timeParts = currentTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteTextColor: AppTheme.textPrimaryColor,
              dayPeriodTextColor: AppTheme.textPrimaryColor,
              dialHandColor: AppTheme.primaryColor,
              dialBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formattedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      onChanged(formattedTime);
    }
  }

  void _setWeekdaySchedule() {
    setState(() {
      for (int i = 0; i < 5; i++) { // Lundi à Vendredi
        final day = _daysOfWeek[i];
        _schedule[day]!['isAvailable'] = true;
        _schedule[day]!['startTime'] = '08:00';
        _schedule[day]!['endTime'] = '17:00';
      }
      // Weekend fermé
      _schedule['Samedi']!['isAvailable'] = false;
      _schedule['Dimanche']!['isAvailable'] = false;
    });
  }

  void _clearAllSchedule() {
    setState(() {
      for (final day in _daysOfWeek) {
        _schedule[day]!['isAvailable'] = false;
      }
    });
  }

  Future<void> _saveSchedule() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    // Récupérer le doctorId du profil utilisateur
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    
    if (user == null || user.doctorProfile == null || user.doctorProfile!.id == null || user.doctorProfile!.id!.isEmpty) {
      // Tenter de recharger le profil médecin avant d'afficher l'erreur
      try {
        await authProvider.refreshUser();
        final refreshedUser = authProvider.user;
        
        if (refreshedUser == null || refreshedUser.doctorProfile == null || refreshedUser.doctorProfile!.id == null || refreshedUser.doctorProfile!.id!.isEmpty) {
          throw Exception('Profil médecin non disponible');
        }
        
        // Continuer avec le profil rechargé
        // (le code continuera après ce bloc)
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible de récupérer votre profil médecin'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    final apiService = ApiService();
    final response = await apiService.updateDoctorSchedule(_schedule);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (response.isSuccess) {
        // Rafraîchir les données utilisateur pour s'assurer d'avoir les informations les plus à jour
        await authProvider.refreshUser();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Horaires sauvegardés avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Utiliser GoRouter au lieu de Navigator pour la navigation
        context.goNamed('profile');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? 'Une erreur est survenue lors de la sauvegarde'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
