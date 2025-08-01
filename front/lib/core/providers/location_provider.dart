import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';

class LocationData {
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? city;
  final String? country;

  LocationData({
    this.latitude,
    this.longitude,
    this.address,
    this.city,
    this.country,
  });

  bool get hasLocation => latitude != null && longitude != null;

  Map<String, dynamic> toJson() {
    return {
      'coordinates': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'address': address,
      'city': city,
      'country': country,
    };
  }

  // Cette méthode formatte l'adresse complète
  String get formattedAddress {
    List<String> parts = [];
    if (address != null && address!.isNotEmpty) parts.add(address!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    
    return parts.join(', ');
  }
}

class LocationProvider extends ChangeNotifier {
  LocationData? _currentLocation;
  bool _isLoading = false;
  String? _error;
  bool _permissionDenied = false;
  Timer? _locationUpdateTimer;
  
  // Getters
  LocationData? get currentLocation => _currentLocation;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get permissionDenied => _permissionDenied;
  bool get hasLocation => _currentLocation != null && _currentLocation!.hasLocation;
  
  // Constructeur qui initialise la détection automatique si demandée
  LocationProvider({bool autoDetect = true}) {
    if (autoDetect) {
      detectLocation();
      // Actualiser la position toutes les 5 minutes
      _locationUpdateTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
        detectLocation();
      });
    }
  }
  
  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }
  
  // Méthode pour détecter la position actuelle
  Future<LocationData?> detectLocation() async {
    if (_isLoading) return _currentLocation;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // 1. Vérifier et demander les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _error = 'Permission de localisation refusée';
          _permissionDenied = true;
          _isLoading = false;
          notifyListeners();
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _error = 'Les permissions de localisation sont bloquées définitivement';
        _permissionDenied = true;
        _isLoading = false;
        notifyListeners();
        return null;
      }
      
      // 2. Obtenir la position
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // 3. Convertir la position en adresse (geocoding)
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks[0];
        _currentLocation = LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          address: place.street,
          city: place.locality,
          country: place.country,
        );
        
        print('DEBUG: Location détectée - ${_currentLocation!.formattedAddress}');
        print('DEBUG: Coordonnées - Lat: ${position.latitude}, Lng: ${position.longitude}');
      } else {
        // On a uniquement les coordonnées sans adresse
        _currentLocation = LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        _error = 'Adresse non trouvée pour les coordonnées';
      }
      
      _isLoading = false;
      notifyListeners();
      return _currentLocation;
    } catch (e) {
      _error = 'Erreur de géolocalisation: $e';
      _isLoading = false;
      print('ERROR: LocationProvider - $_error');
      notifyListeners();
      return null;
    }
  }
  
  // Méthode pour forcer une actualisation de la position
  Future<LocationData?> forceLocationUpdate() async {
    return await detectLocation();
  }
}
