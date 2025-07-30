class UserModel {
  final String id;
  final String firstName;
  final String lastName;
  final String phone;
  final String? email;
  final String role; // 'patient' or 'doctor'
  final bool isPhoneVerified;
  final bool isEmailVerified;
  final String? profilePicture;
  final DateTime? dateOfBirth;
  final String? gender;
  final dynamic address; // Peut être String ou Map<String, dynamic>
  final LocationData? location;
  final NotificationSettings notificationSettings;
  final DoctorProfile? doctorProfile;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.email,
    required this.role,
    required this.isPhoneVerified,
    required this.isEmailVerified,
    this.profilePicture,
    this.dateOfBirth,
    this.gender,
    this.address,
    this.location,
    required this.notificationSettings,
    this.doctorProfile,
    required this.createdAt,
    required this.updatedAt,
  });

  // Full name getter
  String get fullName => '$firstName $lastName';

  // Display name getter
  String get displayName {
    if (role == 'doctor' && doctorProfile != null) {
      return 'Dr $fullName';
    }
    return fullName;
  }

  // Age getter
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  // Is doctor getter
  bool get isDoctor => role == 'doctor';

  // Is patient getter
  bool get isPatient => role == 'patient';

  // Is verified doctor getter
  bool get isVerifiedDoctor => isDoctor && doctorProfile?.isVerified == true;

  // Factory constructor from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      role: json['role'] ?? 'patient',
      isPhoneVerified: json['isPhoneVerified'] ?? false,
      isEmailVerified: json['isEmailVerified'] ?? false,
      profilePicture: json['profilePicture'],
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'])
          : null,
      gender: json['gender'],
      address: json['address'],
      location: json['location'] != null
          ? LocationData.fromJson(json['location'])
          : null,
      notificationSettings: json['notificationSettings'] != null
          ? NotificationSettings.fromJson(json['notificationSettings'])
          : NotificationSettings.defaultSettings(),
      doctorProfile: json['doctorProfile'] != null
          ? (() {
              try {
                print('DEBUG: Parsing doctorProfile with data: ${json['doctorProfile']}');
                return DoctorProfile.fromJson(json['doctorProfile']);
              } catch (e) {
                print('DEBUG: Error parsing doctorProfile: $e');
                // Retourne un objet minimal au lieu de null pour éviter les problèmes d'affichage
                return DoctorProfile(
                  id: json['doctorProfile']['_id']?.toString() ?? json['doctorProfile']['id']?.toString(),
                  userId: json['doctorProfile']['userId']?.toString(),
                  specialization: [],
                );
              }
            })()
          : (json['role'] == 'doctor' ? DoctorProfile(id: '', userId: json['_id'] ?? json['id'], specialization: []) : null),  // Crée un profil vide pour les doctors
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'email': email,
      'role': role,
      'isPhoneVerified': isPhoneVerified,
      'isEmailVerified': isEmailVerified,
      'profilePicture': profilePicture,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'address': address,
      'location': location?.toJson(),
      'notificationSettings': notificationSettings.toJson(),
      'doctorProfile': doctorProfile?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Copy with method
  UserModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? role,
    bool? isPhoneVerified,
    bool? isEmailVerified,
    String? profilePicture,
    DateTime? dateOfBirth,
    String? gender,
    String? address,
    LocationData? location,
    NotificationSettings? notificationSettings,
    DoctorProfile? doctorProfile,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      profilePicture: profilePicture ?? this.profilePicture,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      location: location ?? this.location,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      doctorProfile: doctorProfile ?? this.doctorProfile,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
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

class NotificationSettings {
  final bool appointments;
  final bool messages;
  final bool promotions;
  final bool reminders;

  NotificationSettings({
    required this.appointments,
    required this.messages,
    required this.promotions,
    required this.reminders,
  });

  factory NotificationSettings.defaultSettings() {
    return NotificationSettings(
      appointments: true,
      messages: true,
      promotions: false,
      reminders: true,
    );
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      appointments: json['appointments'] ?? true,
      messages: json['messages'] ?? true,
      promotions: json['promotions'] ?? false,
      reminders: json['reminders'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appointments': appointments,
      'messages': messages,
      'promotions': promotions,
      'reminders': reminders,
    };
  }

  NotificationSettings copyWith({
    bool? appointments,
    bool? messages,
    bool? promotions,
    bool? reminders,
  }) {
    return NotificationSettings(
      appointments: appointments ?? this.appointments,
      messages: messages ?? this.messages,
      promotions: promotions ?? this.promotions,
      reminders: reminders ?? this.reminders,
    );
  }
}

class DoctorProfile {
  final String? id;
  final String? userId;
  final List<dynamic>? specialization;
  final String? medicalLicenseNumber;
  final int? yearsOfExperience;
  final List<dynamic>? education;
  final List<dynamic>? certifications;
  final Map<String, dynamic>? clinic;
  final Map<String, dynamic>? workingHours;
  final double? consultationFee;
  final String? currency;
  final List<dynamic>? languages;
  final String? verificationStatus;
  final DateTime? verificationDate;
  final String? verificationNotes;
  final String? verifiedBy;
  final Map<String, dynamic>? profilePhoto;
  final Map<String, dynamic>? documents;
  final Map<String, dynamic>? stats;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DoctorProfile({
    this.id,
    this.userId,
    this.specialization,
    this.medicalLicenseNumber,
    this.yearsOfExperience,
    this.education,
    this.certifications,
    this.clinic,
    this.workingHours,
    this.consultationFee,
    this.currency,
    this.languages,
    this.verificationStatus,
    this.verificationDate,
    this.verificationNotes,
    this.verifiedBy,
    this.profilePhoto,
    this.documents,
    this.stats,
    this.createdAt,
    this.updatedAt,
  });

  // Computed properties
  bool get isVerified => verificationStatus == 'approved';
  String get clinicName => clinic?['name'] as String? ?? '';
  String get clinicAddress => _getClinicAddress();
  String? get clinicPhone => clinic?['phone'] as String?;
  String? get clinicDescription => clinic?['description'] as String?;
  
  String _getClinicAddress() {
    if (clinic == null || clinic!['address'] == null) return '';
    
    final address = clinic!['address'] as Map<String, dynamic>;
    final parts = <String>[];
    
    if (address['street'] != null) parts.add(address['street'] as String);
    if (address['city'] != null) parts.add(address['city'] as String);
    if (address['country'] != null) parts.add(address['country'] as String);
    
    return parts.join(', ');
  }

  factory DoctorProfile.fromJson(Map<String, dynamic> json) {
    try {
      return DoctorProfile(
        id: json['_id']?.toString() ?? json['id']?.toString(),
        userId: json['userId']?.toString(),
        specialization: json['specialties'] as List<dynamic>? ?? json['specialization'] as List<dynamic>?,
        medicalLicenseNumber: json['medicalLicenseNumber']?.toString(),
        yearsOfExperience: json['yearsOfExperience'] as int?,
        education: json['education'] as List<dynamic>?,
        certifications: json['certifications'] as List<dynamic>?,
        clinic: json['clinic'] as Map<String, dynamic>?,
        workingHours: json['workingHours'] as Map<String, dynamic>?,
        consultationFee: json['consultationFee'] != null ? 
            (json['consultationFee'] is int ? 
                (json['consultationFee'] as int).toDouble() : 
                json['consultationFee'] as double) : 
            null,
        currency: json['currency'],
        languages: json['languages'] as List<dynamic>?,
        verificationStatus: json['verificationStatus'],
        verificationDate: json['verificationDate'] != null ? 
            DateTime.parse(json['verificationDate']) : null,
        verificationNotes: json['verificationNotes'],
        verifiedBy: json['verifiedBy'],
        profilePhoto: json['profilePhoto'] as Map<String, dynamic>?,
        documents: json['documents'] as Map<String, dynamic>?,
        stats: json['stats'] as Map<String, dynamic>?,
        createdAt: json['createdAt'] != null ? 
            DateTime.parse(json['createdAt']) : null,
        updatedAt: json['updatedAt'] != null ? 
            DateTime.parse(json['updatedAt']) : null,
      );
    } catch (e) {
      print('Error parsing DoctorProfile: $e');
      print('JSON data: $json');
      // Au lieu de propager l'erreur, on crée un objet DoctorProfile minimal
      // pour éviter que toute la chaîne de parsing échoue
      return DoctorProfile(
        id: json['_id']?.toString() ?? json['id']?.toString(),
        userId: json['userId']?.toString(),
        specialization: [], // Liste vide par défaut
        // Les autres champs restent null
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'specialties': specialization,
      'medicalLicenseNumber': medicalLicenseNumber,
      'yearsOfExperience': yearsOfExperience,
      'education': education,
      'certifications': certifications,
      'clinic': clinic,
      'workingHours': workingHours,
      'consultationFee': consultationFee,
      'currency': currency,
      'languages': languages,
      'verificationStatus': verificationStatus,
      'verificationDate': verificationDate?.toIso8601String(),
      'verificationNotes': verificationNotes,
      'verifiedBy': verifiedBy,
      'profilePhoto': profilePhoto,
      'documents': documents,
      'stats': stats,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
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
}
