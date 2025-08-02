import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../../../core/services/location_service.dart';
import '../../../core/services/location_service.dart' as loc_service;

class LocationProvider with ChangeNotifier {
  final LocationService _locationService = LocationService();
  
  geo.Position? _currentPosition;
  String? _currentAddress;
  bool _isLoading = false;
  String? _error;
  bool _permissionRequested = false;

  // Getters
  geo.Position? get currentPosition => _currentPosition;
  String? get currentAddress => _currentAddress;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasLocation => _currentPosition != null;
  bool get permissionRequested => _permissionRequested;

  // Initialize location with auto-detection
  Future<void> initialize({bool autoDetect = true}) async {
    _setLoading(true);
    
    try {
      // Check if permission was previously requested
      _permissionRequested = await _locationService.wasPermissionRequested();
      
      // Try to get saved location first
      final savedPosition = await _locationService.getSavedLocation();
      if (savedPosition != null) {
        _currentPosition = savedPosition;
        notifyListeners();
      }
      
      // Always try to get current location when auto-detect is enabled
      if (autoDetect) {
        await getCurrentLocation(savePosition: true);
        
        // Schedule periodic location updates
        _setupPeriodicLocationUpdates();
      }
      // Sinon, seulement si la permission avait déjà été accordée
      else if (_permissionRequested) {
        await getCurrentLocation();
      }
    } catch (e) {
      _setError('Erreur d\'initialisation de la localisation: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Setup periodic location updates
  void _setupPeriodicLocationUpdates() {
    // Mise à jour toutes les 10 minutes
    Future.delayed(const Duration(minutes: 10), () {
      if (hasListeners) { // Only update if provider still has listeners
        getCurrentLocation(savePosition: true);
        _setupPeriodicLocationUpdates(); // Reschedule
      } else {
        
      }
    });
  }

  // Get current location
  Future<bool> getCurrentLocation({bool savePosition = false}) async {
    _setLoading(true);
    _clearError();
    
    try {
      // Vérification des services de localisation
      final servicesEnabled = await _locationService.isLocationServiceEnabled();
      
      if (!servicesEnabled) {
        _setError('Services de localisation désactivés');
        _setLoading(false);
        return false;
      }
      
      // Vérification des permissions
      await _locationService.checkPermission();
      
      // Demande de position
      final position = await _locationService.getCurrentPosition();
      
      if (position != null) {
        _currentPosition = position;
        _permissionRequested = true;
        // print('🌐 GEOLOCATION: Position GPS obtenue avec succès!');
        
        // Obtenir l'adresse à partir des coordonnées
        await _getAddressFromPosition(position);
        
        if (savePosition) {
          // print('💾 LOCATION SERVICE: Position sauvegardée dans le stockage local');
        }
        
        notifyListeners();
        return true;
      } else {
        _setError('Impossible d\'obtenir la localisation');
        return false;
      }
    } catch (e) {
      _setError('Erreur lors de la récupération de la position: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Get location with fallback to default
  Future<geo.Position> getLocationWithFallback() async {
    if (_currentPosition != null) {
      return _currentPosition!;
    }
    
    return await _locationService.getPositionWithFallback();
  }

  // Get address from coordinates
  Future<void> _getAddressFromPosition(geo.Position position) async {
    try {
      final address = await _locationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (address != null) {
        _currentAddress = address;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting address: $e');
      }
    }
  }

  // Calculate distance to a point
  double calculateDistance(double latitude, double longitude) {
    if (_currentPosition == null) return 0;
    
    return _locationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      latitude,
      longitude,
    );
  }

  // Calculate distance in kilometers
  double calculateDistanceInKm(double latitude, double longitude) {
    if (_currentPosition == null) return 0;
    
    return _locationService.calculateDistanceInKm(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      latitude,
      longitude,
    );
  }

  // Get distance text for display
  String getDistanceText(double latitude, double longitude) {
    final distanceInKm = calculateDistanceInKm(latitude, longitude);
    return _locationService.getDistanceText(distanceInKm);
  }

  // Check if location is in Senegal
  bool isInSenegal() {
    if (_currentPosition == null) return false;
    
    return _locationService.isInSenegal(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );
  }

  // Open location settings
  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
  }

  // Open app settings
  Future<void> openAppSettings() async {
    await _locationService.openAppSettings();
  }

  // Refresh location
  Future<void> refreshLocation() async {
    await getCurrentLocation();
  }

  // Clear location data
  void clearLocation() {
    _currentPosition = null;
    _currentAddress = null;
    _clearError();
    notifyListeners();
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // Get formatted current location
  String get formattedLocation {
    if (_currentAddress != null) {
      return _currentAddress!;
    }
    
    if (_currentPosition != null) {
      return '${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}';
    }
    
    return 'Localisation non disponible';
  }

  // Check if we have permission
  Future<bool> hasLocationPermission() async {
    final permission = await _locationService.checkPermission();
    return permission == geo.LocationPermission.always || 
           permission == geo.LocationPermission.whileInUse;
  }

  // Request location permission
  Future<bool> requestLocationPermission() async {
    final permission = await _locationService.requestPermission();
    _permissionRequested = true;
    
    final hasPermission = permission == geo.LocationPermission.always || 
                         permission == geo.LocationPermission.whileInUse;
    
    if (hasPermission) {
      await getCurrentLocation();
    }
    
    return hasPermission;
  }
}
