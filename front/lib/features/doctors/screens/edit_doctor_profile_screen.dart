import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../providers/doctor_profile_provider.dart';
import '../../auth/models/user_model.dart'; // Utilise ClinicInfo de user_model

class EditDoctorProfileScreen extends StatefulWidget {
  const EditDoctorProfileScreen({super.key});

  @override
  State<EditDoctorProfileScreen> createState() => _EditDoctorProfileScreenState();
}

class _EditDoctorProfileScreenState extends State<EditDoctorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _specializationController = TextEditingController();
  final _licenseController = TextEditingController();
  final _experienceController = TextEditingController();
  final _educationController = TextEditingController();
  final _bioController = TextEditingController();
  final _consultationFeeController = TextEditingController();
  final _clinicNameController = TextEditingController();
  final _clinicAddressController = TextEditingController();
  final _clinicPhoneController = TextEditingController();

  List<String> _selectedLanguages = [];
  bool _isLoading = false;

  final List<String> _availableLanguages = [
    'Français',
    'Wolof',
    'Arabe',
    'Anglais',
    'Pulaar',
    'Serer',
    'Diola',
    'Mandinka',
  ];

  // Liste des spécialisations supprimée car les champs sont en lecture seule

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _specializationController.dispose();
    _licenseController.dispose();
    _experienceController.dispose();
    _educationController.dispose();
    _bioController.dispose();
    _consultationFeeController.dispose();
    _clinicNameController.dispose();
    _clinicAddressController.dispose();
    _clinicPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentProfile() async {
    final provider = context.read<DoctorProfileProvider>();
    await provider.getDoctorProfile();
    
    final profile = provider.doctorProfile;
    if (profile != null) {
      setState(() {
        _specializationController.text = (profile.specialization?.join(', ') ?? '');
        _licenseController.text = profile.medicalLicenseNumber ?? '';
        _experienceController.text = profile.yearsOfExperience?.toString() ?? '';
        
        // Handle education - SÉCURITÉ: extraire seulement le degree, jamais les IDs
        if (profile.education != null && profile.education!.isNotEmpty) {
          final educationItem = profile.education!.first;
          String safeEducationText = '';
          
          if (educationItem is Map<String, dynamic>) {
            // SÉCURITÉ: Extraire UNIQUEMENT le champ degree, ignorer _id, id, etc.
            final degree = educationItem['degree'];
            if (degree != null && degree is String) {
              // Nettoyer le texte pour éviter l'injection et les données sensibles
              safeEducationText = degree.replaceAll(RegExp(r'[{}\[\]_id:,]'), '').trim();
            }
          } else if (educationItem is String) {
            // Si c'est déjà une chaîne, la nettoyer aussi
            safeEducationText = educationItem.replaceAll(RegExp(r'[{}\[\]_id:,]'), '').trim();
          }
          
          _educationController.text = safeEducationText;
        }
        
        // Use clinic description instead of bio
        _bioController.text = profile.clinicDescription ?? '';
        _consultationFeeController.text = profile.consultationFee?.toString() ?? '';
        
        // Handle languages which is now a List<dynamic>?
        if (profile.languages != null) {
          _selectedLanguages = profile.languages!.map((lang) => lang.toString()).toList();
        }
        
        // Handle clinic info which is now a Map<String, dynamic>?
        if (profile.clinic != null) {
          _clinicNameController.text = profile.clinicName;
          _clinicAddressController.text = profile.clinicAddress;
          _clinicPhoneController.text = profile.clinicPhone ?? '';
        }
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final provider = context.read<DoctorProfileProvider>();
    
    // Créer l'objet ClinicInfo avec la structure correcte (user_model.dart)
    final clinicInfo = ClinicInfo(
      name: _clinicNameController.text.trim(),
      address: _clinicAddressController.text.trim(),
      phone: _clinicPhoneController.text.trim(),
      location: null, // TODO: Ajouter un sélecteur de localisation
    );

    // Ne pas envoyer les champs sensibles (spécialisation et numéro d'ordre médical)
    // pour des raisons de sécurité
    final success = await provider.updateDoctorProfile(
      // specialization et licenseNumber sont omis intentionnellement
      experienceYears: int.tryParse(_experienceController.text.trim()),
      education: _educationController.text.trim(),
      bio: _bioController.text.trim(),
      languages: _selectedLanguages,
      consultationFee: double.tryParse(_consultationFeeController.text.trim()),
      clinicInfo: clinicInfo,
    );

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Erreur lors de la mise à jour'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Modifier le profil',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimaryColor),
        actions: [
          Consumer<DoctorProfileProvider>(
            builder: (context, provider, child) {
              return TextButton(
                onPressed: _isLoading || provider.isUpdating ? null : _saveProfile,
                child: _isLoading || provider.isUpdating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Sauvegarder',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
              );
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Informations professionnelles
              _buildSectionTitle('Informations professionnelles'),
              
              // Champ de spécialisation en lecture seule
              _buildTextField(
                controller: _specializationController,
                label: 'Spécialisation',
                readOnly: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez sélectionner une spécialisation';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Numéro d'ordre médical en lecture seule
              _buildTextField(
                controller: _licenseController,
                label: 'Numéro d\'ordre médical',
                readOnly: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez saisir votre numéro d\'ordre';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _experienceController,
                label: 'Années d\'expérience',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez saisir vos années d\'expérience';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Veuillez saisir un nombre valide';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _educationController,
                label: 'Formation',
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez saisir votre formation';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _consultationFeeController,
                label: 'Tarif de consultation (FCFA)',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (double.tryParse(value) == null) {
                      return 'Veuillez saisir un montant valide';
                    }
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // Langues parlées
              _buildSectionTitle('Langues parlées'),
              
              _buildLanguageSelector(),
              
              const SizedBox(height: 24),
              
              // Cabinet médical
              _buildSectionTitle('Cabinet médical'),
              
              _buildTextField(
                controller: _clinicNameController,
                label: 'Nom du cabinet',
              ),
              
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _clinicAddressController,
                label: 'Adresse du cabinet',
                maxLines: 2,
              ),
              
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _clinicPhoneController,
                label: 'Téléphone du cabinet',
                keyboardType: TextInputType.phone,
              ),
              
              const SizedBox(height: 24),
              
              // Bio
              _buildSectionTitle('À propos'),
              
              _buildTextField(
                controller: _bioController,
                label: 'Biographie',
                maxLines: 4,
                hintText: 'Décrivez votre parcours, vos spécialités, votre approche...',
              ),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      readOnly: readOnly,
      enabled: !readOnly,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  // Méthode de dropdown supprimée car les champs sensibles sont en lecture seule

  Widget _buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sélectionnez les langues que vous parlez :',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableLanguages.map((language) {
              final isSelected = _selectedLanguages.contains(language);
              return FilterChip(
                label: Text(language),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedLanguages.add(language);
                    } else {
                      _selectedLanguages.remove(language);
                    }
                  });
                },
                selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                checkmarkColor: AppTheme.primaryColor,
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
