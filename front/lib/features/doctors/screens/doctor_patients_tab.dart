import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/doctor_patients_provider.dart';
import '../models/patient_model.dart';

class DoctorPatientsTab extends StatefulWidget {
  const DoctorPatientsTab({super.key});

  @override
  State<DoctorPatientsTab> createState() => _DoctorPatientsTabState();
}

class _DoctorPatientsTabState extends State<DoctorPatientsTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Charger les patients au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DoctorPatientsProvider>(context, listen: false).loadPatients();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DoctorPatientsProvider>(
      builder: (context, provider, child) {
        return SafeArea(
          child: RefreshIndicator(
            onRefresh: provider.refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(provider),
                        const SizedBox(height: 24),
                        _buildSearchBar(provider),
                        const SizedBox(height: 24),
                        _buildStatsCards(provider),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                _buildPatientsList(provider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(DoctorPatientsProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Mes patients',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        if (!provider.isLoading)
          Text(
            '${provider.totalPatients} patient${provider.totalPatients > 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  Widget _buildSearchBar(DoctorPatientsProvider provider) {
    return TextField(
      controller: _searchController,
      onChanged: provider.searchPatients,
      decoration: InputDecoration(
        hintText: 'Rechercher un patient...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  provider.searchPatients('');
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
      ),
    );
  }

  Widget _buildStatsCards(DoctorPatientsProvider provider) {
    if (provider.isLoading || provider.patients.isEmpty) {
      return const SizedBox.shrink();
    }

    final stats = provider.getPatientStats();
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total',
            stats['total'].toString(),
            Icons.people,
            AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Nouveaux',
            stats['new'].toString(),
            Icons.person_add,
            const Color.fromARGB(255, 58, 105, 171),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Réguliers',
            stats['regular'].toString(),
            Icons.favorite,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientsList(DoctorPatientsProvider provider) {
    if (provider.isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (provider.error != null) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Erreur',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.errorColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                provider.error!,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: provider.loadPatients,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.patients.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: AppTheme.textSecondary.withAlpha(128),
              ),
              const SizedBox(height: 16),
              Text(
                provider.searchQuery.isNotEmpty 
                    ? 'Aucun patient trouvé'
                    : 'Aucun patient',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                provider.searchQuery.isNotEmpty
                    ? 'Essayez avec d\'autres mots-clés'
                    : 'Les patients apparaîtront ici après leurs premiers rendez-vous confirmés',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final patient = provider.patients[index];
            return _buildPatientCard(patient);
          },
          childCount: provider.patients.length,
        ),
      ),
    );
  }

  Widget _buildPatientCard(PatientModel patient) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color.fromARGB(255, 32, 160, 200),
                  child: Text(
                    patient.firstName.isNotEmpty 
                        ? patient.firstName[0].toUpperCase() 
                        : 'P',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      if (patient.age != null)
                        Text(
                          '${patient.age} ans • ${patient.genderDisplay}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: patient.totalAppointments == 1 
                            ? Colors.green.withValues(alpha: 0.1)
                            : Color.fromARGB(255, 32, 160, 200).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        patient.totalAppointments == 1 ? 'Nouveau' : 'Régulier',
                        style: TextStyle(
                          fontSize: 12,
                          color: patient.totalAppointments == 1 
                              ? Colors.green
                              : Color.fromARGB(255, 32, 160, 200),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(
                  patient.phone ?? 'Non renseigné',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Dernier RDV: ${patient.formattedLastAppointment}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.medical_services, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(
                  '${patient.completedAppointments}/${patient.totalAppointments} consultations terminées',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
