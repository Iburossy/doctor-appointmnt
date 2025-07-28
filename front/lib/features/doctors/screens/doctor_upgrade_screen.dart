import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/routes/app_router.dart';
import '../../../models/doctor.dart';
import '../../../core/services/doctor_upload_service.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/loading_overlay.dart';


class DoctorUpgradeScreen extends StatefulWidget {
  const DoctorUpgradeScreen({super.key});

  @override
  State<DoctorUpgradeScreen> createState() => _DoctorUpgradeScreenState();
}

class _DoctorUpgradeScreenState extends State<DoctorUpgradeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _specializationController = TextEditingController();
  final _licenseController = TextEditingController();
  final _experienceController = TextEditingController();
  final _educationController = TextEditingController();
  final _bioController = TextEditingController();
  final _consultationFeeController = TextEditingController();
  final _clinicNameController = TextEditingController();
  final _clinicAddressController = TextEditingController();
  final _clinicCityController = TextEditingController(); // Ajout du contrôleur pour la ville
  final _clinicPhoneController = TextEditingController();
  
  final List<String> _selectedLanguages = ['Français'];
  File? _licenseDocument;
  File? _diplomaDocument;
  bool _isLoading = false;
  int _currentStep = 0;
  String? _detectedStreet;
  String? _detectedCity;
  Coordinates? _detectedCoordinates;
  
  final List<String> _specializations = [
    'Médecine générale',
    'Cardiologie',
    'Dermatologie',
    'Gynécologie',
    'Pédiatrie',
    'Neurologie',
    'Ophtalmologie',
    'Orthopédie',
    'Psychiatrie',
    'Radiologie',
    'Urologie',
    'Autre',
  ];
  
  final List<String> _languages = [
    'Français', // Attention à l'encodage spécial requis par le backend
    'Wolof',
    'Arabe',
    'Anglais',
    'Pulaar',
    'Serer',
    'Diola',
    'Mandinka',
  ];
  
  Future<void> _getCurrentLocationAndFillAddress() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Gérer les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('La permission de localisation est requise.')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La permission de localisation est bloquée. Veuillez l\'activer dans les paramètres.')),
        );
        return;
      }

      // 2. Obtenir la position
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 3. Convertir la position en adresse (geocoding)
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks[0];
        final String street = place.street ?? '';
        final String city = place.locality ?? '';
        final String fullAddress = '$street, $city, ${place.country}';

        // 4. Remplir les champs
        setState(() {
          // Mettre à jour les variables d'état pour la soumission
          _detectedStreet = street;
          _detectedCity = city;
          _detectedCoordinates = Coordinates(
            latitude: position.latitude,
            longitude: position.longitude,
          );

          // Mettre à jour les contrôleurs pour l'affichage
          _clinicAddressController.text = street;
          _clinicCityController.text = city;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Adresse remplie: $fullAddress')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de déterminer l\'adresse.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de géolocalisation: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
    _clinicCityController.dispose();
    _clinicPhoneController.dispose();
    super.dispose();
  }
  
  Future<void> _pickDocument(bool isLicense) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    
    if (image != null) {
      setState(() {
        if (isLicense) {
          _licenseDocument = File(image.path);
        } else {
          _diplomaDocument = File(image.path);
        }
      });
    }
  }
  
  Future<void> _submitUpgradeRequest() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Vérifier si les documents requis sont présents
    if (_licenseDocument == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez télécharger votre licence médicale'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_diplomaDocument == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez télécharger votre diplôme médical'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Valider que l'adresse a été détectée
      if (_detectedStreet == null || _detectedCity == null || _detectedCoordinates == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Veuillez détecter l\'adresse de votre cabinet avant de soumettre.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return; // Arrêter la soumission
      }

      // Créer d'abord l'objet ClinicAddress en utilisant les données détectées
      final address = ClinicAddress(
        street: _detectedStreet!,
        city: _detectedCity!,
        region: 'Dakar', // TODO: Potentiellement à obtenir via geocoding
        country: 'Sénégal', // TODO: Potentiellement à obtenir via geocoding
        coordinates: _detectedCoordinates!,
      );
      
      // Créer ensuite l'objet Clinic qui utilisera sa méthode toJson() pour formater l'adresse
      final clinic = Clinic(
        name: _clinicNameController.text,
        address: address,
        phone: _clinicPhoneController.text,
        description: 'Cabinet médical de ${_clinicNameController.text}',
      );
      
      final Map<String, dynamic> formData = {
        'medicalLicenseNumber': _licenseController.text,
        'specialties': [_specializationController.text], // Convertir en tableau
        'yearsOfExperience': int.tryParse(_experienceController.text) ?? 0,
        'education': [
          {
            'degree': _educationController.text,
            'institution': 'Non spécifié',
            'field': 'Médecine',
            'graduationYear': DateTime.now().year
          }
        ],
        'bio': _bioController.text,
        'languages': _selectedLanguages,
        'consultationFee': double.tryParse(_consultationFeeController.text) ?? 0,
        'clinic': clinic.toJson(), // Utiliser la méthode toJson() qui formatera correctement l'adresse
        // Ajouter des horaires par défaut
        'workingHours': {
          'monday': {
            'isWorking': true,
            'morning': { 'start': '08:00', 'end': '12:00' },
            'afternoon': { 'start': '15:00', 'end': '18:00' }
          },
          'tuesday': {
            'isWorking': true,
            'morning': { 'start': '08:00', 'end': '12:00' },
            'afternoon': { 'start': '15:00', 'end': '18:00' }
          },
          'wednesday': {
            'isWorking': true,
            'morning': { 'start': '08:00', 'end': '12:00' },
            'afternoon': { 'start': '15:00', 'end': '18:00' }
          },
          'thursday': {
            'isWorking': true,
            'morning': { 'start': '08:00', 'end': '12:00' },
            'afternoon': { 'start': '15:00', 'end': '18:00' }
          },
          'friday': {
            'isWorking': true,
            'morning': { 'start': '08:00', 'end': '12:00' },
            'afternoon': { 'start': '15:00', 'end': '18:00' }
          },
          'saturday': {
            'isWorking': false,
            'morning': { 'start': '08:00', 'end': '12:00' },
            'afternoon': { 'start': '15:00', 'end': '18:00' }
          },
          'sunday': {
            'isWorking': false,
            'morning': { 'start': '08:00', 'end': '12:00' },
            'afternoon': { 'start': '15:00', 'end': '18:00' }
          }
        }
      };
      
      // Utilisation du service d'upload de documents
      final uploadService = DoctorUploadService.instance;
      
      // Préparation des documents avec les noms exacts attendus par le backend
      final documents = <String, List<File>>{
        'medicalLicense': [_licenseDocument!],
        'diploma': [_diplomaDocument!],
      };
      
      // Création du profil et upload des documents en une seule opération
      final result = await uploadService.createDoctorProfileWithDocuments(
        doctorData: formData,
        documents: documents,
        onStatusUpdate: (status) {
          // Mise à jour du statut si nécessaire
          // Utiliser un logger en production au lieu de print
          debugPrint('Statut: $status');
        },
      );
      
      if (result.success) {
        
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('✓ Demande envoyée'),
              content: const Text(
                'Votre demande d\'upgrade vers médecin a été envoyée avec succès. '
                'Elle sera examinée par notre équipe dans les plus brefs délais. '
                'Vous recevrez une notification dès qu\'une décision sera prise.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    AppNavigation.goToHome();
                  },
                  child: const Text('Compris'),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${result.message}'),
              backgroundColor: const Color.fromARGB(255, 242, 61, 61),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Fin de la classe _DoctorUpgradeScreenState

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
                    title: const Text('Devenir médecin'),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                AppNavigation.goToHome();
              },
            ),
          ],
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_currentStep > 0) {
                setState(() {
                  _currentStep--;
                });
              } else {
                AppNavigation.goToHome();
              }
            },
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: Stepper(
                    currentStep: _currentStep,
                    onStepTapped: (step) {
                      setState(() {
                        _currentStep = step;
                      });
                    },
                    controlsBuilder: (context, details) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CustomButton(
                            text: details.stepIndex > 0 ? 'Précédent' : 'Annuler',
                            onPressed: () {
                              if (_currentStep > 0) {
                                setState(() {
                                  _currentStep--;
                                });
                              } else {
                                AppNavigation.goToHome();
                              }
                            },
                            width: 120,
                            height: 40,
                            backgroundColor: Colors.grey[300],
                            textColor: Colors.black87,
                          ),
                          if (details.stepIndex < 3)
                            CustomButton(
                              text: 'Suivant',
                              onPressed: () {
                                if (_currentStep < 2) {
                                  setState(() {
                                    _currentStep++;
                                  });
                                }
                              },
                              width: 120,
                              height: 40,
                            ),
                          if (details.stepIndex == 3)
                            CustomButton(
                              text: 'Envoyer la demande',
                              onPressed: _submitUpgradeRequest,
                              isLoading: _isLoading,
                              width: 160,
                              height: 40,
                            ),
                        ],
                      );
                    },
                    steps: [
                      // Étape 1: Informations professionnelles
                      Step(
                        title: const Text('Informations professionnelles'),
                        content: _buildProfessionalInfoStep(),
                        isActive: _currentStep >= 0,
                      ),
                      // Étape 2: Documents
                      Step(
                        title: const Text('Documents'),
                        content: _buildDocumentsStep(),
                        isActive: _currentStep >= 1,
                      ),
                      // Étape 3: Cabinet médical
                      Step(
                        title: const Text('Cabinet médical'),
                        content: _buildClinicInfoStep(),
                        isActive: _currentStep >= 2,
                      ),
                      // Étape 4: Finalisation
                      Step(
                        title: const Text('Finalisation'),
                        content: _buildFinalizationStep(),
                        isActive: _currentStep >= 3,
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
  
  Widget _buildProfessionalInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDropdownField(
          controller: _specializationController,
          label: 'Spécialisation',
          items: _specializations,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'La spécialisation est requise';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _licenseController,
          label: 'Numéro de licence médicale',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Le numéro de licence est requis';
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
              return 'L\'expérience est requise';
            }
            final years = int.tryParse(value);
            if (years == null || years < 0) {
              return 'Veuillez entrer un nombre valide';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _educationController,
          label: 'Éducation et formations',
          maxLines: 3,
          hintText: 'Université, diplômes, formations spécialisées...',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'L\'information sur l\'education est requise';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildLanguageSelector(),
      ],
    );
  }
  
  Widget _buildDocumentsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Veuillez télécharger les documents requis pour valider votre profil médecin :',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 20),
        _buildDocumentUpload(
          title: 'Licence médicale',
          subtitle: 'Document officiel de votre licence médicale',
          file: _licenseDocument,
          onTap: () => _pickDocument(true),
          isRequired: true,
        ),
        const SizedBox(height: 16),
        _buildDocumentUpload(
          title: 'Diplôme médical',
          subtitle: 'Diplôme de docteur en médecine',
          file: _diplomaDocument,
          onTap: () => _pickDocument(false),
          isRequired: true,
        ),
      ],
    );
  }
  
  Widget _buildClinicInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _clinicNameController,
          decoration: const InputDecoration(
            labelText: 'Nom du cabinet',
            prefixIcon: Icon(Icons.business_outlined),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer le nom du cabinet';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'Informations sur votre cabinet médical (optionnel) :',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 20),
        // Adresse automatique par géolocalisation
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Adresse du cabinet',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_clinicAddressController.text.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _clinicAddressController.text,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_clinicCityController.text.isNotEmpty)
                        Text(
                          _clinicCityController.text,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _getCurrentLocationAndFillAddress,
                  icon: const Icon(Icons.my_location),
                  label: Text(_clinicAddressController.text.isEmpty 
                    ? 'Détecter automatiquement l\'adresse' 
                    : 'Mettre à jour l\'adresse'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nous utilisons votre position actuelle pour déterminer automatiquement l\'adresse de votre cabinet.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _clinicPhoneController,
          label: 'Téléphone du cabinet',
          keyboardType: TextInputType.phone,
          hintText: '77 123 45 67',
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _consultationFeeController,
          label: 'Tarif de consultation (FCFA)',
          keyboardType: TextInputType.number,
          hintText: '15000',
        ),
      ],
    );
  }
  
  Widget _buildFinalizationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _bioController,
          label: 'Biographie professionnelle',
          maxLines: 4,
          hintText: 'Présentez-vous et décrivez votre expérience...',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Une biographie est requise';
            }
            if (value.length < 50) {
              return 'La biographie doit contenir au moins 50 caractères';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Processus de validation',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Votre demande sera examinée par notre équipe médicale. '
                'Le processus de validation peut prendre 2-5 jours ouvrables. '
                'Vous recevrez une notification dès qu\'une décision sera prise.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: icon != null ? Icon(icon, color: AppTheme.primaryColor) : null,
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: validator,
        ),
      ],
    );
  }
  
  Widget _buildDropdownField({
    required TextEditingController controller,
    required String label,
    required List<String> items,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: controller.text.isEmpty ? null : controller.text,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: (String? newValue) {
        controller.text = newValue ?? '';
      },
      validator: validator,
    );
  }
  
  Widget _buildLanguageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Langues parlées',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _languages.map((language) {
            final isSelected = _selectedLanguages.contains(language);
            return FilterChip(
              label: Text(language),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedLanguages.add(language);
                  } else {
                    if (_selectedLanguages.length > 1) {
                      _selectedLanguages.remove(language);
                    }
                  }
                });
              },
              selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
              checkmarkColor: AppTheme.primaryColor,
            );
          }).toList(),
        ),
      ],
    );
  }
  
  Widget _buildDocumentUpload({
    required String title,
    required String subtitle,
    required File? file,
    required VoidCallback onTap,
    required bool isRequired,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: file != null ? Colors.green : Colors.grey[300]!,
            width: file != null ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: file != null ? Colors.green[50] : Colors.white,
        ),
        child: Row(
          children: [
            Icon(
              file != null ? Icons.check_circle : Icons.upload_file,
              color: file != null ? Colors.green : AppTheme.primaryColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      if (isRequired)
                        const Text(
                          ' *',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    file != null ? 'Document téléchargé' : subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: file != null ? Colors.green[700] : AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
