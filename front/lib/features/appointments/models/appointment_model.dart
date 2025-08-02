import '../../doctors/models/doctor_model.dart';

class AppointmentModel {
  final String id;
  final String patientId;
  final String doctorId;
  final DateTime appointmentDate;
  final String timeSlot;
  final String status; // 'pending', 'confirmed', 'completed', 'cancelled'
  final String? reason;
  final List<String> symptoms; // Liste des symptômes
  final String? notes;
  final String? diagnosis;
  final List<String> prescription; // Liste des prescriptions
  final String? doctorNotes;
  final String? cancellationReason;
  final int? duration; // Durée en minutes
  final String? consultationType; // Type de consultation
  final PaymentInfo? paymentInfo;
  final ReviewModel? review;
  final DoctorModel? doctorInfo; // Populated doctor information
  final dynamic patient; // Patient information
  final DateTime createdAt;
  final DateTime updatedAt;

  AppointmentModel({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.appointmentDate,
    required this.timeSlot,
    required this.status,
    this.reason,
    this.symptoms = const [],
    this.notes,
    this.diagnosis,
    this.prescription = const [],
    this.doctorNotes,
    this.cancellationReason,
    this.duration,
    this.consultationType,
    this.paymentInfo,
    this.review,
    this.doctorInfo,
    this.patient,
    required this.createdAt,
    required this.updatedAt,
  });

  // Status getters
  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  // Time getters
  bool get isUpcoming => appointmentDate.isAfter(DateTime.now()) && !isCancelled;
  bool get isPast => appointmentDate.isBefore(DateTime.now()) || isCompleted;
  bool get isToday {
    final now = DateTime.now();
    return appointmentDate.year == now.year &&
           appointmentDate.month == now.month &&
           appointmentDate.day == now.day;
  }

  // Formatted date and time
  String get formattedDate {
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    
    return '${appointmentDate.day} ${months[appointmentDate.month - 1]} ${appointmentDate.year}';
  }

  String get formattedTime => timeSlot;

  String get formattedDateTime => '$formattedDate à $formattedTime';

  // Status display
  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'confirmed':
        return 'Confirmé';
      case 'completed':
        return 'Terminé';
      case 'cancelled':
        return 'Annulé';
      default:
        return status;
    }
  }

  // Status color
  String get statusColor {
    switch (status) {
      case 'pending':
        return 'orange';
      case 'confirmed':
        return 'blue';
      case 'completed':
        return 'green';
      case 'cancelled':
        return 'red';
      default:
        return 'grey';
    }
  }

  // Can be cancelled
  bool get canBeCancelled {
    return (isPending || isConfirmed) && 
           appointmentDate.isAfter(DateTime.now().add(const Duration(hours: 2)));
  }

  // Can be rescheduled
  bool get canBeRescheduled {
    return (isPending || isConfirmed) && 
           appointmentDate.isAfter(DateTime.now().add(const Duration(hours: 2)));
  }

  // Can be reviewed
  bool get canBeReviewed {
    return isCompleted && review == null;
  }

  // Time until appointment
  String get timeUntilAppointment {
    if (isPast) return 'Passé';
    
    final now = DateTime.now();
    final difference = appointmentDate.difference(now);
    
    if (difference.inDays > 0) {
      return 'Dans ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Dans ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Dans ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Maintenant';
    }
  }

  // Méthode utilitaire pour parser n'importe quel champ de type liste
  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    
    if (value is List) {
      return List<String>.from(value.map((s) => s.toString()));
    } else if (value is String) {
      return [value];
    }
    
    return [];
  }

  // Factory constructor from JSON
  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    try {
      
      
      // Extraire les informations du patient et du médecin si elles sont imbriquées
      
      final patientData = json['patient'] is Map ? json['patient'] as Map<String, dynamic> : null;
      final doctorData = json['doctor'] is Map ? json['doctor'] as Map<String, dynamic> : null;
      final paymentData = json['payment'] is Map ? json['payment'] as Map<String, dynamic> : null;
      
      // Ignorer les champs complexes pour éviter les erreurs de parsing
      
      final jsonCopy = Map<String, dynamic>.from(json);
      
      // Supprimer tous les champs complexes non essentiels
      final fieldsToRemove = [
        'reminders', 'documents', 'files', 'medicalRecords', 'notifications',
        'messages', 'attachments', 'history', 'timeline', 'followUps'
      ];
      
      for (final field in fieldsToRemove) {
        jsonCopy.remove(field);
      }
      
      
      jsonCopy.forEach((key, value) {
        
      });
    
    
    
    // Traiter chaque champ individuellement avec des logs
    
    final id = jsonCopy['_id'] ?? jsonCopy['id'] ?? '';
    
    
    final patientId = patientData?['_id'] ?? patientData?['id'] ?? jsonCopy['patient'] ?? '';
    
    
    final doctorId = doctorData?['_id'] ?? doctorData?['id'] ?? jsonCopy['doctor'] ?? '';
    
    
    
    final appointmentDate = DateTime.parse(jsonCopy['appointmentDate']);
    
    
    final timeSlot = jsonCopy['appointmentTime'] ?? jsonCopy['timeSlot'] ?? '';
    
    
    final status = jsonCopy['status'] ?? 'pending';
    
    
    
    final reason = jsonCopy['reason'];
    
    
    final symptoms = _parseStringList(jsonCopy['symptoms']);
    
    
    final notes = jsonCopy['patientNotes'] ?? jsonCopy['notes'];
    
    
    final diagnosis = jsonCopy['diagnosis'];
    
    
    final prescription = _parseStringList(jsonCopy['prescription']);
    
    
    final doctorNotes = jsonCopy['doctorNotes'];
    
    
    final cancellationReason = jsonCopy['cancellationReason'];
    
    
    final duration = jsonCopy['duration'];
    
    
    final consultationType = jsonCopy['consultationType'];
    
    
    final paymentInfoObj = paymentData != null
        ? PaymentInfo.fromJson(paymentData)
        : (jsonCopy['paymentInfo'] != null ? PaymentInfo.fromJson(jsonCopy['paymentInfo']) : null);
    
    
    final reviewObj = jsonCopy['review'] != null
        ? ReviewModel.fromJson(jsonCopy['review'])
        : null;
    
    
    final doctorInfoObj = doctorData != null
        ? DoctorModel.fromJson(doctorData)
        : (jsonCopy['doctorInfo'] != null ? DoctorModel.fromJson(jsonCopy['doctorInfo']) : null);
    
    
    final patientObj = patientData ?? jsonCopy['patient'];
    
    
    
    final createdAt = jsonCopy['createdAt'] != null ? DateTime.parse(jsonCopy['createdAt']) : DateTime.now();
    
    
    final updatedAt = jsonCopy['updatedAt'] != null ? DateTime.parse(jsonCopy['updatedAt']) : DateTime.now();
    
    
    return AppointmentModel(
      id: id,
      patientId: patientId,
      doctorId: doctorId,
      appointmentDate: appointmentDate,
      timeSlot: timeSlot,
      status: status,
      reason: reason,
      symptoms: symptoms,
      notes: notes,
      diagnosis: diagnosis,
      prescription: prescription,
      doctorNotes: doctorNotes,
      cancellationReason: cancellationReason,
      duration: duration,
      consultationType: consultationType,
      paymentInfo: paymentInfoObj,
      review: reviewObj,
      doctorInfo: doctorInfoObj,
      patient: patientObj,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
    } catch (e, stackTrace) {
      
      rethrow;
    }
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'doctorId': doctorId,
      'appointmentDate': appointmentDate.toIso8601String(),
      'timeSlot': timeSlot,
      'status': status,
      'reason': reason,
      'symptoms': symptoms,
      'notes': notes,
      'diagnosis': diagnosis,
      'prescription': prescription,
      'doctorNotes': doctorNotes,
      'cancellationReason': cancellationReason,
      'duration': duration,
      'consultationType': consultationType,
      'paymentInfo': paymentInfo?.toJson(),
      'review': review?.toJson(),
      'doctorInfo': doctorInfo?.toJson(),
      'patient': patient,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Copy with method
  AppointmentModel copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    DateTime? appointmentDate,
    String? timeSlot,
    String? status,
    String? reason,
    List<String>? symptoms,
    String? notes,
    String? diagnosis,
    List<String>? prescription,
    String? doctorNotes,
    String? cancellationReason,
    int? duration,
    String? consultationType,
    PaymentInfo? paymentInfo,
    ReviewModel? review,
    DoctorModel? doctorInfo,
    dynamic patient,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      timeSlot: timeSlot ?? this.timeSlot,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      symptoms: symptoms ?? this.symptoms,
      notes: notes ?? this.notes,
      diagnosis: diagnosis ?? this.diagnosis,
      prescription: prescription ?? this.prescription,
      doctorNotes: doctorNotes ?? this.doctorNotes,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      duration: duration ?? this.duration,
      consultationType: consultationType ?? this.consultationType,
      paymentInfo: paymentInfo ?? this.paymentInfo,
      review: review ?? this.review,
      doctorInfo: doctorInfo ?? this.doctorInfo,
      patient: patient ?? this.patient,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PaymentInfo {
  final double amount;
  final String currency;
  final String status; // 'pending', 'paid', 'failed', 'refunded'
  final String? method; // 'cash', 'mobile_money', 'card'
  final String? transactionId;
  final DateTime? paidAt;

  PaymentInfo({
    required this.amount,
    required this.currency,
    required this.status,
    this.method,
    this.transactionId,
    this.paidAt,
  });

  // Status getters
  bool get isPending => status == 'pending';
  bool get isPaid => status == 'paid';
  bool get isFailed => status == 'failed';
  bool get isRefunded => status == 'refunded';

  // Formatted amount
  String get formattedAmount {
    return '${amount.toStringAsFixed(0)} $currency';
  }

  // Status display
  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'paid':
        return 'Payé';
      case 'failed':
        return 'Échec';
      case 'refunded':
        return 'Remboursé';
      default:
        return status;
    }
  }

  factory PaymentInfo.fromJson(Map<String, dynamic> json) {
    return PaymentInfo(
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'FCFA',
      status: json['status'] ?? 'pending',
      method: json['method'],
      transactionId: json['transactionId'],
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'currency': currency,
      'status': status,
      'method': method,
      'transactionId': transactionId,
      'paidAt': paidAt?.toIso8601String(),
    };
  }
}

class ReviewModel {
  final int rating;
  final String? comment;
  final DateTime createdAt;

  ReviewModel({
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  // Formatted rating
  String get formattedRating {
    return '$rating/5 étoiles';
  }

  // Rating stars
  String get ratingStars {
    return '★' * rating + '☆' * (5 - rating);
  }

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      rating: json['rating'] ?? 0,
      comment: json['comment'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
