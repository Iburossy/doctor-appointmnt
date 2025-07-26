import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_provider.dart';
import '../../doctors/screens/doctors_search_screen.dart';
import '../../../shared/widgets/custom_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const _HomeTab(),
    const _DoctorsTab(),
    const _AppointmentsTab(),
    const _ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.textSecondary,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_hospital_outlined),
            activeIcon: Icon(Icons.local_hospital),
            label: 'Médecins',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Rendez-vous',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.user;
        
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(user?.displayName ?? 'Utilisateur'),
                
                const SizedBox(height: 32),
                
                // Quick Actions
                _buildQuickActions(context, authProvider),
                
                const SizedBox(height: 32),
                
                // Recent Section
                _buildRecentSection(),
                
                const SizedBox(height: 32),
                
                // Health Tips
                _buildHealthTips(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(String userName) {
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
          userName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.favorite,
                color: Colors.white,
                size: 24,
              ),
              
              const SizedBox(width: 12),
              
              const Expanded(
                child: Text(
                  'Votre santé est notre priorité',
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

  Widget _buildQuickActions(BuildContext context, AuthProvider authProvider) {
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
              child: _buildActionCard(
                icon: Icons.search,
                title: 'Trouver un médecin',
                subtitle: 'Rechercher près de vous',
                color: AppTheme.primaryColor,
                onTap: () => AppNavigation.goNamed('doctors'),
              ),
            ),
            
            const SizedBox(width: 16),
            
            Expanded(
              child: _buildActionCard(
                icon: Icons.calendar_today,
                title: 'Mes rendez-vous',
                subtitle: 'Voir vos consultations',
                color: AppTheme.secondaryColor,
                onTap: () => AppNavigation.goNamed('appointments'),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        if (authProvider.canUpgradeToDoctor())
          _buildDoctorUpgradeCard(context),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            
            const SizedBox(height: 12),
            
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            
            const SizedBox(height: 4),
            
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorUpgradeCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.medical_services,
                color: Colors.white,
                size: 24,
              ),
              
              const SizedBox(width: 12),
              
              const Expanded(
                child: Text(
                  'Devenir médecin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          const Text(
            'Rejoignez notre réseau de professionnels de santé',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 16),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => AppNavigation.goNamed('doctor-upgrade'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Commencer',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Récent',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            children: [
              Icon(
                Icons.history,
                size: 48,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
              
              const SizedBox(height: 12),
              
              const Text(
                'Aucun historique récent',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              
              const SizedBox(height: 4),
              
              Text(
                'Vos rendez-vous récents apparaîtront ici',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHealthTips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Conseils santé',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Colors.blue.shade600,
                size: 24,
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hydratation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Text(
                      'Buvez au moins 8 verres d\'eau par jour pour rester hydraté.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Placeholder tabs
class _DoctorsTab extends StatelessWidget {
  const _DoctorsTab();

  @override
  Widget build(BuildContext context) {
    // Import the DoctorsSearchScreen content directly
    return const DoctorsSearchScreen();
  }
}

class _AppointmentsTab extends StatelessWidget {
  const _AppointmentsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Mes rendez-vous\n(À implémenter)',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          color: AppTheme.textSecondaryColor,
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.user;
        
        return CustomScrollView(
          slivers: [
            // Header avec avatar et infos de base
            SliverAppBar(
              expandedHeight: 200,
              pinned: false,
              backgroundColor: AppTheme.primaryColor,
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        // Avatar
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: user?.avatar != null && user!.avatar!.isNotEmpty
                                ? Image.network(
                                    _getFullAvatarUrl(user.avatar!),
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
                                      print('DEBUG - Error loading avatar: $error');
                                      print('DEBUG - Avatar URL: ${_getFullAvatarUrl(user.avatar!)}');
                                      return Icon(
                                        Icons.person,
                                        size: 40,
                                        color: AppTheme.primaryColor,
                                      );
                                    },
                                  )
                                : Icon(
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
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
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
                          value: (user?.phone?.isNotEmpty == true) ? user!.phone : 'Non renseigné',
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
    );
  }
  
  String _getFullAvatarUrl(String avatarPath) {
    // Si l'URL est déjà complète, la retourner telle quelle
    if (avatarPath.startsWith('http://') || avatarPath.startsWith('https://')) {
      return avatarPath;
    }
    
    // Construire l'URL complète avec l'URL de base du serveur
    // Enlever '/api' de baseUrl pour les fichiers statiques
    final baseUrl = AppConfig.baseUrl.replaceAll('/api', '');
    
    // S'assurer que le chemin commence par '/'
    final cleanPath = avatarPath.startsWith('/') ? avatarPath : '/$avatarPath';
    
    final fullUrl = '$baseUrl$cleanPath';
    print('DEBUG - Full avatar URL: $fullUrl');
    return fullUrl;
  }
  
  String _formatAddress(dynamic address) {
    if (address == null) return 'Non renseigné';
    
    // Debug: afficher la structure de l'adresse
    print('DEBUG - Address type: ${address.runtimeType}');
    print('DEBUG - Address value: $address');
    
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
