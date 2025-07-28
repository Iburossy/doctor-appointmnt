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
          ? DoctorProfile.fromJson(json['doctorProfile'])
          : null,
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

  DoctorProfile({
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
  });

  factory DoctorProfile.fromJson(Map<String, dynamic> json) {
    return DoctorProfile(
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
