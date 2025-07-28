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
import 'core/services/notification_service.dart';
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
  
  // Initialize services
  await StorageService.init();
  await NotificationService.init();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const DoctorsApp());
}

class DoctorsApp extends StatelessWidget {
  const DoctorsApp({super.key});

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
            
            // Routing
            routerConfig: AppRouter.router,
            
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
