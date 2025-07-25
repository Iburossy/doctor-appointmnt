/// Modèle représentant un document médical avec métadonnées Cloudinary
class DocumentFile {
  final String? filename;
  final String? originalName;
  final String? path;
  final String? url;
  final String? cloudinaryId;
  final String? mimetype;
  final int? size;
  final DateTime? uploadedAt;

  DocumentFile({
    this.filename,
    this.originalName,
    this.path,
    this.url,
    this.cloudinaryId,
    this.mimetype,
    this.size,
    this.uploadedAt,
  });

  factory DocumentFile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return DocumentFile();
    
    return DocumentFile(
      filename: json['filename'],
      originalName: json['originalName'],
      path: json['path'],
      url: json['url'],
      cloudinaryId: json['cloudinaryId'],
      mimetype: json['mimetype'],
      size: json['size'],
      uploadedAt: json['uploadedAt'] != null 
          ? DateTime.parse(json['uploadedAt']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'originalName': originalName,
      'path': path,
      'url': url,
      'cloudinaryId': cloudinaryId,
      'mimetype': mimetype,
      'size': size,
      'uploadedAt': uploadedAt?.toIso8601String(),
    };
  }
}

/// Modèle représentant une certification médicale
class Certification {
  final String? name;
  final String? issuingOrganization;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final String? documentUrl;

  Certification({
    this.name,
    this.issuingOrganization,
    this.issueDate,
    this.expiryDate,
    this.documentUrl,
  });

  factory Certification.fromJson(Map<String, dynamic>? json) {
    if (json == null) return Certification();
    
    return Certification(
      name: json['name'],
      issuingOrganization: json['issuingOrganization'],
      issueDate: json['issueDate'] != null 
          ? DateTime.parse(json['issueDate']) 
          : null,
      expiryDate: json['expiryDate'] != null 
          ? DateTime.parse(json['expiryDate']) 
          : null,
      documentUrl: json['documentUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'issuingOrganization': issuingOrganization,
      'issueDate': issueDate?.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
      'documentUrl': documentUrl,
    };
  }
}

/// Modèle représentant un diplôme médical
class Education {
  final String? degree;
  final String? institution;
  final int? year;
  final String? country;

  Education({
    this.degree,
    this.institution,
    this.year,
    this.country,
  });

  factory Education.fromJson(Map<String, dynamic>? json) {
    if (json == null) return Education();
    
    return Education(
      degree: json['degree'],
      institution: json['institution'],
      year: json['year'],
      country: json['country'] ?? 'Sénégal',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'degree': degree,
      'institution': institution,
      'year': year,
      'country': country ?? 'Sénégal',
    };
  }
}

/// Modèle représentant les coordonnées géographiques
class Coordinates {
  final double? latitude;
  final double? longitude;

  Coordinates({
    this.latitude,
    this.longitude,
  });

  factory Coordinates.fromJson(Map<String, dynamic>? json) {
    if (json == null) return Coordinates();
    
    return Coordinates(
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

/// Modèle représentant l'adresse d'un cabinet médical
class ClinicAddress {
  final String? street;
  final String? city;
  final String? region;
  final String? country;
  final Coordinates? coordinates;

  ClinicAddress({
    this.street,
    this.city,
    this.region,
    this.country,
    this.coordinates,
  });

  factory ClinicAddress.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ClinicAddress();
    
    return ClinicAddress(
      street: json['street'],
      city: json['city'],
      region: json['region'],
      country: json['country'] ?? 'Sénégal',
      coordinates: Coordinates.fromJson(json['coordinates']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'street': street,
      'city': city,
      'region': region,
      'country': country ?? 'Sénégal',
      'coordinates': coordinates?.toJson(),
    };
  }
}

/// Modèle représentant un cabinet médical
class Clinic {
  final String? name;
  final ClinicAddress? address;
  final String? phone;
  final List<DocumentFile>? photos;
  final String? description;

  Clinic({
    this.name,
    this.address,
    this.phone,
    this.photos,
    this.description,
  });

  factory Clinic.fromJson(Map<String, dynamic>? json) {
    if (json == null) return Clinic();
    
    List<DocumentFile>? photosList;
    if (json['photos'] != null) {
      photosList = (json['photos'] as List)
          .map((photo) => DocumentFile.fromJson(photo))
          .toList();
    }
    
    return Clinic(
      name: json['name'],
      address: ClinicAddress.fromJson(json['address']),
      phone: json['phone'],
      photos: photosList,
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address?.toJson(),
      'phone': phone,
      'photos': photos?.map((photo) => photo.toJson()).toList(),
      'description': description,
    };
  }
}

/// Modèle représentant une plage horaire
class TimeSlot {
  final String? start;
  final String? end;

  TimeSlot({
    this.start,
    this.end,
  });

  factory TimeSlot.fromJson(Map<String, dynamic>? json) {
    if (json == null) return TimeSlot();
    
    return TimeSlot(
      start: json['start'],
      end: json['end'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
    };
  }
}

/// Modèle représentant une journée de travail
class WorkDay {
  final bool isWorking;
  final TimeSlot? morning;
  final TimeSlot? afternoon;

  WorkDay({
    this.isWorking = false,
    this.morning,
    this.afternoon,
  });

  factory WorkDay.fromJson(Map<String, dynamic>? json) {
    if (json == null) return WorkDay();
    
    return WorkDay(
      isWorking: json['isWorking'] ?? false,
      morning: TimeSlot.fromJson(json['morning']),
      afternoon: TimeSlot.fromJson(json['afternoon']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isWorking': isWorking,
      'morning': morning?.toJson(),
      'afternoon': afternoon?.toJson(),
    };
  }
}

/// Modèle représentant les horaires de travail hebdomadaires
class WorkingHours {
  final WorkDay monday;
  final WorkDay tuesday;
  final WorkDay wednesday;
  final WorkDay thursday;
  final WorkDay friday;
  final WorkDay saturday;
  final WorkDay sunday;

  WorkingHours({
    required this.monday,
    required this.tuesday,
    required this.wednesday,
    required this.thursday,
    required this.friday,
    required this.saturday,
    required this.sunday,
  });

  factory WorkingHours.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return WorkingHours(
        monday: WorkDay(),
        tuesday: WorkDay(),
        wednesday: WorkDay(),
        thursday: WorkDay(),
        friday: WorkDay(),
        saturday: WorkDay(),
        sunday: WorkDay(),
      );
    }
    
    return WorkingHours(
      monday: WorkDay.fromJson(json['monday']),
      tuesday: WorkDay.fromJson(json['tuesday']),
      wednesday: WorkDay.fromJson(json['wednesday']),
      thursday: WorkDay.fromJson(json['thursday']),
      friday: WorkDay.fromJson(json['friday']),
      saturday: WorkDay.fromJson(json['saturday']),
      sunday: WorkDay.fromJson(json['sunday']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'monday': monday.toJson(),
      'tuesday': tuesday.toJson(),
      'wednesday': wednesday.toJson(),
      'thursday': thursday.toJson(),
      'friday': friday.toJson(),
      'saturday': saturday.toJson(),
      'sunday': sunday.toJson(),
    };
  }
}

/// Modèle représentant les documents d'un médecin
class DoctorDocuments {
  final DocumentFile? medicalLicense;
  final List<DocumentFile>? diplomas;
  final List<DocumentFile>? certifications;

  DoctorDocuments({
    this.medicalLicense,
    this.diplomas,
    this.certifications,
  });

  factory DoctorDocuments.fromJson(Map<String, dynamic>? json) {
    if (json == null) return DoctorDocuments();
    
    List<DocumentFile>? diplomasList;
    if (json['diplomas'] != null) {
      diplomasList = (json['diplomas'] as List)
          .map((diploma) => DocumentFile.fromJson(diploma))
          .toList();
    }
    
    List<DocumentFile>? certificationsList;
    if (json['certifications'] != null) {
      certificationsList = (json['certifications'] as List)
          .map((cert) => DocumentFile.fromJson(cert))
          .toList();
    }
    
    return DoctorDocuments(
      medicalLicense: DocumentFile.fromJson(json['medicalLicense']),
      diplomas: diplomasList,
      certifications: certificationsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medicalLicense': medicalLicense?.toJson(),
      'diplomas': diplomas?.map((diploma) => diploma.toJson()).toList(),
      'certifications': certifications?.map((cert) => cert.toJson()).toList(),
    };
  }
}

/// Modèle représentant les statistiques d'un médecin
class DoctorStats {
  final int totalAppointments;
  final int completedAppointments;
  final int cancelledAppointments;
  final double averageRating;
  final int totalReviews;

  DoctorStats({
    this.totalAppointments = 0,
    this.completedAppointments = 0,
    this.cancelledAppointments = 0,
    this.averageRating = 0.0,
    this.totalReviews = 0,
  });

  factory DoctorStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return DoctorStats();
    
    return DoctorStats(
      totalAppointments: json['totalAppointments'] ?? 0,
      completedAppointments: json['completedAppointments'] ?? 0,
      cancelledAppointments: json['cancelledAppointments'] ?? 0,
      averageRating: (json['averageRating'] ?? 0.0).toDouble(),
      totalReviews: json['totalReviews'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalAppointments': totalAppointments,
      'completedAppointments': completedAppointments,
      'cancelledAppointments': cancelledAppointments,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
    };
  }
}

/// Modèle représentant une période d'indisponibilité
class UnavailableDate {
  final DateTime date;
  final String? reason;

  UnavailableDate({
    required this.date,
    this.reason,
  });

  factory UnavailableDate.fromJson(Map<String, dynamic> json) {
    return UnavailableDate(
      date: DateTime.parse(json['date']),
      reason: json['reason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'reason': reason,
    };
  }
}

/// Modèle principal représentant un médecin
class Doctor {
  final String? id;
  final String? userId;
  final String? medicalLicenseNumber;
  final List<String>? specialties;
  final int? yearsOfExperience;
  final List<Education>? education;
  final List<Certification>? certifications;
  final Clinic? clinic;
  final WorkingHours? workingHours;
  final double? consultationFee;
  final String? currency;
  final List<String>? languages;
  final String? verificationStatus;
  final DateTime? verificationDate;
  final String? verificationNotes;
  final String? verifiedBy;
  final DocumentFile? profilePhoto;
  final DoctorDocuments? documents;
  final DoctorStats? stats;
  final bool isAvailable;
  final List<UnavailableDate>? unavailableDates;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Doctor({
    this.id,
    this.userId,
    this.medicalLicenseNumber,
    this.specialties,
    this.yearsOfExperience,
    this.education,
    this.certifications,
    this.clinic,
    this.workingHours,
    this.consultationFee,
    this.currency = 'XOF',
    this.languages,
    this.verificationStatus = 'pending',
    this.verificationDate,
    this.verificationNotes,
    this.verifiedBy,
    this.profilePhoto,
    this.documents,
    this.stats,
    this.isAvailable = true,
    this.unavailableDates,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    // Traitement des listes
    List<String>? specialtiesList;
    if (json['specialties'] != null) {
      specialtiesList = List<String>.from(json['specialties']);
    }
    
    List<Education>? educationList;
    if (json['education'] != null) {
      educationList = (json['education'] as List)
          .map((edu) => Education.fromJson(edu))
          .toList();
    }
    
    List<Certification>? certificationsList;
    if (json['certifications'] != null) {
      certificationsList = (json['certifications'] as List)
          .map((cert) => Certification.fromJson(cert))
          .toList();
    }
    
    List<String>? languagesList;
    if (json['languages'] != null) {
      languagesList = List<String>.from(json['languages']);
    }
    
    List<UnavailableDate>? unavailableDatesList;
    if (json['unavailableDates'] != null) {
      unavailableDatesList = (json['unavailableDates'] as List)
          .map((date) => UnavailableDate.fromJson(date))
          .toList();
    }
    
    return Doctor(
      id: json['_id'] ?? json['id'],
      userId: json['userId'],
      medicalLicenseNumber: json['medicalLicenseNumber'],
      specialties: specialtiesList,
      yearsOfExperience: json['yearsOfExperience'],
      education: educationList,
      certifications: certificationsList,
      clinic: Clinic.fromJson(json['clinic']),
      workingHours: WorkingHours.fromJson(json['workingHours']),
      consultationFee: (json['consultationFee'] ?? 0.0).toDouble(),
      currency: json['currency'] ?? 'XOF',
      languages: languagesList,
      verificationStatus: json['verificationStatus'] ?? 'pending',
      verificationDate: json['verificationDate'] != null 
          ? DateTime.parse(json['verificationDate']) 
          : null,
      verificationNotes: json['verificationNotes'],
      verifiedBy: json['verifiedBy'],
      profilePhoto: DocumentFile.fromJson(json['profilePhoto']),
      documents: DoctorDocuments.fromJson(json['documents']),
      stats: DoctorStats.fromJson(json['stats']),
      isAvailable: json['isAvailable'] ?? true,
      unavailableDates: unavailableDatesList,
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'medicalLicenseNumber': medicalLicenseNumber,
      'specialties': specialties,
      'yearsOfExperience': yearsOfExperience,
      'education': education?.map((edu) => edu.toJson()).toList(),
      'certifications': certifications?.map((cert) => cert.toJson()).toList(),
      'clinic': clinic?.toJson(),
      'workingHours': workingHours?.toJson(),
      'consultationFee': consultationFee,
      'currency': currency,
      'languages': languages,
      'verificationStatus': verificationStatus,
      'verificationDate': verificationDate?.toIso8601String(),
      'verificationNotes': verificationNotes,
      'verifiedBy': verifiedBy,
      'profilePhoto': profilePhoto?.toJson(),
      'documents': documents?.toJson(),
      'stats': stats?.toJson(),
      'isAvailable': isAvailable,
      'unavailableDates': unavailableDates?.map((date) => date.toJson()).toList(),
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
