import 'package:flutter/material.dart';
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
import '../../shared/screens/splash_screen.dart';
import '../../shared/screens/error_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    
    // Redirect logic based on auth state and user role
    redirect: (context, state) {
      final authProvider = context.read<AuthProvider>();
      final isLoggedIn = authProvider.isAuthenticated;
      final isOnboarded = authProvider.isOnboarded;
      final user = authProvider.user;
      
      final isGoingToAuth = state.matchedLocation.startsWith('/auth');
      final isGoingToOnboarding = state.matchedLocation == '/onboarding';
      final isGoingToSplash = state.matchedLocation == '/splash';
      final isGoingToHome = state.matchedLocation == '/home';
      final isGoingToDoctorDashboard = state.matchedLocation == '/doctor-dashboard';
      
      // Always allow splash screen
      if (isGoingToSplash) return null;
      
      // If not onboarded, go to onboarding
      if (!isOnboarded && !isGoingToOnboarding) {
        return '/onboarding';
      }
      
      // If not logged in and not going to auth, redirect to login
      if (!isLoggedIn && !isGoingToAuth && !isGoingToOnboarding) {
        return '/auth/login';
      }
      
      // If logged in and going to auth, redirect based on role
      if (isLoggedIn && isGoingToAuth) {
        if (user?.isDoctor == true) {
          return '/doctor-dashboard';
        } else {
          return '/home';
        }
      }
      
      // If logged in, redirect to appropriate dashboard based on role
      if (isLoggedIn && user != null) {
        // If doctor trying to access patient home, redirect to doctor dashboard
        if (user.isDoctor && isGoingToHome) {
          return '/doctor-dashboard';
        }
        // If patient trying to access doctor dashboard, redirect to patient home
        if (user.isPatient && isGoingToDoctorDashboard) {
          return '/home';
        }
      }
      
      return null; // No redirect needed
    },
    
    routes: [
      // Splash Screen
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      
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
        path: '/auth/verify-phone',
        name: 'verify-phone',
        builder: (context, state) {
          final phone = state.extra as String?;
          return PhoneVerificationScreen(phoneNumber: phone ?? '');
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
      
      GoRoute(
        path: '/doctor-upgrade',
        name: 'doctor-upgrade',
        builder: (context, state) => const DoctorUpgradeScreen(),
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
    ],
    
    // Error handling
    errorBuilder: (context, state) => ErrorScreen(
      error: state.error.toString(),
    ),
  );
}

// Navigation helper class
class AppNavigation {
  static final GoRouter _router = AppRouter.router;
  
  // Navigation methods
  static void go(String location) => _router.go(location);
  static void push(String location) => _router.push(location);
  static void pop() => _router.pop();
  static void replace(String location) => _router.pushReplacement(location);
  
  // Named route navigation
  static void goNamed(String name, {Map<String, String>? pathParameters, Object? extra}) {
    _router.goNamed(name, pathParameters: pathParameters ?? {}, extra: extra);
  }
  
  static void pushNamed(String name, {Map<String, String>? pathParameters, Object? extra}) {
    _router.pushNamed(name, pathParameters: pathParameters ?? {}, extra: extra);
  }
  
  // Specific navigation methods
  static void goToLogin() => goNamed('login');
  static void goToRegister() => goNamed('register');
  static void goToHome() => goNamed('home');
  static void goToDoctorDashboard() => goNamed('doctor-dashboard');
  static void goToEditDoctorProfile() => goNamed('edit-doctor-profile');
  static void goToProfile() => goNamed('profile');
  static void goToDoctors() => goNamed('doctors');
  static void goToAppointments() => goNamed('appointments');
  
  static void goToPhoneVerification(String phoneNumber) {
    goNamed('verify-phone', extra: phoneNumber);
  }
  
  static void goToDoctorDetail(String doctorId) {
    goNamed('doctor-detail', pathParameters: {'doctorId': doctorId});
  }
  
  static void goToBookAppointment(String doctorId) {
    goNamed('book-appointment', pathParameters: {'doctorId': doctorId});
  }
  
  static void goToAppointmentDetail(String appointmentId) {
    goNamed('appointment-detail', pathParameters: {'appointmentId': appointmentId});
  }
  
  // Auth navigation
  static void logout() {
    goNamed('login');
  }
  
  // Can pop check
  static bool canPop() => _router.canPop();
  
  // Get current location
  static String get currentLocation => _router.routerDelegate.currentConfiguration.uri.toString();
}
