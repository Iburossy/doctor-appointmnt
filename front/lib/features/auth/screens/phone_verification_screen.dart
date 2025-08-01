import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import 'dart:async';
import '../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/loading_overlay.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const PhoneVerificationScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  
  Timer? _timer;
  int _resendCountdown = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    
    // Auto focus on pin input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    _timer?.cancel();
    super.dispose();
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

  Future<void> _verifyCode() async {
    if (_pinController.text.length != 6) {
      _showErrorSnackBar('Veuillez entrer le code à 6 chiffres');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    
    // Utiliser le numéro de téléphone du profil utilisateur au lieu de celui de l'URL
    final userPhone = authProvider.user?.phone;
    if (userPhone == null) {
      _showErrorSnackBar('Erreur: numéro de téléphone non trouvé');
      return;
    }
    
    print('📱 Vérification avec le numéro: $userPhone (au lieu de ${widget.phoneNumber})');
    
    final success = await authProvider.verifyPhone(
      phone: userPhone,
      code: _pinController.text,
    );

    if (success && mounted) {
      _showSuccessSnackBar('Téléphone vérifié avec succès !');
      // Small delay to show success message
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        context.goNamed('home');
      }
    } else if (mounted) {
      _showErrorSnackBar(authProvider.error ?? 'Code de vérification invalide');
      _pinController.clear();
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;

    final authProvider = context.read<AuthProvider>();
    
    // Utiliser le numéro de téléphone du profil utilisateur
    final userPhone = authProvider.user?.phone;
    if (userPhone == null) {
      _showErrorSnackBar('Erreur: numéro de téléphone non trouvé');
      return;
    }
    
    final success = await authProvider.resendVerificationCode(userPhone);

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

  String get _maskedPhoneNumber {
    if (widget.phoneNumber.length >= 8) {
      final start = widget.phoneNumber.substring(0, 4);
      final end = widget.phoneNumber.substring(widget.phoneNumber.length - 2);
      return '$start****$end';
    }
    return widget.phoneNumber;
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
          onPressed: () => context.pop(),
        ),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return LoadingOverlay(
            isLoading: authProvider.isLoading,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    
                    // Header
                    _buildHeader(),
                    
                    const SizedBox(height: 48),
                    
                    // PIN Input
                    _buildPinInput(),
                    
                    const SizedBox(height: 32),
                    
                    // Verify Button
                    CustomButton(
                      text: 'Vérifier',
                      onPressed: _verifyCode,
                      isLoading: authProvider.isLoading,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Resend Code
                    _buildResendSection(),
                    
                    const Spacer(),
                    
                    // Help Text
                    _buildHelpText(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.sms,
            size: 40,
            color: AppTheme.primaryColor,
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Title
        const Text(
          'Vérification du téléphone',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 16),
        
        // Description
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondaryColor,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'Nous avons envoyé un code de vérification à 6 chiffres au numéro '),
              TextSpan(
                text: _maskedPhoneNumber,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
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

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppTheme.primaryColor, width: 2),
      borderRadius: BorderRadius.circular(12),
      color: AppTheme.primaryColor.withValues(alpha: 0.05),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        border: Border.all(color: AppTheme.primaryColor),
      ),
    );

    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: Colors.red, width: 2),
      borderRadius: BorderRadius.circular(12),
    );

    return Pinput(
      controller: _pinController,
      focusNode: _focusNode,
      length: 6,
      defaultPinTheme: defaultPinTheme,
      focusedPinTheme: focusedPinTheme,
      submittedPinTheme: submittedPinTheme,
      errorPinTheme: errorPinTheme,
      pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
      showCursor: true,
      onCompleted: (pin) => _verifyCode(),
      validator: (value) {
        if (value == null || value.length != 6) {
          return 'Code invalide';
        }
        return null;
      },
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

  Widget _buildHelpText() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.blue.shade600,
            size: 20,
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Text(
              'Le code peut prendre quelques minutes à arriver. Vérifiez vos SMS.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
