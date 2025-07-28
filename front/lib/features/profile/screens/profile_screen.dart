import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/custom_button.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.user;
          
          // Debug: afficher toutes les données utilisateur
          if (user != null) {
            print('=== DEBUG USER DATA (ProfileScreen) ===');
            print('ID: ${user.id}');
            print('FirstName: ${user.firstName}');
            print('LastName: ${user.lastName}');
            print('Phone: ${user.phone}');
            print('Email: ${user.email}');
            print('DateOfBirth: ${user.dateOfBirth}');
            print('Gender: ${user.gender}');
            print('Address: ${user.address}');
            print('Address type: ${user.address.runtimeType}');
            print('ProfilePicture: ${user.profilePicture}');
            print('Role: ${user.role}');
            print('==========================================');
          } else {
            print('DEBUG (ProfileScreen): User is null!');
          }
          
          return CustomScrollView(
            slivers: [
              // Header avec avatar et infos de base
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: AppTheme.primaryColor,
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                    ),
                    onPressed: () async {
                      print('DEBUG: Refreshing user data...');
                      await authProvider.refreshUser();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profil actualisé'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20, bottom: 20, left: 16, right: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Avatar
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(40),
                                  child: user != null && user.profilePicture != null && user.profilePicture!.isNotEmpty
                                      ? Image.network(
                                          _getFullAvatarUrl(user.profilePicture!),
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Center(
                                              child: CircularProgressIndicator(
                                                value: loadingProgress.expectedTotalBytes != null
                                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                    : null,
                                                color: AppTheme.primaryColor,
                                              ),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.person,
                                              size: 40,
                                              color: AppTheme.primaryColor,
                                            );
                                          },
                                        )
                                      : const Icon(
                                          Icons.person,
                                          size: 40,
                                          color: AppTheme.primaryColor,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Nom
                              Text(
                                user?.firstName != null && user?.lastName != null
                                    ? '${user?.firstName} ${user?.lastName}'
                                    : 'Utilisateur',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Badge de rôle
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: user?.role == 'doctor' ? Colors.green : Colors.blue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  user?.role == 'doctor' ? 'Médecin' : 'Patient',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Téléphone
                              Text(
                                user?.phone ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Contenu principal
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Informations personnelles
                      _buildSectionCard(
                        title: 'Informations personnelles',
                        icon: Icons.person_outline,
                        children: [
                          _buildInfoTile(
                            icon: Icons.phone,
                            title: 'Téléphone',
                            value: (user?.phone.isNotEmpty == true) ? user!.phone : 'Non renseigné',
                          ),
                          _buildInfoTile(
                            icon: Icons.email_outlined,
                            title: 'Email',
                            value: (user?.email?.isNotEmpty == true) ? user!.email! : 'Non renseigné',
                          ),
                          _buildInfoTile(
                            icon: Icons.cake_outlined,
                            title: 'Date de naissance',
                            value: user?.dateOfBirth != null 
                                ? '${user!.dateOfBirth!.day.toString().padLeft(2, '0')}/${user.dateOfBirth!.month.toString().padLeft(2, '0')}/${user.dateOfBirth!.year}'
                                : 'Non renseigné',
                          ),
                          _buildInfoTile(
                            icon: Icons.wc_outlined,
                            title: 'Genre',
                            value: user?.gender?.isNotEmpty == true 
                                ? (user!.gender == 'male' ? 'Homme' : (user.gender == 'female' ? 'Femme' : user.gender!))
                                : 'Non renseigné',
                          ),
                          _buildInfoTile(
                            icon: Icons.location_on_outlined,
                            title: 'Adresse',
                            value: _formatAddress(user?.address),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Section Compte
                      _buildSectionCard(
                        title: 'Mon compte',
                        icon: Icons.account_circle_outlined,
                        children: [
                          _buildActionTile(
                            icon: Icons.edit_outlined,
                            title: 'Modifier mon profil',
                            subtitle: 'Mettre à jour mes informations',
                            onTap: () {
                              AppNavigation.push('/profile/edit');
                            },
                          ),
                          if (user?.role == 'patient')
                            _buildActionTile(
                              icon: Icons.medical_services_outlined,
                              title: 'Devenir médecin',
                              subtitle: 'Demander un upgrade de compte',
                              onTap: () {
                                AppNavigation.push('/doctor-upgrade');
                              },
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Section Paramètres
                      _buildSectionCard(
                        title: 'Paramètres',
                        icon: Icons.settings_outlined,
                        children: [
                          _buildActionTile(
                            icon: Icons.notifications_outlined,
                            title: 'Notifications',
                            subtitle: 'Gérer les notifications',
                            onTap: () {
                              // TODO: Implémenter paramètres notifications
                            },
                          ),
                          _buildActionTile(
                            icon: Icons.language_outlined,
                            title: 'Langue',
                            subtitle: 'Français',
                            onTap: () {
                              // TODO: Implémenter sélection langue
                            },
                          ),
                          _buildActionTile(
                            icon: Icons.help_outline,
                            title: 'Aide et support',
                            subtitle: 'Obtenir de l\'aide',
                            onTap: () {
                              // TODO: Implémenter aide
                            },
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Bouton de déconnexion
                      CustomButton(
                        text: 'Se déconnecter',
                        onPressed: () async {
                          await authProvider.logout();
                          if (context.mounted) {
                            AppNavigation.goToLogin();
                          }
                        },
                        isOutlined: true,
                        textColor: Colors.red,
                      ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  String _getFullAvatarUrl(String avatarPath) {
    // Si l'URL est déjà complète, la retourner telle quelle
    if (avatarPath.startsWith('http')) {
      return avatarPath;
    }

    // Correction pour extraire le chemin relatif si un chemin absolu Windows est fourni
    const marker = 'uploads';
    final index = avatarPath.indexOf(marker);
    if (index != -1) {
      avatarPath = avatarPath.substring(index).replaceAll('\\', '/');
    }

    // Construire l'URL de base sans le segment '/api'
    final baseUrl = AppConfig.baseUrl.replaceAll('/api', '');

    final fullUrl = '$baseUrl/$avatarPath';
    print('DEBUG - Full avatar URL: $fullUrl');
    return fullUrl;
  }
  
  String _formatAddress(dynamic address) {
    if (address == null) return 'Non renseigné';
    
    // Debug: afficher la structure de l'adresse
    print('DEBUG (ProfileScreen) - Address type: ${address.runtimeType}');
    print('DEBUG (ProfileScreen) - Address value: $address');
    
    if (address is Map) {
      final street = address['street']?.toString() ?? '';
      final city = address['city']?.toString() ?? '';
      if (street.isNotEmpty && city.isNotEmpty) {
        return '$street, $city';
      } else if (street.isNotEmpty) {
        return street;
      } else if (city.isNotEmpty) {
        return city;
      }
      return 'Non renseigné';
    }
    
    final addressStr = address.toString().trim();
    return addressStr.isNotEmpty ? addressStr : 'Non renseigné';
  }
  
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondaryColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
