import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'config/app_config.dart' as new_config;
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'core/services/storage_service.dart';

import 'features/auth/providers/auth_provider.dart';
import 'features/location/providers/location_provider.dart';
import 'features/doctors/providers/doctors_provider.dart';
import 'features/doctors/providers/doctor_profile_provider.dart';
import 'features/appointments/providers/appointments_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize new environment configuration
  await new_config.AppConfig.initialize();
  
  // Print configuration for debug
  new_config.AppConfig.instance.printConfiguration();
  
  // Initialize Hive for local storage
  await Hive.initFlutter();
  
  // Initialize only essential services
  await StorageService.init();
  // NotificationService will be initialized after authentication
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const DoctorsApp());
}

// Classe utilitaire pour gérer la vérification périodique du rôle
class _RoleCheckManager {
  static bool isSetup = false;
}

class DoctorsApp extends StatelessWidget {
  const DoctorsApp({super.key});
  
  // Méthode pour configurer une vérification périodique du rôle utilisateur
  void _setupPeriodicRoleCheck(AuthProvider authProvider) {
    // Vérifier uniquement si ce n'est pas déjà configuré (utiliser un flag static)
    if (!_RoleCheckManager.isSetup) {
      _RoleCheckManager.isSetup = true;
      
      // Vérifier immédiatement le rôle au démarrage
      if (authProvider.isAuthenticated) {
        Future.delayed(const Duration(seconds: 2), () {
          authProvider.refreshUser();
        });
      }
      
      // Configurer une vérification périodique (toutes les 5 minutes)
      Future.delayed(const Duration(seconds: 1), () {
        Stream.periodic(const Duration(minutes: 5), (_) {
          if (authProvider.isAuthenticated) {
            authProvider.checkCurrentRole().then((serverRole) {
              if (serverRole != null && serverRole != authProvider.user?.role) {
                print('Role mismatch detected in periodic check! Refreshing user data...');
                authProvider.refreshUser();
              }
            });
          }
          return null;
        }).listen((_) {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => DoctorsProvider()),
        ChangeNotifierProvider(create: (_) => DoctorProfileProvider()),
        ChangeNotifierProvider(create: (_) => AppointmentsProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          // Ne pas configurer la vérification périodique au moment de la construction
          // Cela sera fait via un callback post-frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _setupPeriodicRoleCheck(authProvider);
          });
          
          return MaterialApp.router(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            
            // Theme
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('fr', 'FR'),
              Locale('en', 'US'),
            ],
            themeMode: ThemeMode.system,
            
            // Localization
            locale: const Locale('fr', 'SN'), // Français Sénégal
            
            // Utiliser le routeur réactif qui écoute les changements d'authentification
            routerConfig: AppRouter.createRouter(authProvider),
            
            // Builder for global configurations
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.0), // Prevent text scaling
                ),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}
