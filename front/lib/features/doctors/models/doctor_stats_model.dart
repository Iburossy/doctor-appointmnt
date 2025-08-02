import 'package:intl/intl.dart';

class DoctorStatsModel {
  final int totalAppointments;
  final int totalPatients;
  final double monthlyIncome;
  final double totalIncome;
  final double averageRating;
  final int totalReviews;
  final String currency;
  final String? verificationStatus;

  DoctorStatsModel({
    this.totalAppointments = 0,
    this.totalPatients = 0,
    this.monthlyIncome = 0.0,
    this.totalIncome = 0.0,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.currency = 'XOF',
    this.verificationStatus,
  });

  factory DoctorStatsModel.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] ?? {};
    final monthlyIncomeData = stats['monthlyIncome'];

    double income = 0.0;
    if (monthlyIncomeData is Map<String, dynamic>) {
        final currentMonth = new DateFormat('yyyy-MM').format(DateTime.now());
        if (monthlyIncomeData['month'] == currentMonth) {
            income = (monthlyIncomeData['amount'] ?? 0.0).toDouble();
        }
    }

    return DoctorStatsModel(
      totalAppointments: (stats['totalAppointments'] ?? 0).toInt(),
      totalPatients: (stats['totalPatients'] ?? 0).toInt(),
      monthlyIncome: income,
      totalIncome: (stats['totalIncome'] ?? 0.0).toDouble(),
      averageRating: (stats['averageRating'] ?? 0.0).toDouble(),
      totalReviews: (stats['totalReviews'] ?? 0).toInt(),
      currency: stats['currency'] ?? 'XOF',
      verificationStatus: json['verificationStatus'],
    );
  }

  // TODO: Ces getters pourraient être améliorés pour refléter des données plus précises
  int get patientsCount => totalPatients;
  int get todaysAppointments => 0; // Cette donnée n'est pas fournie par l'API pour l'instant

  String get ratingText => '${averageRating.toStringAsFixed(1)}/5';

  String get formattedMonthlyIncome {
    final format = NumberFormat.currency(locale: 'fr_SN', symbol: currency, decimalDigits: 0);
    return format.format(monthlyIncome);
  }
}
