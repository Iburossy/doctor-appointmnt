import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routes/app_router.dart';

class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  
  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        // Navigation vers les différents écrans
        switch (index) {
          case 0:
            AppNavigation.goToHome();
            break;
          case 1:
            AppNavigation.goToDoctors();
            break;
          case 2:
            AppNavigation.goToAppointments();
            break;
          case 3:
            AppNavigation.goToProfile();
            break;
        }
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
          icon: Icon(Icons.search_outlined),
          activeIcon: Icon(Icons.search),
          label: 'Médecins',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today_outlined),
          activeIcon: Icon(Icons.calendar_today),
          label: 'RDV',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ],
    );
  }
}

// Constantes pour identifier l'écran actuel
class AppScreenIndex {
  static const int home = 0;
  static const int doctors = 1;
  static const int appointments = 2;
  static const int profile = 3;
  static const int other = -1; // Pour les écrans qui ne sont pas dans la navigation principale
}
