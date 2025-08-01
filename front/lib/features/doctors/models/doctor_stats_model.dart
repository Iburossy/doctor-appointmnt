class DoctorStatsModel {
  final int totalAppointments;
  final int completedAppointments;
  final int cancelledAppointments;
  final double averageRating;
  final int totalReviews;
  final String? verificationStatus;

  DoctorStatsModel({
    this.totalAppointments = 0,
    this.completedAppointments = 0,
    this.cancelledAppointments = 0,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.verificationStatus,
  });

  factory DoctorStatsModel.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] ?? {};
    return DoctorStatsModel(
      totalAppointments: stats['totalAppointments'] ?? 0,
      completedAppointments: stats['completedAppointments'] ?? 0,
      cancelledAppointments: stats['cancelledAppointments'] ?? 0,
      averageRating: (stats['averageRating'] ?? 0.0).toDouble(),
      totalReviews: stats['totalReviews'] ?? 0,
      verificationStatus: json['verificationStatus'],
    );
  }

  /// Calcule le nombre de patients vus (basé sur les rendez-vous terminés)
  int get patientsCount => completedAppointments;
  
  /// Calcule les rendez-vous prévus aujourd'hui (dans ce cas, on utilise le total comme approximation)
  int get todaysAppointments => totalAppointments - completedAppointments - cancelledAppointments;
  
  /// Retourne la note moyenne formatée sur 5
  String get ratingText => '${averageRating.toStringAsFixed(1)}/5';
  
  /// Calcule un revenu approximatif basé sur le nombre de consultations terminées
  /// (50€ par consultation en moyenne)
  String get monthlyRevenue {
    // On suppose que 60% des consultations totales sont pour le mois en cours
    int estimatedMonthlyAppointments = (completedAppointments * 0.6).round();
    int revenue = estimatedMonthlyAppointments * 50;
    return '${revenue.toString()}€';
  }
}
