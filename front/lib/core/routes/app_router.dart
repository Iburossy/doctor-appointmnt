// import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/phone_verification_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/doctors/screens/doctors_search_screen.dart';
import '../../features/doctors/screens/doctor_detail_screen.dart';
import '../../features/doctors/screens/doctor_dashboard_screen.dart';
import '../../features/doctors/screens/edit_doctor_profile_screen.dart';
import '../../features/appointments/screens/appointment_booking_screen.dart';
import '../../features/appointments/screens/appointments_list_screen.dart';
import '../../features/appointments/screens/appointment_detail_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/doctors/screens/doctor_upgrade_screen.dart';
import '../../features/doctors/screens/doctor_schedule_screen.dart';
import '../../features/doctors/screens/doctor_appointment_details_screen.dart';
import '../../features/appointments/models/appointment_model.dart';

import '../../shared/screens/error_screen.dart';

class AppRouter {
  // Liste statique des routes pour réutilisation
  static final List<RouteBase> _routes = [

    
    // Onboarding
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    
    // Authentication Routes
    GoRoute(
      path: '/auth',
      redirect: (context, state) => '/auth/login',
    ),
    
    GoRoute(
      path: '/auth/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    
    GoRoute(
      path: '/auth/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    
    GoRoute(
      path: '/auth/verify-phone/:phone',
      name: 'phone-verification',
      builder: (context, state) {
        final phone = state.pathParameters['phone'] ?? '';
        return PhoneVerificationScreen(phoneNumber: phone);
      },
    ),
    
    GoRoute(
      path: '/auth/forgot-password',
      name: 'forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    
    // Main App Routes
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    
    // Doctor Dashboard
    GoRoute(
      path: '/doctor-dashboard',
      name: 'doctor-dashboard',
      builder: (context, state) => const DoctorDashboardScreen(),
    ),
    
    // Doctor Profile Edit
    GoRoute(
      path: '/edit-doctor-profile',
      name: 'edit-doctor-profile',
      builder: (context, state) => const EditDoctorProfileScreen(),
    ),
    
    // Doctors Routes
    GoRoute(
      path: '/doctors',
      name: 'doctors',
      builder: (context, state) => const DoctorsSearchScreen(),
    ),
    
    GoRoute(
      path: '/doctors/:doctorId',
      name: 'doctor-detail',
      builder: (context, state) {
        final doctorId = state.pathParameters['doctorId']!;
        return DoctorDetailScreen(doctorId: doctorId);
      },
    ),
    
    // Appointments Routes
    GoRoute(
      path: '/appointments',
      name: 'appointments',
      builder: (context, state) => const AppointmentsListScreen(),
    ),
    
    GoRoute(
      path: '/appointments/book/:doctorId',
      name: 'book-appointment',
      builder: (context, state) {
        final doctorId = state.pathParameters['doctorId']!;
        return AppointmentBookingScreen(doctorId: doctorId);
      },
    ),
    
    GoRoute(
      path: '/appointments/:appointmentId',
      name: 'appointment-detail',
      builder: (context, state) {
        final appointmentId = state.pathParameters['appointmentId']!;
        return AppointmentDetailScreen(appointmentId: appointmentId);
      },
    ),
    
    // Profile Routes
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    
    GoRoute(
      path: '/profile/edit',
      name: 'edit-profile',
      builder: (context, state) => const EditProfileScreen(),
    ),
    
    // Doctor Schedule
    GoRoute(
      path: '/doctor-schedule',
      name: 'doctor-schedule',
      builder: (context, state) => const DoctorScheduleScreen(),
    ),

    // Doctor Upgrade
    GoRoute(
      path: '/doctor-upgrade',
      name: 'doctor-upgrade',
      builder: (context, state) => const DoctorUpgradeScreen(),
    ),

    // Doctor Appointment Details
    GoRoute(
      path: DoctorAppointmentDetailsScreen.routeName,
      name: 'doctor-appointment-details',
      builder: (context, state) {
        final appointment = state.extra as AppointmentModel?;
        if (appointment == null) {
          // Gérer le cas où l'objet n'est pas passé, peut-être rediriger
          return const ErrorScreen(error: 'Rendez-vous non trouvé');
        }
        return DoctorAppointmentDetailsScreen(appointment: appointment);
      },
    ),
  ];
  
  // Méthode pour créer un routeur qui écoute les changements d'AuthProvider
  static GoRouter createRouter(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/home',
      debugLogDiagnostics: true,
      
      // Écouter les changements d'état d'authentification
      refreshListenable: authProvider,
      
      // Redirect logic based on auth state and user role
      redirect: (context, state) {
        final isLoggedIn = authProvider.isAuthenticated;
        final isOnboarded = authProvider.isOnboarded;
        final user = authProvider.user;
        final isInitialized = authProvider.isInitialized;

        final location = state.matchedLocation;

        // Debug logging
        print('🔄 REDIRECT DEBUG: location=$location, isInit=$isInitialized, isAuth=$isLoggedIn, isOnboarded=$isOnboarded, role=${user?.role}');

        // Si l'initialisation n'est pas terminée, on attend
        if (!isInitialized) {
          print('🔄 REDIRECT: Not initialized - waiting...');
          return null;
        }

        // 1. Priorité à l'onboarding
        if (!isOnboarded) {
          print('🔄 REDIRECT: Not onboarded → onboarding');
          return location == '/onboarding' ? null : '/onboarding';
        }

        // L'utilisateur a terminé l'onboarding, on gère l'authentification
        final isGoingToAuth = location.startsWith('/auth');

        // 2. Si l'utilisateur est connecté
        if (isLoggedIn) {
          final isDoctor = user?.isDoctor == true;
          final isPhoneVerified = user?.isPhoneVerified == true;
          final correctHome = isDoctor ? '/doctor-dashboard' : '/home';

          // PRIORITÉ 1: Si l'utilisateur n'est pas vérifié, le rediriger vers la vérification téléphonique
          if (!isPhoneVerified) {
            final isPhoneVerification = location.startsWith('/auth/verify-phone');
            if (!isPhoneVerification) {
              print('🔄 REDIRECT: Authenticated but not verified user → phone verification');
              return '/auth/verify-phone/${user?.phone ?? ''}';
            }
            // Si déjà sur la page de vérification, rester
            print('🔄 REDIRECT: Staying on phone verification page');
            return null;
          }

          // PRIORITÉ 2: Si l'utilisateur est vérifié et sur une page d'authentification, le rediriger
          if (isGoingToAuth) {
            print('🔄 REDIRECT: Verified user on auth page → $correctHome');
            return correctHome;
          }

          // Si un docteur est sur la page d'accueil du patient, le rediriger
          if (isDoctor && location == '/home') {
            print('🔄 REDIRECT: Doctor on patient home → $correctHome');
            return correctHome;
          }

          // Si un patient est sur le dashboard du docteur, le rediriger
          if (!isDoctor && location == '/doctor-dashboard') {
            print('🔄 REDIRECT: Patient on doctor dashboard → $correctHome');
            return correctHome;
          }

          print('🔄 REDIRECT: Authenticated user, staying on $location');
        } else { 
          // 3. Si l'utilisateur n'est pas connecté et n'essaie pas d'accéder à une page d'auth, on le redirige vers le login
          if (!isGoingToAuth) {
            print('🔄 REDIRECT: Not authenticated → login');
            return '/auth/login';
          }
          print('🔄 REDIRECT: Not authenticated, staying on auth page $location');
        }

        // Pas de redirection nécessaire
        print('🔄 REDIRECT: No redirect needed for $location');
        return null;
      },
      
      routes: _routes,
      
      // Error handling
      errorBuilder: (context, state) => ErrorScreen(
        error: state.error.toString(),
      ),
    );
  }

}
