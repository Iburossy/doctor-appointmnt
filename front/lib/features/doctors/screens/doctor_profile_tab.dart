import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/app_config.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/doctor_profile_provider.dart';

class DoctorProfileTab extends StatefulWidget {
  const DoctorProfileTab({super.key});

  @override
  State<DoctorProfileTab> createState() => _DoctorProfileTabState();
}

class _DoctorProfileTabState extends State<DoctorProfileTab> {
  @override
  void initState() {
    super.initState();
    // Reporter le chargement après la phase de construction
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDoctorProfile(context);
    });
  }

  Future<void> _loadDoctorProfile(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated && authProvider.isDoctor) {
      final doctorProfileProvider = Provider.of<DoctorProfileProvider>(context, listen: false);
      
      // Forcer un rechargement complet du profil médecin
      await doctorProfileProvider.forceReloadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Utiliser des Consumers imbriqués pour accéder aux deux providers
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Accéder au provider du profil médecin
        final doctorProfileProvider = Provider.of<DoctorProfileProvider>(context);
        
        final user = authProvider.user;
        
        // Utiliser le profil du DoctorProfileProvider au lieu de user.doctorProfile
        final doctorProfile = doctorProfileProvider.doctorProfile;

        if (user == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Utilisateur non connecté',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.goNamed('login'),
                  icon: const Icon(Icons.login),
                  label: const Text('Se connecter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 32, 160, 200),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        
        // Création d'un profil vide si nécessaire
        final profile = doctorProfile ?? DoctorProfile(id: '', userId: user.id, specialization: []);
        
        // Si le profil est vide et que le provider est en chargement, afficher un indicateur de chargement
        if (doctorProfile == null && doctorProfileProvider.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Chargement du profil médecin...'),
              ],
            ),
          );
        }

        return SafeArea(
          child: RefreshIndicator(
            onRefresh: () => doctorProfileProvider.forceReloadProfile(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Profile Header
                _buildProfileHeader(user, profile),

                const SizedBox(height: 24),

                // Informations professionnelles
                _buildSectionTitle('Informations professionnelles'),

                _buildInfoCard(
                  icon: Icons.medical_services,
                  title: 'N° d\'ordre',
                  value: profile.medicalLicenseNumber ?? 'Non spécifié',
                ),

                _buildInfoCard(
                  icon: Icons.work,
                  title: 'Expérience',
                  value: profile.yearsOfExperience != null
                      ? '${profile.yearsOfExperience} an${profile.yearsOfExperience! > 1 ? 's' : '\''} d\'expérience'
                      : 'Non spécifiée',
                ),

                _buildInfoCard(
                  icon: Icons.school,
                  title: 'Formation',
                  value: profile.education != null && profile.education!.isNotEmpty
                      ? _extractEducationInfo(profile.education!)
                      : 'Non spécifiée',
                ),

                const SizedBox(height: 24),

                if (profile.clinicDescription != null && profile.clinicDescription!.isNotEmpty)
                  ...
                  [
                    _buildSectionTitle('À propos'),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Text(
                        profile.clinicDescription!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimaryColor,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                // Profile Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => context.goNamed('doctor-schedule'),
                        icon: const Icon(Icons.calendar_today),
                        label: const Text('Mes horaires'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 32, 160, 200),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Redirection vers l'écran d'édition du profil médecin
                          context.pushNamed('edit-doctor-profile');
                        },
                        icon: const Icon(Icons.edit),
                        
                        label: const Text('Modifier'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Logout Button
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Provider.of<AuthProvider>(context, listen: false).logout();
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      'Se déconnecter',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
      },
    );
  }

  Widget _buildProfileHeader(UserModel user, DoctorProfile profile) {
    
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 32, 160, 200).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color.fromARGB(255, 32, 160, 200),
            backgroundImage:
                user.profilePicture != null && user.profilePicture!.isNotEmpty
                    ? NetworkImage(_getFullAvatarUrl(user.profilePicture!))
                    : null,
            child: user.profilePicture == null || user.profilePicture!.isEmpty
                ? Text(
                    (user.firstName.isNotEmpty == true)
                        ? user.firstName.substring(0, 1).toUpperCase()
                        : 'D',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (profile.specialization?.isNotEmpty ?? false)
                      ? profile.specialization!.first as String
                      : 'Médecin généraliste',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.star,
                      size: 18,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      profile.stats != null
                          ? '${(profile.stats!['averageRating'] ?? 0.0).toStringAsFixed(1)} (${profile.stats!['totalReviews'] ?? 0} avis)'
                          : '0.0 (0 avis)',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimaryColor,
        ),
      ),
    );
  }

  // Extraire les informations d'éducation de manière sécurisée sans exposer les IDs MongoDB
  String _extractEducationInfo(List<dynamic> educationList) {
    if (educationList.isEmpty) return 'Non spécifiée';
    
    // Récupérer les informations pertinentes de chaque élément d'éducation
    final List<String> formattedEducations = [];
    
    for (var edu in educationList) {
      if (edu is Map) {
        // Si c'est un objet, extraire seulement le diplôme et l'institution
        final degree = edu['degree']?.toString() ?? '';
        final institution = edu['institution']?.toString() ?? '';
        final year = edu['year']?.toString() ?? '';
        
        String formattedEdu = '';
        if (degree.isNotEmpty) formattedEdu += degree;
        if (institution.isNotEmpty) {
          if (formattedEdu.isNotEmpty) formattedEdu += ' - ';
          formattedEdu += institution;
        }
        if (year.isNotEmpty) {
          if (formattedEdu.isNotEmpty) formattedEdu += ' (';
          formattedEdu += year;
          if (formattedEdu.endsWith('(')) formattedEdu += ')';
        }
        
        if (formattedEdu.isNotEmpty) {
          formattedEducations.add(formattedEdu);
        }
      } else if (edu is String) {
        // Si c'est une chaîne simple, l'ajouter directement
        formattedEducations.add(edu);
      }
    }
    
    return formattedEducations.isNotEmpty 
        ? formattedEducations.join('\n') 
        : 'Non spécifiée';
  }
  
  String _getFullAvatarUrl(String? avatarPath) {
    if (avatarPath == null || avatarPath.isEmpty) {
      return '';
    }
    if (avatarPath.startsWith('http')) {
      return avatarPath;
    }
    
    String fullUrl;
    // Si le chemin commence par /uploads/, construire l'URL complète
    if (avatarPath.startsWith('/uploads/')) {
      fullUrl = '${AppConfig.staticUrl}$avatarPath';
    } else {
      // Sinon, ajouter /uploads/ si nécessaire
      fullUrl = '${AppConfig.staticUrl}/uploads/$avatarPath';
    }
    
    return fullUrl;
  }
  
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color.fromARGB(255, 32, 160, 200),
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
