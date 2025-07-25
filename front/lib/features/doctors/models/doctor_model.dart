class DoctorModel {
  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String phone;
  final String? email;
  final String? avatar;
  final String? specialization;
  final String? licenseNumber;
  final int? experienceYears;
  final String? education;
  final String? bio;
  final List<String> languages;
  final ClinicInfo? clinicInfo;
  final List<WorkingHours> workingHours;
  final double? consultationFee;
  final bool isVerified;
  final bool isAvailable;
  final double rating;
  final int reviewCount;
  final DateTime? verifiedAt;
  final String? verificationNotes;
  final double? distance; // Distance from user location in km
  final DateTime createdAt;
  final DateTime updatedAt;

  DoctorModel({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.email,
    this.avatar,
    this.specialization,
    this.licenseNumber,
    this.experienceYears,
    this.education,
    this.bio,
    required this.languages,
    this.clinicInfo,
    required this.workingHours,
    this.consultationFee,
    required this.isVerified,
    required this.isAvailable,
    required this.rating,
    required this.reviewCount,
    this.verifiedAt,
    this.verificationNotes,
    this.distance,
    required this.createdAt,
    required this.updatedAt,
  });

  // Full name getter
  String get fullName => '$firstName $lastName';

  // Display name getter
  String get displayName => 'Dr $fullName';

  // Formatted consultation fee
  String get formattedFee {
    if (consultationFee == null) return 'Prix non spécifié';
    return '${consultationFee!.toStringAsFixed(0)} FCFA';
  }

  // Formatted experience
  String get formattedExperience {
    if (experienceYears == null) return 'Expérience non spécifiée';
    return '$experienceYears an${experienceYears! > 1 ? 's' : ''} d\'expérience';
  }

  // Formatted rating
  String get formattedRating {
    return '$rating ($reviewCount avis)';
  }

  // Formatted distance
  String get formattedDistance {
    if (distance == null) return '';
    if (distance! < 1) {
      return '${(distance! * 1000).round()} m';
    } else if (distance! < 10) {
      return '${distance!.toStringAsFixed(1)} km';
    } else {
      return '${distance!.round()} km';
    }
  }

  // Check if doctor is currently available
  bool get isCurrentlyAvailable {
    if (!isAvailable) return false;
    
    final now = DateTime.now();
    final currentDay = _getDayName(now.weekday);
    
    final todaySchedule = workingHours.where((wh) => 
        wh.day.toLowerCase() == currentDay.toLowerCase() && wh.isAvailable).toList();
    
    if (todaySchedule.isEmpty) return false;
    
    final currentTime = TimeOfDay.fromDateTime(now);
    
    for (final schedule in todaySchedule) {
      final startTime = _parseTime(schedule.startTime);
      final endTime = _parseTime(schedule.endTime);
      
      if (_isTimeInRange(currentTime, startTime, endTime)) {
        return true;
      }
    }
    
    return false;
  }

  // Get next available slot
  String get nextAvailableSlot {
    if (!isAvailable) return 'Non disponible';
    
    final now = DateTime.now();
    
    // Check today first
    for (int i = 0; i < 7; i++) {
      final checkDate = now.add(Duration(days: i));
      final dayName = _getDayName(checkDate.weekday);
      
      final daySchedule = workingHours.where((wh) => 
          wh.day.toLowerCase() == dayName.toLowerCase() && wh.isAvailable).toList();
      
      if (daySchedule.isNotEmpty) {
        final schedule = daySchedule.first;
        if (i == 0) {
          // Today - check if still available
          final currentTime = TimeOfDay.fromDateTime(now);
          final startTime = _parseTime(schedule.startTime);
          final endTime = _parseTime(schedule.endTime);
          
          if (_isTimeInRange(currentTime, startTime, endTime) || 
              _isTimeBefore(currentTime, startTime)) {
            return 'Aujourd\'hui ${schedule.startTime}';
          }
        } else {
          return '${_getFrenchDayName(dayName)} ${schedule.startTime}';
        }
      }
    }
    
    return 'Pas de créneaux disponibles';
  }

  // Factory constructor from JSON
  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      avatar: json['avatar'],
      specialization: json['specialization'],
      licenseNumber: json['licenseNumber'],
      experienceYears: json['experienceYears'],
      education: json['education'],
      bio: json['bio'],
      languages: List<String>.from(json['languages'] ?? []),
      clinicInfo: json['clinicInfo'] != null
          ? ClinicInfo.fromJson(json['clinicInfo'])
          : null,
      workingHours: (json['workingHours'] as List?)
              ?.map((e) => WorkingHours.fromJson(e))
              .toList() ??
          [],
      consultationFee: json['consultationFee']?.toDouble(),
      isVerified: json['isVerified'] ?? false,
      isAvailable: json['isAvailable'] ?? true,
      rating: (json['rating'] ?? 0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.parse(json['verifiedAt'])
          : null,
      verificationNotes: json['verificationNotes'],
      distance: json['distance']?.toDouble(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'email': email,
      'avatar': avatar,
      'specialization': specialization,
      'licenseNumber': licenseNumber,
      'experienceYears': experienceYears,
      'education': education,
      'bio': bio,
      'languages': languages,
      'clinicInfo': clinicInfo?.toJson(),
      'workingHours': workingHours.map((e) => e.toJson()).toList(),
      'consultationFee': consultationFee,
      'isVerified': isVerified,
      'isAvailable': isAvailable,
      'rating': rating,
      'reviewCount': reviewCount,
      'verifiedAt': verifiedAt?.toIso8601String(),
      'verificationNotes': verificationNotes,
      'distance': distance,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Helper methods
  String _getDayName(int weekday) {
    const days = [
      'monday', 'tuesday', 'wednesday', 'thursday', 
      'friday', 'saturday', 'sunday'
    ];
    return days[weekday - 1];
  }

  String _getFrenchDayName(String englishDay) {
    const dayMap = {
      'monday': 'Lundi',
      'tuesday': 'Mardi',
      'wednesday': 'Mercredi',
      'thursday': 'Jeudi',
      'friday': 'Vendredi',
      'saturday': 'Samedi',
      'sunday': 'Dimanche',
    };
    return dayMap[englishDay.toLowerCase()] ?? englishDay;
  }

  TimeOfDay _parseTime(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  bool _isTimeInRange(TimeOfDay current, TimeOfDay start, TimeOfDay end) {
    final currentMinutes = current.hour * 60 + current.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    
    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }

  bool _isTimeBefore(TimeOfDay current, TimeOfDay target) {
    final currentMinutes = current.hour * 60 + current.minute;
    final targetMinutes = target.hour * 60 + target.minute;
    
    return currentMinutes < targetMinutes;
  }
}

class ClinicInfo {
  final String name;
  final String address;
  final String? phone;
  final LocationData? location;

  ClinicInfo({
    required this.name,
    required this.address,
    this.phone,
    this.location,
  });

  factory ClinicInfo.fromJson(Map<String, dynamic> json) {
    return ClinicInfo(
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'],
      location: json['location'] != null
          ? LocationData.fromJson(json['location'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'location': location?.toJson(),
    };
  }
}

class LocationData {
  final String type;
  final List<double> coordinates; // [longitude, latitude]
  final String? address;

  LocationData({
    required this.type,
    required this.coordinates,
    this.address,
  });

  double get longitude => coordinates[0];
  double get latitude => coordinates[1];

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      type: json['type'] ?? 'Point',
      coordinates: List<double>.from(json['coordinates'] ?? [0.0, 0.0]),
      address: json['address'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'coordinates': coordinates,
      'address': address,
    };
  }
}

class WorkingHours {
  final String day;
  final String startTime;
  final String endTime;
  final bool isAvailable;

  WorkingHours({
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.isAvailable,
  });

  factory WorkingHours.fromJson(Map<String, dynamic> json) {
    return WorkingHours(
      day: json['day'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      isAvailable: json['isAvailable'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'startTime': startTime,
      'endTime': endTime,
      'isAvailable': isAvailable,
    };
  }

  String get formattedSchedule {
    if (!isAvailable) return 'Fermé';
    return '$startTime - $endTime';
  }
}

// Import TimeOfDay from Flutter
class TimeOfDay {
  final int hour;
  final int minute;

  const TimeOfDay({required this.hour, required this.minute});

  factory TimeOfDay.fromDateTime(DateTime dateTime) {
    return TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
  }
}
