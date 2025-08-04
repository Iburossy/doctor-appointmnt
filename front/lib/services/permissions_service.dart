import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PermissionsService {
  static final PermissionsService _instance = PermissionsService._internal();
  factory PermissionsService() => _instance;
  PermissionsService._internal();

  // Demander les permissions de localisation
  Future<bool> requestLocationPermission() async {
    try {
      print('🗺️ Demande de permission de localisation...');
      
      if (Platform.isAndroid) {
        return await _requestLocationPermissionAndroid();
      } else if (Platform.isIOS) {
        return await _requestLocationPermissionIOS();
      }
      
      return false;
    } catch (e) {
      print('❌ Erreur lors de la demande de permission de localisation: $e');
      return false;
    }
  }

  // Permission de localisation pour Android
  Future<bool> _requestLocationPermissionAndroid() async {
    // Vérifier si les services de localisation sont activés
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('❌ Services de localisation désactivés');
      return false;
    }

    // Vérifier les permissions
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('❌ Permission de localisation refusée');
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      print('❌ Permission de localisation refusée définitivement');
      return false;
    }

    print('✅ Permission de localisation accordée (Android)');
    return true;
  }

  // Permission de localisation pour iOS
  Future<bool> _requestLocationPermissionIOS() async {
    // Vérifier si les services de localisation sont activés
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('❌ Services de localisation désactivés');
      return false;
    }

    // Vérifier les permissions
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('❌ Permission de localisation refusée');
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      print('❌ Permission de localisation refusée définitivement');
      // Sur iOS, ouvrir les paramètres
      await openAppSettings();
      return false;
    }

    print('✅ Permission de localisation accordée (iOS)');
    return true;
  }

  // Demander les permissions de notification
  Future<bool> requestNotificationPermission() async {
    try {
      print('🔔 Demande de permission de notification...');
      
      if (Platform.isAndroid) {
        return await _requestNotificationPermissionAndroid();
      } else if (Platform.isIOS) {
        return await _requestNotificationPermissionIOS();
      }
      
      return false;
    } catch (e) {
      print('❌ Erreur lors de la demande de permission de notification: $e');
      return false;
    }
  }

  // Permission de notification pour Android
  Future<bool> _requestNotificationPermissionAndroid() async {
    // Sur Android 13+, demander la permission de notification
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (status.isGranted) {
        print('✅ Permission de notification accordée (Android)');
        return true;
      } else {
        print('❌ Permission de notification refusée (Android)');
        return false;
      }
    }
    return true; // Pour les versions Android plus anciennes
  }

  // Permission de notification pour iOS
  Future<bool> _requestNotificationPermissionIOS() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Permission de notification accordée (iOS)');
      return true;
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('✅ Permission de notification provisoire accordée (iOS)');
      return true;
    } else {
      print('❌ Permission de notification refusée (iOS)');
      return false;
    }
  }

  // Vérifier le statut des permissions
  Future<Map<String, bool>> checkPermissionsStatus() async {
    bool locationGranted = false;
    bool notificationGranted = false;

    // Vérifier la localisation
    LocationPermission locationPermission = await Geolocator.checkPermission();
    locationGranted = locationPermission == LocationPermission.always ||
                     locationPermission == LocationPermission.whileInUse;

    // Vérifier les notifications
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      notificationGranted = status.isGranted;
    } else if (Platform.isIOS) {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.getNotificationSettings();
      notificationGranted = settings.authorizationStatus == AuthorizationStatus.authorized ||
                           settings.authorizationStatus == AuthorizationStatus.provisional;
    }

    return {
      'location': locationGranted,
      'notification': notificationGranted,
    };
  }

  // Demander toutes les permissions nécessaires
  Future<Map<String, bool>> requestAllPermissions() async {
    print('🔐 Demande de toutes les permissions...');
    
    bool locationGranted = await requestLocationPermission();
    bool notificationGranted = await requestNotificationPermission();

    final results = {
      'location': locationGranted,
      'notification': notificationGranted,
    };

    print('📊 Résultats des permissions: $results');
    return results;
  }

  // Ouvrir les paramètres de l'application
  Future<void> openAppSettings() async {
    await openAppSettings();
  }

  // Obtenir la position actuelle
  Future<Position?> getCurrentPosition() async {
    try {
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print('📍 Position obtenue: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('❌ Erreur lors de l\'obtention de la position: $e');
      return null;
    }
  }
}
