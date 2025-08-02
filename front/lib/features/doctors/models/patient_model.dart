class PatientModel {
  final String id;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? email;
  final DateTime? dateOfBirth;
  final String? gender;
  final Map<String, dynamic>? address;
  final DateTime? lastAppointment;
  final int totalAppointments;
  final int completedAppointments;

  PatientModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.email,
    this.dateOfBirth,
    this.gender,
    this.address,
    this.lastAppointment,
    this.totalAppointments = 0,
    this.completedAppointments = 0,
  });

  String get fullName => '$firstName $lastName'.trim();

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

  String get genderDisplay {
    switch (gender?.toLowerCase()) {
      case 'male':
      case 'homme':
      case 'm':
        return 'Homme';
      case 'female':
      case 'femme':
      case 'f':
        return 'Femme';
      default:
        return 'Non spécifié';
    }
  }

  String get formattedLastAppointment {
    if (lastAppointment == null) return 'Aucun rendez-vous';
    
    final now = DateTime.now();
    final difference = now.difference(lastAppointment!);
    
    if (difference.inDays == 0) {
      return 'Aujourd\'hui';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} jours';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Il y a $weeks semaine${weeks > 1 ? 's' : ''}';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Il y a $months mois';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'Il y a $years an${years > 1 ? 's' : ''}';
    }
  }

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      phone: json['phone'],
      email: json['email'],
      dateOfBirth: json['dateOfBirth'] != null 
          ? DateTime.tryParse(json['dateOfBirth']) 
          : null,
      gender: json['gender'],
      address: json['address'] as Map<String, dynamic>?,
      lastAppointment: json['lastAppointment'] != null 
          ? DateTime.tryParse(json['lastAppointment']) 
          : null,
      totalAppointments: json['totalAppointments'] ?? 0,
      completedAppointments: json['completedAppointments'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'email': email,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'address': address,
      'lastAppointment': lastAppointment?.toIso8601String(),
      'totalAppointments': totalAppointments,
      'completedAppointments': completedAppointments,
    };
  }
}
