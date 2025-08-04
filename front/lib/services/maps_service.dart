import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'permissions_service.dart';

class MapsService {
  static final MapsService _instance = MapsService._internal();
  factory MapsService() => _instance;
  MapsService._internal();

  final PermissionsService _permissionsService = PermissionsService();

  // Ouvrir Google Maps ou Apple Maps avec une adresse
  Future<bool> openMapsWithAddress(String address) async {
    try {
      print('🗺️ Ouverture des cartes avec adresse: $address');
      
      // Encoder l'adresse pour l'URL
      final encodedAddress = Uri.encodeComponent(address);
      
      if (Platform.isIOS) {
        // Essayer d'ouvrir Apple Maps en premier sur iOS
        final appleUrl = 'http://maps.apple.com/?q=$encodedAddress';
        if (await canLaunchUrl(Uri.parse(appleUrl))) {
          await launchUrl(Uri.parse(appleUrl), mode: LaunchMode.externalApplication);
          return true;
        }
      }
      
      // Fallback vers Google Maps
      final googleUrl = 'https://www.google.com/maps/search/?api=1&query=$encodedAddress';
      if (await canLaunchUrl(Uri.parse(googleUrl))) {
        await launchUrl(Uri.parse(googleUrl), mode: LaunchMode.externalApplication);
        return true;
      }
      
      print('❌ Impossible d\'ouvrir les cartes');
      return false;
    } catch (e) {
      print('❌ Erreur lors de l\'ouverture des cartes: $e');
      return false;
    }
  }

  // Ouvrir les cartes avec des coordonnées
  Future<bool> openMapsWithCoordinates(double latitude, double longitude, {String? label}) async {
    try {
      print('🗺️ Ouverture des cartes avec coordonnées: $latitude, $longitude');
      
      if (Platform.isIOS) {
        // Apple Maps sur iOS
        String appleUrl = 'http://maps.apple.com/?ll=$latitude,$longitude';
        if (label != null) {
          appleUrl += '&q=${Uri.encodeComponent(label)}';
        }
        
        if (await canLaunchUrl(Uri.parse(appleUrl))) {
          await launchUrl(Uri.parse(appleUrl), mode: LaunchMode.externalApplication);
          return true;
        }
      }
      
      // Google Maps (fallback ou Android)
      String googleUrl = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
      if (label != null) {
        googleUrl = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(label)}&center=$latitude,$longitude';
      }
      
      if (await canLaunchUrl(Uri.parse(googleUrl))) {
        await launchUrl(Uri.parse(googleUrl), mode: LaunchMode.externalApplication);
        return true;
      }
      
      print('❌ Impossible d\'ouvrir les cartes');
      return false;
    } catch (e) {
      print('❌ Erreur lors de l\'ouverture des cartes: $e');
      return false;
    }
  }

  // Obtenir les directions vers une destination
  Future<bool> openDirections({
    required double destinationLat,
    required double destinationLng,
    String? destinationLabel,
    double? originLat,
    double? originLng,
  }) async {
    try {
      print('🧭 Ouverture des directions vers: $destinationLat, $destinationLng');
      
      // Si pas d'origine spécifiée, utiliser la position actuelle
      String origin = '';
      if (originLat != null && originLng != null) {
        origin = '$originLat,$originLng';
      } else {
        // Essayer d'obtenir la position actuelle
        Position? position = await _permissionsService.getCurrentPosition();
        if (position != null) {
          origin = '${position.latitude},${position.longitude}';
        }
      }
      
      if (Platform.isIOS) {
        // Apple Maps sur iOS
        String appleUrl = 'http://maps.apple.com/?daddr=$destinationLat,$destinationLng';
        if (origin.isNotEmpty) {
          appleUrl += '&saddr=$origin';
        }
        if (destinationLabel != null) {
          appleUrl += '&q=${Uri.encodeComponent(destinationLabel)}';
        }
        
        if (await canLaunchUrl(Uri.parse(appleUrl))) {
          await launchUrl(Uri.parse(appleUrl), mode: LaunchMode.externalApplication);
          return true;
        }
      }
      
      // Google Maps (fallback ou Android)
      String googleUrl = 'https://www.google.com/maps/dir/';
      if (origin.isNotEmpty) {
        googleUrl += '$origin/';
      }
      googleUrl += '$destinationLat,$destinationLng';
      
      if (await canLaunchUrl(Uri.parse(googleUrl))) {
        await launchUrl(Uri.parse(googleUrl), mode: LaunchMode.externalApplication);
        return true;
      }
      
      print('❌ Impossible d\'ouvrir les directions');
      return false;
    } catch (e) {
      print('❌ Erreur lors de l\'ouverture des directions: $e');
      return false;
    }
  }

  // Calculer la distance entre deux points
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    ) / 1000; // Convertir en kilomètres
  }

  // Formater la distance pour l'affichage
  String formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).round()} m';
    } else if (distanceInKm < 10) {
      return '${distanceInKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceInKm.round()} km';
    }
  }

  // Vérifier si les services de localisation sont disponibles
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // Obtenir la position actuelle avec gestion des permissions
  Future<Position?> getCurrentPosition() async {
    return await _permissionsService.getCurrentPosition();
  }
}
