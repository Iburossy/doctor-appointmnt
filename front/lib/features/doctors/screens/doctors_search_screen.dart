import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

import '../../location/providers/location_provider.dart';
import '../providers/doctors_provider.dart';
import '../models/doctor_model.dart';
import '../../../shared/widgets/loading_overlay.dart';

class DoctorsSearchScreen extends StatefulWidget {
  const DoctorsSearchScreen({super.key});

  @override
  State<DoctorsSearchScreen> createState() => _DoctorsSearchScreenState();
}

class _DoctorsSearchScreenState extends State<DoctorsSearchScreen> {
  final _searchController = TextEditingController();
  String? _selectedSpecialization;
  double _searchRadius = 10.0; // km
  bool _showFilters = false;

  final List<String> _specializations = [
    'Médecine générale',
    'Cardiologie',
    'Dermatologie',
    'Gynécologie',
    'Pédiatrie',
    'Ophtalmologie',
    'ORL',
    'Orthopédie',
    'Psychiatrie',
    'Radiologie',
    'Neurologie',
    'Urologie',
    'Dentisterie',
    'Kinésithérapie',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSearch();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeSearch() async {
    final locationProvider = context.read<LocationProvider>();
    
    // Get current location if not already available
    if (!locationProvider.hasLocation) {
      await locationProvider.getCurrentLocation();
    }
    
    // Perform initial search
    await _performSearch();
  }

  Future<void> _performSearch() async {
    final doctorsProvider = context.read<DoctorsProvider>();
    final locationProvider = context.read<LocationProvider>();
    
    await doctorsProvider.searchDoctors(
      query: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      specialization: _selectedSpecialization,
      latitude: locationProvider.currentPosition?.latitude,
      longitude: locationProvider.currentPosition?.longitude,
      radius: _searchRadius,
      sortBy: 'distance',
    );
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedSpecialization = null;
      _searchRadius = 10.0;
      _searchController.clear();
    });
    _performSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer2<DoctorsProvider, LocationProvider>(
        builder: (context, doctorsProvider, locationProvider, child) {
          return LoadingOverlay(
            isLoading: doctorsProvider.isSearching,
            child: CustomScrollView(
              slivers: [
                // App Bar
                SliverAppBar(
                  expandedHeight: _showFilters ? 280 : 210,
                  floating: false,
                  pinned: true,
                  backgroundColor: AppTheme.primaryColor,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Stack(
                          children: [
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildSearchBar(),
                                  const SizedBox(height: 16),
                                  _buildFilterToggle(),
                                  if (_showFilters) ...[
                                    const SizedBox(height: 16),
                                    _buildFilters(),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Results Header
                SliverToBoxAdapter(
                  child: _buildResultsHeader(doctorsProvider, locationProvider),
                ),
                
                // Doctors List
                if (doctorsProvider.error != null)
                  SliverToBoxAdapter(
                    child: _buildErrorWidget(doctorsProvider.error!),
                  )
                else if (doctorsProvider.searchResults.isEmpty && !doctorsProvider.isSearching)
                  SliverToBoxAdapter(
                    child: _buildEmptyState(),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final doctor = doctorsProvider.searchResults[index];
                        return _buildDoctorCard(doctor);
                      },
                      childCount: doctorsProvider.searchResults.length,
                    ),
                  ),
                
                // Bottom spacing
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher un médecin, spécialité...',
          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        onSubmitted: (_) => _performSearch(),
      ),
    );
  }

  Widget _buildFilterToggle() {
    return GestureDetector(
      onTap: _toggleFilters,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tune, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              _showFilters ? 'Masquer les filtres' : 'Afficher les filtres',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Specialization Filter
          const Text(
            'Spécialité',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSpecialization,
                hint: const Text('Toutes les spécialités'),
                isExpanded: true,
                items: _specializations.map((spec) {
                  return DropdownMenuItem(
                    value: spec,
                    child: Text(spec),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSpecialization = value;
                  });
                  _performSearch();
                },
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Radius Filter
          Row(
            children: [
              const Text(
                'Rayon de recherche: ',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${_searchRadius.round()} km',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: _searchRadius,
            min: 1.0,
            max: 50.0,
            divisions: 49,
            activeColor: Colors.white,
            inactiveColor: Colors.white.withValues(alpha: 0.3),
            onChanged: (value) {
              setState(() {
                _searchRadius = value;
              });
            },
            onChangeEnd: (value) => _performSearch(),
          ),
          
          // Clear Filters Button
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _clearFilters,
              child: const Text(
                'Effacer les filtres',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsHeader(DoctorsProvider doctorsProvider, LocationProvider locationProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            color: AppTheme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              locationProvider.hasLocation
                  ? 'Médecins près de vous'
                  : 'Tous les médecins',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ),
          if (doctorsProvider.searchResults.isNotEmpty)
            Text(
              '${doctorsProvider.searchResults.length} résultat${doctorsProvider.searchResults.length > 1 ? 's' : ''}',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(DoctorModel doctor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.goNamed('doctor-details', pathParameters: {'id': doctor.id}),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  backgroundImage: doctor.avatar != null
                      ? NetworkImage(doctor.avatar!)
                      : null,
                  child: doctor.avatar == null
                      ? Icon(
                          Icons.person,
                          color: AppTheme.primaryColor,
                          size: 30,
                        )
                      : null,
                ),
                
                const SizedBox(width: 16),
                
                // Doctor Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and verification
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              doctor.displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                          ),
                          if (doctor.isVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Vérifié',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Specialization
                      if (doctor.specialization != null)
                        Text(
                          doctor.specialization!,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      
                      const SizedBox(height: 8),
                      
                      // Rating, Experience, Distance
                      Row(
                        children: [
                          // Rating
                          if (doctor.rating > 0) ...[
                            Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              doctor.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          
                          // Experience
                          if (doctor.experienceYears != null) ...[
                            Icon(
                              Icons.work_outline,
                              color: AppTheme.textSecondary,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${doctor.experienceYears} ans',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          
                          // Distance
                          if (doctor.distance != null) ...[
                            Icon(
                              Icons.location_on,
                              color: AppTheme.textSecondary,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              doctor.formattedDistance,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Availability and Fee
                      Row(
                        children: [
                          // Availability
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: doctor.isAvailable
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              doctor.isAvailable ? 'Disponible' : 'Indisponible',
                              style: TextStyle(
                                color: doctor.isAvailable
                                    ? Colors.green
                                    : Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          
                          const Spacer(),
                          
                          // Consultation Fee
                          if (doctor.consultationFee != null)
                            Text(
                              doctor.formattedFee,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun médecin trouvé',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez d\'élargir votre zone de recherche ou de modifier vos filtres.',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _clearFilters,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            child: const Text('Effacer les filtres'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Erreur de chargement',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _performSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
