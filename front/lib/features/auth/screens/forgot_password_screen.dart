import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:pinput/pinput.dart';
import '../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/loading_overlay.dart';
import 'dart:async';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _pageController = PageController();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  String _countryCode = '+221'; // Senegal default
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _currentStep = 0;
  bool _isNavigating = false;
  
  Timer? _timer;
  int _resendCountdown = 60;
  bool _canResend = false;

  @override
  void dispose() {
    _pageController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String get _fullPhoneNumber => '$_countryCode${_phoneController.text}';

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _startResendTimer() {
    _canResend = false;
    _resendCountdown = 60;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendCountdown > 0) {
            _resendCountdown--;
          } else {
            _canResend = true;
            timer.cancel();
          }
        });
      }
    });
  }

  Future<void> _sendResetCode() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    
    final success = await authProvider.forgotPassword(_fullPhoneNumber);

    if (success && mounted) {
      _showSuccessSnackBar('Code de réinitialisation envoyé !');
      _startResendTimer();
      _nextStep();
    } else if (mounted) {
      _showErrorSnackBar(authProvider.error ?? 'Erreur lors de l\'envoi du code');
    }
  }

  Future<void> _verifyCodeAndReset() async {
    if (_pinController.text.length != 6) {
      _showErrorSnackBar('Veuillez entrer le code à 6 chiffres');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showErrorSnackBar('Le mot de passe doit contenir au moins 6 caractères');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar('Les mots de passe ne correspondent pas');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    
    final success = await authProvider.resetPassword(
      phone: _fullPhoneNumber,
      code: _pinController.text,
      newPassword: _passwordController.text,
    );

    if (success && mounted) {
      _showSuccessSnackBar('Mot de passe réinitialisé avec succès !');
      // Small delay to show success message
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        context.goNamed('login');
      }
    } else if (mounted) {
      _showErrorSnackBar(authProvider.error ?? 'Erreur lors de la réinitialisation');
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;

    final authProvider = context.read<AuthProvider>();
    
    final success = await authProvider.forgotPassword(_fullPhoneNumber);

    if (success && mounted) {
      _showSuccessSnackBar('Code renvoyé avec succès !');
      _startResendTimer();
      _pinController.clear();
    } else if (mounted) {
      _showErrorSnackBar(authProvider.error ?? 'Erreur lors de l\'envoi du code');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimaryColor),
          onPressed: () {
            if (_isNavigating) return;
            setState(() => _isNavigating = true);
            Navigator.pop(context);
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                setState(() => _isNavigating = false);
              }
            });
          },
        ),
        title: Text(
          'Mot de passe oublié',
          style: const TextStyle(
            color: AppTheme.textPrimaryColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return LoadingOverlay(
            isLoading: authProvider.isLoading,
            child: Column(
              children: [
                // Progress Indicator
                _buildProgressIndicator(),
                
                // Page Content
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildPhoneStep(),
                      _buildVerificationStep(),
                      _buildNewPasswordStep(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= _currentStep;
          final isCompleted = index < _currentStep;
          
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primaryColor : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                if (index < 2)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: index < _currentStep ? AppTheme.primaryColor : Colors.grey.shade300,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              // Header
              _buildStepHeader(
                icon: Icons.phone,
                title: 'Entrez votre numéro',
                description: 'Nous vous enverrons un code de vérification pour réinitialiser votre mot de passe.',
              ),
              
              const SizedBox(height: 48),
              
              // Phone Field
              _buildPhoneField(),
              
              const Spacer(),
              
              // Continue Button
              CustomButton(
                text: 'Envoyer le code',
                onPressed: _sendResetCode,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationStep() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            
            // Header
            _buildStepHeader(
              icon: Icons.sms,
              title: 'Vérification',
              description: 'Entrez le code à 6 chiffres envoyé au ${_maskPhoneNumber(_fullPhoneNumber)}',
            ),
            
            const SizedBox(height: 48),
            
            // PIN Input
            _buildPinInput(),
            
            const SizedBox(height: 32),
            
            // Resend Section
            _buildResendSection(),
            
            const Spacer(),
            
            // Continue Button
            CustomButton(
              text: 'Continuer',
              onPressed: () {
                if (_pinController.text.length == 6) {
                  _nextStep();
                } else {
                  _showErrorSnackBar('Veuillez entrer le code à 6 chiffres');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewPasswordStep() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            
            // Header
            _buildStepHeader(
              icon: Icons.lock_reset,
              title: 'Nouveau mot de passe',
              description: 'Créez un nouveau mot de passe sécurisé pour votre compte.',
            ),
            
            const SizedBox(height: 48),
            
            // New Password
            CustomTextField(
              controller: _passwordController,
              label: 'Nouveau mot de passe',
              hintText: 'Entrez votre nouveau mot de passe',
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: AppTheme.textSecondaryColor,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Confirm Password
            CustomTextField(
              controller: _confirmPasswordController,
              label: 'Confirmer le mot de passe',
              hintText: 'Confirmez votre nouveau mot de passe',
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                  color: AppTheme.textSecondaryColor,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
            ),
            
            const Spacer(),
            
            // Reset Button
            CustomButton(
              text: 'Réinitialiser le mot de passe',
              onPressed: _verifyCodeAndReset,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepHeader({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            icon,
            size: 40,
            color: AppTheme.primaryColor,
          ),
        ),
        
        const SizedBox(height: 24),
        
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 16),
        
        Text(
          description,
          style: const TextStyle(
            fontSize: 16,
            color: AppTheme.textSecondaryColor,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Numéro de téléphone',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CountryCodePicker(
                onChanged: (country) {
                  setState(() {
                    _countryCode = country.dialCode!;
                  });
                },
                initialSelection: 'SN',
                favorite: const ['SN', 'FR'],
                showCountryOnly: false,
                showOnlyCountryWhenClosed: false,
                alignLeft: false,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              
              Container(
                height: 30,
                width: 1,
                color: AppTheme.borderColor,
              ),
              
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: '77 123 45 67',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre numéro';
                    }
                    if (!AppConfig.isValidSenegalPhone(value)) {
                      return 'Numéro invalide';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPinInput() {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(
        fontSize: 20,
        color: AppTheme.textPrimaryColor,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
      ),
    );

    return Pinput(
      controller: _pinController,
      length: 6,
      defaultPinTheme: defaultPinTheme,
      focusedPinTheme: defaultPinTheme.copyDecorationWith(
        border: Border.all(color: AppTheme.primaryColor, width: 2),
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
      ),
      submittedPinTheme: defaultPinTheme.copyWith(
        decoration: defaultPinTheme.decoration?.copyWith(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          border: Border.all(color: AppTheme.primaryColor),
        ),
      ),
      showCursor: true,
    );
  }

  Widget _buildResendSection() {
    return Column(
      children: [
        const Text(
          'Vous n\'avez pas reçu le code ?',
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        
        const SizedBox(height: 8),
        
        if (_canResend)
          TextButton(
            onPressed: _resendCode,
            child: const Text(
              'Renvoyer le code',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          Text(
            'Renvoyer dans ${_resendCountdown}s',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
      ],
    );
  }

  String _maskPhoneNumber(String phone) {
    if (phone.length >= 8) {
      final start = phone.substring(0, 4);
      final end = phone.substring(phone.length - 2);
      return '$start****$end';
    }
    return phone;
  }
}
