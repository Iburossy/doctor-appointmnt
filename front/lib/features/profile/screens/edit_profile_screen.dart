import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  
  DateTime? _selectedDate;
  String? _selectedGender;
  bool _isLoading = false;
  File? _profileImageFile;
  
  final List<String> _genders = ['Homme', 'Femme'];
  
  @override
  void initState() {
    super.initState();
    _streetController = TextEditingController();
    _cityController = TextEditingController();
    _loadCurrentProfile();
  }
  
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    super.dispose();
  }
  
  String _getFullAvatarUrl(String avatarPath) {
    if (avatarPath.startsWith('http')) {
      return avatarPath;
    }
    return '${AppConfig.baseUrl}/$avatarPath';
  }
  
  void _loadCurrentProfile() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    
    if (user != null) {
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
      _emailController.text = user.email ?? '';
      
      // Gestion de l'adresse - compatible avec l'ancien et le nouveau format
      if (user.address != null) {
        if (user.address is Map) {
          // Nouveau format: objet avec street et city
          final addressMap = user.address as Map;
          _streetController.text = addressMap['street'] ?? '';
          _cityController.text = addressMap['city'] ?? '';
        } else {
          // Ancien format: chaîne simple
          _streetController.text = user.address.toString();
        }
      }
      
      // Valeurs pour le genre et la date de naissance
      _selectedDate = user.dateOfBirth;
      
      // Conversion du genre pour l'interface utilisateur
      if (user.gender == 'male') {
        _selectedGender = 'Homme';
      } else if (user.gender == 'female') {
        _selectedGender = 'Femme';
      }
    }
  }
  
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final success = await authProvider.updateUserProfile(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        dateOfBirth: _selectedDate,
        gender: _selectedGender == 'Homme' ? 'male' : (_selectedGender == 'Femme' ? 'female' : null),
        street: _streetController.text,
        city: _cityController.text,
        avatarFile: _profileImageFile,
      );
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil mis à jour avec succès'),
              backgroundColor: Color.fromARGB(255, 33, 150, 243),
            ),
          );
          
          // Navigation robuste - retourner à l'écran précédent ou à l'accueil
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.goNamed('home');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.error ?? 'Une erreur est survenue'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur inattendue: $e'),
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
  
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('fr', 'FR'),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (pickedFile != null) {
      setState(() {
        _profileImageFile = File(pickedFile.path);
      });
    }
  }

  Widget _buildAvatarPicker() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: _profileImageFile != null
                ? FileImage(_profileImageFile!) as ImageProvider
                : (user?.profilePicture != null && user!.profilePicture!.isNotEmpty
                    ? NetworkImage(_getFullAvatarUrl(user.profilePicture!))
                    : const AssetImage('assets/images/default_avatar.png')),
            child: _profileImageFile == null && (user?.profilePicture == null || user!.profilePicture!.isEmpty)
                ? const Icon(Icons.person, size: 50, color: Colors.grey)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 33, 150, 243),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Modifier le profil'),
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimaryColor,
          elevation: 0,
          actions: [
            TextButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: const Text(
                'Sauvegarder',
                style: TextStyle(
                  color: Color.fromARGB(255, 33, 150, 243),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatarPicker(),
                const SizedBox(height: 24),
                // Section Informations personnelles
                _buildSectionCard(
                  title: 'Informations personnelles',
                  icon: Icons.person_outline,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _firstNameController,
                            label: 'Prénom',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Le prénom est requis';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _lastNameController,
                            label: 'Nom',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Le nom est requis';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Email invalide';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDateField(),
                    const SizedBox(height: 16),
                    _buildGenderDropdown(),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _streetController,
                      label: 'Rue',
                      icon: Icons.location_on,
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _cityController,
                      label: 'Ville',
                      icon: Icons.location_city,
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // // Bouton de sauvegarde
                // CustomButton(
                //   text: 'Sauvegarder les modifications',
                  
                //   onPressed: _isLoading ? null : _saveProfile,
                //   isLoading: _isLoading,
                // ),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const AppBottomNavigation(
          currentIndex: 3, // Index du profil
        ),
      ),
    );
  }
  
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Color.fromARGB(255, 33, 150, 243),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool isObscure = false,
    bool isEnabled = true,
    int maxLines = 1,
    TextInputType? keyboardType,
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
          obscureText: isObscure,
          enabled: isEnabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: icon != null ? Icon(icon, color: Color.fromARGB(255, 33, 150, 243)) : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color.fromARGB(255, 33, 150, 243), width: 2),
            ),
            filled: true,
            fillColor: isEnabled ? Colors.white : Colors.grey[200],
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
  
  Widget _buildDateField() {
    return InkWell(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today,
              color: AppTheme.primaryColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date de naissance',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedDate != null
                        ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                        : 'Sélectionner une date',
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedDate != null
                          ? AppTheme.textPrimaryColor
                          : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      decoration: InputDecoration(
        labelText: 'Genre',
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
          borderSide: const BorderSide(color: Color.fromARGB(255, 33, 150, 243)),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: _genders.map((String gender) {
        return DropdownMenuItem<String>(
          value: gender,
          child: Text(gender),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedGender = newValue;
        });
      },
    );
  }
}
