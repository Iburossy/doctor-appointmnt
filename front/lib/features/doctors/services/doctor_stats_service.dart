import '../../../core/services/api_service.dart';
import '../models/doctor_stats_model.dart';

class DoctorStatsService {
  final ApiService _apiService = ApiService();
  static const String _baseUrl = '/doctors';

  /// Récupère les statistiques du médecin connecté
  Future<DoctorStatsModel> getDoctorStats() async {
    try {
      final response = await _apiService.get('$_baseUrl/me/stats');
      if (response.isSuccess) {
        return DoctorStatsModel.fromJson(response.data);
      } else {
        throw Exception('Erreur: ${response.message}');
      }
    } catch (e) {
      throw Exception('Erreur lors de la récupération des statistiques: $e');
    }
  }
}
