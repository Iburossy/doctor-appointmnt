class DoctorModel {
  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String phone;
  final String? email;
  final String? avatar;
  final List<String> specialties;
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
  final List<String> verificationNotes;
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
    required this.specialties,
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
    required this.verificationNotes,
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

  // Display specialization
  String get displaySpecialization {
    if (specialties.isNotEmpty) return specialties.first;
    return 'Médecin généraliste';
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
    void logField(String key, dynamic value) {
    }

    try {
      final doctorInfo = json['doctor'] as Map<String, dynamic>? ?? {};

      final id = json['_id'] ?? json['id'] ?? '';
      logField('id', id);

      final userInfo = json['userId'] is Map<String, dynamic> ? json['userId'] as Map<String, dynamic> : {};

      final userId = (json['userId'] is String ? json['userId'] : userInfo['_id']) ?? json['_id'] ?? '';
      logField('userId', userId);

      final firstName = json['firstName'] ?? doctorInfo['firstName'] ?? userInfo['firstName'] ?? '';
      logField('firstName', firstName);

      final lastName = json['lastName'] ?? doctorInfo['lastName'] ?? userInfo['lastName'] ?? '';
      logField('lastName', lastName);

      final phone = json['phone'] ?? doctorInfo['phone'] ?? userInfo['phone'] ?? '';
      logField('phone', phone);

      final email = json['email'] ?? doctorInfo['email'];
      logField('email', email);

      final avatar = json['avatar'] ?? doctorInfo['avatar'] ?? doctorInfo['profilePicture'] ?? userInfo['profilePicture'];
      logField('avatar', avatar);

      final specialtiesData = json['specialties'] ?? json['specialization'];
      final List<String> specialties;
      if (specialtiesData is List) {
        specialties = List<String>.from(specialtiesData.map((s) => s.toString()));
      } else if (specialtiesData is String) {
        specialties = [specialtiesData];
      } else {
        specialties = [];
      }
      logField('specialties', specialties);

      final licenseNumber = json['licenseNumber'] ?? json['medicalLicenseNumber'];
      logField('licenseNumber', licenseNumber);

      final experienceYears = json['experienceYears'] ?? json['yearsOfExperience'];
      logField('experienceYears', experienceYears);

      final educationData = json['education'] ?? doctorInfo['education'];
      final education = educationData is List
          ? educationData.map((item) {
              if (item is Map<String, dynamic>) {
                return item['degree'] ?? item.toString();
              }
              return item.toString();
            }).join(', ')
          : educationData?.toString();
      logField('education', education);

      final bio = json['bio'];
      logField('bio', bio);

      final languages = _parseLanguages(json['languages']);
      logField('languages', languages);

      final clinicInfo = _parseClinicInfo(json);
      logField('clinicInfo', clinicInfo);

      final workingHours = _parseWorkingHours(json['workingHours']);
      logField('workingHours', workingHours);

      final consultationFee = json['consultationFee']?.toDouble();
      logField('consultationFee', consultationFee);

      final isVerified = json['isVerified'] ?? false;
      logField('isVerified', isVerified);

      final isAvailable = json['isAvailable'] ?? true;
      logField('isAvailable', isAvailable);

      final rating = _parseRating(json);
      logField('rating', rating);

      final reviewCount = _parseReviewCount(json);
      logField('reviewCount', reviewCount);

      final verifiedAt = json['verifiedAt'] != null ? DateTime.parse(json['verifiedAt']) : null;
      logField('verifiedAt', verifiedAt);

      final verificationNotesData = json['verificationNotes'] ?? doctorInfo['verificationNotes'];
      final verificationNotes = verificationNotesData is List
          ? List<String>.from(verificationNotesData.map((item) => item.toString()))
          : (verificationNotesData != null ? [verificationNotesData.toString()] : <String>[]);
      logField('verificationNotes', verificationNotes);

      final distance = json['distance']?.toDouble();
      logField('distance', distance);

      final createdAt = json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now();
      logField('createdAt', createdAt);

      final updatedAt = json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now();
      logField('updatedAt', updatedAt);

      return DoctorModel(
        id: id,
        userId: userId,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        email: email,
        avatar: avatar,
        specialties: specialties,
        licenseNumber: licenseNumber,
        experienceYears: experienceYears,
        education: education,
        bio: bio,
        languages: languages,
        clinicInfo: clinicInfo,
        workingHours: workingHours,
        consultationFee: consultationFee,
        isVerified: isVerified,
        isAvailable: isAvailable,
        rating: rating,
        reviewCount: reviewCount,
        verifiedAt: verifiedAt,
        verificationNotes: verificationNotes,
        distance: distance,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } catch (e) {
      // Log d'erreur désactivé pour la production
      rethrow;
    }
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
      'specialties': specialties,
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
  
  // Méthode pour traiter les différents formats possibles du champ languages
  static List<String> _parseLanguages(dynamic languagesData) {
    if (languagesData == null) {
      return [];
    }
    
    // Si c'est déjà une liste
    if (languagesData is List) {
      return languagesData.map((lang) => lang.toString()).toList();
    }
    
    // Si c'est une map/objet comme dans certaines réponses API
    if (languagesData is Map) {
      return languagesData.values.map((lang) => lang.toString()).toList();
    }
    
    // Si c'est une chaîne unique
    if (languagesData is String) {
      return [languagesData];
    }
    
    // Par défaut, retourner une liste vide
    return [];
  }
  
  // Méthode pour traiter les différents formats possibles du champ workingHours
  static List<WorkingHours> _parseWorkingHours(dynamic workingHoursData) {
    if (workingHoursData == null) {
      return [];
    }
    
    // Format du backend: {monday: {isWorking: bool, startTime: string, endTime: string}, ...}
    if (workingHoursData is Map) {
      List<WorkingHours> result = [];
      
      // Parcourir chaque jour de la semaine dans la map
      workingHoursData.forEach((day, dayData) {
        if (dayData is Map && day is String) {
          try {
            final bool isAvailable = dayData['isWorking'] ?? false;
            final String startTime = dayData['startTime'] ?? '08:00';
            final String endTime = dayData['endTime'] ?? '17:00';
            
            result.add(WorkingHours(
              day: day,
              isAvailable: isAvailable,
              startTime: startTime,
              endTime: endTime,
            ));
          } catch (e) {
            // En cas d'erreur, ajouter un horaire par défaut pour ce jour
            result.add(WorkingHours(
              day: day,
              isAvailable: false,
              startTime: '08:00',
              endTime: '17:00',
            ));
          }
        }
      });
      
      return result;
    }
    
    // Si c'est déjà au format liste attendu
    if (workingHoursData is List) {
      return workingHoursData
        .map((item) {
          if (item is Map) {
            // Convertir en Map<String, dynamic> pour éviter les erreurs de type
            final Map<String, dynamic> convertedMap = {};
            item.forEach((key, value) {
              if (key is String) {
                convertedMap[key] = value;
              }
            });
            return WorkingHours.fromJson(convertedMap);
          }
          return null;
        })
        .whereType<WorkingHours>()
        .toList();
    }
    
    // Par défaut, retourner une liste vide
    return [];
  }
  
  // Méthode pour traiter les différentes structures possibles des infos de clinique
  static ClinicInfo? _parseClinicInfo(Map<String, dynamic> json) {
    // Vérifier d'abord la structure attendue par le frontend
    if (json['clinicInfo'] != null) {
      return ClinicInfo.fromJson(json['clinicInfo']);
    }
    
    // Vérifier la structure utilisée par le backend
    if (json['clinic'] != null && json['clinic'] is Map) {
      final clinicData = json['clinic'] as Map;
      final Map<String, dynamic> convertedClinic = {};
      
      // Convertir la structure backend vers la structure frontend
      if (clinicData['name'] != null) {
        convertedClinic['name'] = clinicData['name'];
      }
      
      if (clinicData['phone'] != null) {
        convertedClinic['phone'] = clinicData['phone'];
      }
      
      if (clinicData['description'] != null) {
        convertedClinic['description'] = clinicData['description'];
      }
      
      if (clinicData['photos'] != null && clinicData['photos'] is List) {
        convertedClinic['photos'] = clinicData['photos'];
      }
      
      // Gestion de l'adresse
      if (clinicData['address'] != null && clinicData['address'] is Map) {
        final addressData = clinicData['address'] as Map;
        final Map<String, dynamic> convertedAddress = {};
        
        if (addressData['street'] != null) {
          convertedAddress['street'] = addressData['street'];
        }
        
        if (addressData['city'] != null) {
          convertedAddress['city'] = addressData['city'];
        }
        
        if (addressData['region'] != null) {
          convertedAddress['region'] = addressData['region'];
        }
        
        if (addressData['country'] != null) {
          convertedAddress['country'] = addressData['country'];
        }
        
        // Géolocalisation
        if (addressData['location'] != null && addressData['location'] is Map) {
          final locationData = addressData['location'] as Map;
          if (locationData['coordinates'] != null && locationData['coordinates'] is List) {
            final coordinates = locationData['coordinates'] as List;
            if (coordinates.length >= 2) {
              // Conversion des coordonnées [longitude, latitude] en {longitude, latitude}
              convertedAddress['longitude'] = coordinates[0];
              convertedAddress['latitude'] = coordinates[1];
            }
          }
        }
        
        convertedClinic['address'] = convertedAddress;
      }
      
      return ClinicInfo.fromJson(convertedClinic);
    }
    
    return null;
  }
  
  // Méthode pour traiter le rating depuis les statistiques
  static double _parseRating(Map<String, dynamic> json) {
    // Vérifier d'abord le champ rating direct
    if (json['rating'] != null) {
      return (json['rating'] as num).toDouble();
    }
    
    // Vérifier dans les statistiques
    if (json['stats'] != null && json['stats'] is Map) {
      final stats = json['stats'] as Map;
      if (stats['averageRating'] != null) {
        return (stats['averageRating'] as num).toDouble();
      }
    }
    
    return 0.0;
  }
  
  // Méthode pour traiter le nombre d'avis depuis les statistiques
  static int _parseReviewCount(Map<String, dynamic> json) {
    // Vérifier d'abord le champ reviewCount direct
    if (json['reviewCount'] != null) {
      return json['reviewCount'] as int;
    }
    
    // Vérifier dans les statistiques
    if (json['stats'] != null && json['stats'] is Map) {
      final stats = json['stats'] as Map;
      if (stats['totalReviews'] != null) {
        return stats['totalReviews'] as int;
      }
    }
    
    return 0;
  }
}

class ClinicInfo {
  final String name;
  final String street;
  final String city;
  final String region;
  final String country;
  final String? postalCode;
  final double latitude;
  final double longitude;
  final String? phone;
  final String? description;
  final List<String> photos;

  ClinicInfo({
    required this.name,
    required this.street,
    required this.city,
    required this.region,
    required this.country,
    this.postalCode,
    required this.latitude,
    required this.longitude,
    this.phone,
    this.description,
    required this.photos,
  });

  factory ClinicInfo.fromJson(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>? ?? {};
    final location = address['location'] as Map<String, dynamic>? ?? {};
    final coordinates = location['coordinates'] as List<dynamic>?;

    return ClinicInfo(
      name: json['name'] ?? '',
      street: address['street'] ?? '',
      city: address['city'] ?? '',
      region: address['region'] ?? '',
      country: address['country'] ?? '',
      postalCode: address['postalCode'],
      latitude: coordinates != null && coordinates.length > 1
          ? (coordinates[1] as num).toDouble()
          : (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: coordinates != null && coordinates.isNotEmpty
          ? (coordinates[0] as num).toDouble()
          : (json['longitude'] as num?)?.toDouble() ?? 0.0,
      phone: json['phone']?.toString(),
      description: json['description'],
      photos: List<String>.from(json['photos'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': {
        'street': street,
        'city': city,
        'region': region,
        'country': country,
        'postalCode': postalCode,
        'location': {
          'type': 'Point',
          'coordinates': [longitude, latitude],
        },
      },
      'phone': phone,
      'description': description,
      'photos': photos,
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
