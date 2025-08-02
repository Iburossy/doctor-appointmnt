import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../config/app_config.dart';
import 'storage_service.dart';

class LocationService {
  static const String _locationPermissionKey = 'location_permission_requested';
  
  // Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
  
  // Check permission
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }
  
  // Request location permission
  Future<LocationPermission> requestPermission() async {
    await StorageService.setBool(_locationPermissionKey, true);
    // Ajouter un court délai pour éviter les demandes simultanées
    await Future.delayed(const Duration(milliseconds: 500));
    return await Geolocator.requestPermission();
  }
  
  // Check if permission was previously requested
  Future<bool> wasPermissionRequested() async {
    return StorageService.getBool(_locationPermissionKey) ?? false;
  }
  
  // Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      // Check if location services are enabled
      final servicesEnabled = await isLocationServiceEnabled();
      
      if (!servicesEnabled) {
        throw LocationServiceDisabledException();
      }
      
      // Check permission
      LocationPermission permission = await checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        
        if (permission == LocationPermission.denied) {
          throw LocationPermissionDeniedException();
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw LocationPermissionDeniedForeverException();
      }
      
      // Get position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      // Save to storage
      await _saveCurrentLocation(position);
      return position;
    } catch (e) {
      return null;
    }
  }
  
  // Get last known position
  Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      return null;
    }
  }
  
  // Get position with fallback
  Future<Position> getPositionWithFallback() async {
    // Try to get current position
    Position? position = await getCurrentPosition();
    
    if (position != null) {
      return position;
    }
    
    // Try last known position
    position = await getLastKnownPosition();
    
    if (position != null) {
      return position;
    }
    
    // Try saved location
    final savedLocation = await StorageService.getLocation();
    if (savedLocation != null) {
      return Position(
        longitude: savedLocation['longitude'],
        latitude: savedLocation['latitude'],
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }
    
    // Return default Dakar location
    return Position(
      longitude: AppConfig.defaultLongitude,
      latitude: AppConfig.defaultLatitude,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }
  
  // Calculate distance between two points
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
    );
  }
  
  // Calculate distance in kilometers
  double calculateDistanceInKm(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    final distanceInMeters = calculateDistance(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
    return distanceInMeters / 1000;
  }
  
  // Get address from coordinates (Reverse Geocoding)
  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        return _formatAddress(placemark);
      }
    } catch (e) {

    }
    return null;
  }
  
  // Get coordinates from address (Geocoding)
  Future<Position?> getCoordinatesFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      
      if (locations.isNotEmpty) {
        final location = locations.first;
        return Position(
          longitude: location.longitude,
          latitude: location.latitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      }
    } catch (e) {

    }
    return null;
  }
  
  // Format address from placemark
  String _formatAddress(Placemark placemark) {
    List<String> addressParts = [];
    
    if (placemark.street?.isNotEmpty == true) {
      addressParts.add(placemark.street!);
    }
    
    if (placemark.subLocality?.isNotEmpty == true) {
      addressParts.add(placemark.subLocality!);
    }
    
    if (placemark.locality?.isNotEmpty == true) {
      addressParts.add(placemark.locality!);
    }
    
    if (placemark.administrativeArea?.isNotEmpty == true) {
      addressParts.add(placemark.administrativeArea!);
    }
    
    if (placemark.country?.isNotEmpty == true) {
      addressParts.add(placemark.country!);
    }
    
    return addressParts.join(', ');
  }
  
  // Save current location to storage
  Future<void> _saveCurrentLocation(Position position) async {
    final locationData = {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': position.timestamp.millisecondsSinceEpoch,
      'accuracy': position.accuracy,
    };
    
    await StorageService.saveLocation(locationData);
  }
  
  // Get saved location
  Future<Position?> getSavedLocation() async {
    final locationData = await StorageService.getLocation();
    
    if (locationData != null) {
      return Position(
        longitude: locationData['longitude'],
        latitude: locationData['latitude'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(locationData['timestamp']),
        accuracy: locationData['accuracy'],
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }
    
    return null;
  }
  
  // Check if location is in Senegal (approximate bounds)
  bool isInSenegal(double latitude, double longitude) {
    // Senegal approximate bounds
    const double northBound = 16.7;
    const double southBound = 12.3;
    const double eastBound = -11.3;
    const double westBound = -17.5;
    
    return latitude >= southBound &&
           latitude <= northBound &&
           longitude >= westBound &&
           longitude <= eastBound;
  }
  
  // Get distance text for display
  String getDistanceText(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).round()} m';
    } else if (distanceInKm < 10) {
      return '${distanceInKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceInKm.round()} km';
    }
  }
  
  // Open device location settings
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }
  
  // Open app settings
  Future<void> openAppSettings() async {
    await openAppSettings();
  }
  
  // Stream position updates
  Stream<Position> getPositionStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );
    
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}

// Custom exceptions
class LocationServiceDisabledException implements Exception {
  final String message = 'Les services de localisation sont désactivés';
}

class LocationPermissionDeniedException implements Exception {
  final String message = 'Permission de localisation refusée';
}

class LocationPermissionDeniedForeverException implements Exception {
  final String message = 'Permission de localisation refusée définitivement';
}
