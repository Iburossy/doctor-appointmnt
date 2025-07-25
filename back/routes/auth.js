const express = require('express');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const User = require('../models/User');
const smsService = require('../services/smsService');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

// Générer un token JWT
const generateToken = (userId) => {
  return jwt.sign({ userId }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRE || '7d'
  });
};

// @route   POST /api/auth/register
// @desc    Inscription d'un nouvel utilisateur
// @access  Public
router.post('/register', [
  body('firstName')
    .trim()
    .isLength({ min: 2, max: 50 })
    .withMessage('Le prénom doit contenir entre 2 et 50 caractères'),
  body('lastName')
    .trim()
    .isLength({ min: 2, max: 50 })
    .withMessage('Le nom doit contenir entre 2 et 50 caractères'),
  body('phone')
    .isMobilePhone('any')
    .withMessage('Numéro de téléphone invalide'),
  body('password')
    .isLength({ min: 6 })
    .withMessage('Le mot de passe doit contenir au moins 6 caractères'),
  body('email')
    .optional()
    .isEmail()
    .withMessage('Email invalide')
], async (req, res) => {
  try {
    // Vérifier les erreurs de validation
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Données invalides',
        details: errors.array()
      });
    }

    const { firstName, lastName, phone, email, password } = req.body;

    // Formater le numéro de téléphone
    const formattedPhone = smsService.formatPhoneNumber(phone);
    
    if (!smsService.validateSenegalPhoneNumber(formattedPhone)) {
      return res.status(400).json({
        error: 'Format de numéro de téléphone sénégalais invalide'
      });
    }

    // Vérifier si l'utilisateur existe déjà
    const existingUser = await User.findOne({
      $or: [
        { phone: formattedPhone },
        ...(email ? [{ email: email.toLowerCase() }] : [])
      ]
    });

    if (existingUser) {
      return res.status(400).json({
        error: existingUser.phone === formattedPhone 
          ? 'Ce numéro de téléphone est déjà utilisé'
          : 'Cet email est déjà utilisé'
      });
    }

    // Créer le nouvel utilisateur
    const user = new User({
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      phone: formattedPhone,
      email: email?.toLowerCase(),
      password
    });

    // Générer le code de vérification
    const verificationCode = user.generateVerificationCode();
    user.phoneVerificationCode = verificationCode;
    user.phoneVerificationExpires = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    await user.save();

    // Envoyer le SMS de vérification
    try {
      const smsResult = await smsService.sendVerificationCode(formattedPhone, verificationCode);
      console.log('SMS envoyé:', smsResult);
    } catch (smsError) {
      console.error('Erreur SMS:', smsError);
      // Ne pas bloquer l'inscription si l'SMS échoue
    }

    // Générer le token
    const token = generateToken(user._id);

    res.status(201).json({
      message: 'Compte créé avec succès. Vérifiez votre téléphone.',
      token,
      user: {
        id: user._id,
        firstName: user.firstName,
        lastName: user.lastName,
        phone: user.phone,
        email: user.email,
        role: user.role,
        isPhoneVerified: user.isPhoneVerified
      },
      ...(process.env.NODE_ENV === 'development' && { devCode: verificationCode })
    });

  } catch (error) {
    console.error('Erreur inscription:', error);
    res.status(500).json({
      error: 'Erreur lors de la création du compte'
    });
  }
});

// @route   POST /api/auth/verify-phone
// @desc    Vérifier le numéro de téléphone avec le code OTP
// @access  Private
router.post('/verify-phone', authenticate, [
  body('code')
    .isLength({ min: 6, max: 6 })
    .isNumeric()
    .withMessage('Le code doit contenir 6 chiffres')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Code invalide',
        details: errors.array()
      });
    }

    const { code } = req.body;
    const user = req.user;

    if (user.isPhoneVerified) {
      return res.status(400).json({
        error: 'Numéro déjà vérifié'
      });
    }

    if (!user.phoneVerificationCode || !user.phoneVerificationExpires) {
      return res.status(400).json({
        error: 'Aucun code de vérification en attente'
      });
    }

    if (user.phoneVerificationExpires < new Date()) {
      return res.status(400).json({
        error: 'Code de vérification expiré'
      });
    }

    if (user.phoneVerificationCode !== code) {
      return res.status(400).json({
        error: 'Code de vérification incorrect'
      });
    }

    // Marquer le téléphone comme vérifié
    user.isPhoneVerified = true;
    user.phoneVerificationCode = undefined;
    user.phoneVerificationExpires = undefined;
    
    await user.save();

    res.json({
      message: 'Numéro de téléphone vérifié avec succès',
      user: {
        id: user._id,
        firstName: user.firstName,
        lastName: user.lastName,
        phone: user.phone,
        email: user.email,
        role: user.role,
        isPhoneVerified: user.isPhoneVerified
      }
    });

  } catch (error) {
    console.error('Erreur vérification téléphone:', error);
    res.status(500).json({
      error: 'Erreur lors de la vérification'
    });
  }
});

// @route   POST /api/auth/resend-code
// @desc    Renvoyer le code de vérification
// @access  Private
router.post('/resend-code', authenticate, async (req, res) => {
  try {
    const user = req.user;

    if (user.isPhoneVerified) {
      return res.status(400).json({
        error: 'Numéro déjà vérifié'
      });
    }

    // Générer un nouveau code
    const verificationCode = user.generateVerificationCode();
    user.phoneVerificationCode = verificationCode;
    user.phoneVerificationExpires = new Date(Date.now() + 10 * 60 * 1000);

    await user.save();

    // Envoyer le SMS
    try {
      await smsService.sendVerificationCode(user.phone, verificationCode);
    } catch (smsError) {
      console.error('Erreur SMS:', smsError);
      return res.status(500).json({
        error: 'Impossible d\'envoyer le SMS'
      });
    }

    res.json({
      message: 'Nouveau code envoyé',
      ...(process.env.NODE_ENV === 'development' && { devCode: verificationCode })
    });

  } catch (error) {
    console.error('Erreur renvoi code:', error);
    res.status(500).json({
      error: 'Erreur lors du renvoi du code'
    });
  }
});

// @route   POST /api/auth/login
// @desc    Connexion utilisateur
// @access  Public
router.post('/login', [
  body('phone')
    .isMobilePhone('any')
    .withMessage('Numéro de téléphone invalide'),
  body('password')
    .isLength({ min: 1 })
    .withMessage('Mot de passe requis')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Données invalides',
        details: errors.array()
      });
    }

    const { phone, password } = req.body;
    const formattedPhone = smsService.formatPhoneNumber(phone);

    // Trouver l'utilisateur
    const user = await User.findOne({ phone: formattedPhone });
    
    if (!user) {
      return res.status(401).json({
        error: 'Numéro de téléphone ou mot de passe incorrect'
      });
    }

    if (!user.isActive) {
      return res.status(401).json({
        error: 'Compte désactivé'
      });
    }

    // Vérifier le mot de passe
    const isPasswordValid = await user.comparePassword(password);
    
    if (!isPasswordValid) {
      return res.status(401).json({
        error: 'Numéro de téléphone ou mot de passe incorrect'
      });
    }

    // Mettre à jour la dernière connexion
    user.lastLogin = new Date();
    await user.save();

    // Générer le token
    const token = generateToken(user._id);

    res.json({
      message: 'Connexion réussie',
      token,
      user: {
        id: user._id,
        firstName: user.firstName,
        lastName: user.lastName,
        phone: user.phone,
        email: user.email,
        role: user.role,
        isPhoneVerified: user.isPhoneVerified,
        profilePicture: user.profilePicture
      }
    });

  } catch (error) {
    console.error('Erreur connexion:', error);
    res.status(500).json({
      error: 'Erreur lors de la connexion'
    });
  }
});

// @route   POST /api/auth/forgot-password
// @desc    Demander la réinitialisation du mot de passe
// @access  Public
router.post('/forgot-password', [
  body('phone')
    .isMobilePhone('any')
    .withMessage('Numéro de téléphone invalide')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Numéro de téléphone invalide',
        details: errors.array()
      });
    }

    const { phone } = req.body;
    const formattedPhone = smsService.formatPhoneNumber(phone);

    const user = await User.findOne({ phone: formattedPhone });
    
    if (!user) {
      // Ne pas révéler si l'utilisateur existe ou non
      return res.json({
        message: 'Si ce numéro existe, un code de réinitialisation a été envoyé'
      });
    }

    // Générer le code de réinitialisation
    const resetCode = user.generateVerificationCode();
    user.passwordResetCode = resetCode;
    user.passwordResetExpires = new Date(Date.now() + 10 * 60 * 1000);

    await user.save();

    // Envoyer le SMS
    try {
      const message = `Votre code de réinitialisation Doctors App: ${resetCode}. Ce code expire dans 10 minutes.`;
      await smsService.sendVerificationCode(formattedPhone, resetCode);
    } catch (smsError) {
      console.error('Erreur SMS réinitialisation:', smsError);
    }

    res.json({
      message: 'Si ce numéro existe, un code de réinitialisation a été envoyé',
      ...(process.env.NODE_ENV === 'development' && { devCode: resetCode })
    });

  } catch (error) {
    console.error('Erreur mot de passe oublié:', error);
    res.status(500).json({
      error: 'Erreur lors de la demande de réinitialisation'
    });
  }
});

// @route   POST /api/auth/reset-password
// @desc    Réinitialiser le mot de passe avec le code
// @access  Public
router.post('/reset-password', [
  body('phone')
    .isMobilePhone('any')
    .withMessage('Numéro de téléphone invalide'),
  body('code')
    .isLength({ min: 6, max: 6 })
    .isNumeric()
    .withMessage('Code invalide'),
  body('newPassword')
    .isLength({ min: 6 })
    .withMessage('Le nouveau mot de passe doit contenir au moins 6 caractères')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Données invalides',
        details: errors.array()
      });
    }

    const { phone, code, newPassword } = req.body;
    const formattedPhone = smsService.formatPhoneNumber(phone);

    const user = await User.findOne({ phone: formattedPhone });
    
    if (!user) {
      return res.status(400).json({
        error: 'Code de réinitialisation invalide'
      });
    }

    if (!user.passwordResetCode || !user.passwordResetExpires) {
      return res.status(400).json({
        error: 'Aucune demande de réinitialisation en cours'
      });
    }

    if (user.passwordResetExpires < new Date()) {
      return res.status(400).json({
        error: 'Code de réinitialisation expiré'
      });
    }

    if (user.passwordResetCode !== code) {
      return res.status(400).json({
        error: 'Code de réinitialisation incorrect'
      });
    }

    // Réinitialiser le mot de passe
    user.password = newPassword;
    user.passwordResetCode = undefined;
    user.passwordResetExpires = undefined;

    await user.save();

    res.json({
      message: 'Mot de passe réinitialisé avec succès'
    });

  } catch (error) {
    console.error('Erreur réinitialisation mot de passe:', error);
    res.status(500).json({
      error: 'Erreur lors de la réinitialisation'
    });
  }
});

// @route   GET /api/auth/me
// @desc    Obtenir les informations de l'utilisateur connecté
// @access  Private
router.get('/me', authenticate, async (req, res) => {
  try {
    res.json({
      user: {
        id: req.user._id,
        firstName: req.user.firstName,
        lastName: req.user.lastName,
        phone: req.user.phone,
        email: req.user.email,
        role: req.user.role,
        isPhoneVerified: req.user.isPhoneVerified,
        isEmailVerified: req.user.isEmailVerified,
        profilePicture: req.user.profilePicture,
        address: req.user.address,
        language: req.user.language,
        notifications: req.user.notifications
      }
    });
  } catch (error) {
    console.error('Erreur récupération profil:', error);
    res.status(500).json({
      error: 'Erreur lors de la récupération du profil'
    });
  }
});

// @route   POST /api/auth/verify-phone-registration
// @desc    Vérifier le téléphone lors de l'inscription (route publique)
// @access  Public
router.post('/verify-phone-registration', [
  body('phone')
    .isMobilePhone('any')
    .withMessage('Numéro de téléphone invalide'),
  body('code')
    .isLength({ min: 6, max: 6 })
    .isNumeric()
    .withMessage('Le code doit contenir 6 chiffres')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Données invalides',
        details: errors.array()
      });
    }

    const { phone, code } = req.body;
    const formattedPhone = smsService.formatPhoneNumber(phone);

    // Trouver l'utilisateur par numéro de téléphone
    const user = await User.findOne({ phone: formattedPhone });
    
    if (!user) {
      return res.status(404).json({
        error: 'Utilisateur non trouvé'
      });
    }

    if (user.isPhoneVerified) {
      return res.status(400).json({
        error: 'Numéro déjà vérifié'
      });
    }

    if (!user.phoneVerificationCode || !user.phoneVerificationExpires) {
      return res.status(400).json({
        error: 'Aucun code de vérification en attente'
      });
    }

    if (user.phoneVerificationExpires < new Date()) {
      return res.status(400).json({
        error: 'Code de vérification expiré'
      });
    }

    if (user.phoneVerificationCode !== code) {
      return res.status(400).json({
        error: 'Code de vérification incorrect'
      });
    }

    // Marquer le téléphone comme vérifié
    user.isPhoneVerified = true;
    user.phoneVerificationCode = undefined;
    user.phoneVerificationExpires = undefined;
    
    await user.save();

    // Générer le token pour l'utilisateur nouvellement vérifié
    const token = generateToken(user._id);

    res.json({
      message: 'Numéro de téléphone vérifié avec succès',
      token,
      user: {
        id: user._id,
        firstName: user.firstName,
        lastName: user.lastName,
        phone: user.phone,
        email: user.email,
        role: user.role,
        isPhoneVerified: user.isPhoneVerified
      }
    });

  } catch (error) {
    console.error('Erreur vérification téléphone inscription:', error);
    res.status(500).json({
      error: 'Erreur lors de la vérification'
    });
  }
});

// @route   POST /api/auth/login
// @desc    Connexion utilisateur (admin et autres)
// @access  Public
router.post('/login', [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Email invalide'),
  body('password')
    .isLength({ min: 6 })
    .withMessage('Le mot de passe doit contenir au moins 6 caractères')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Données invalides',
        details: errors.array()
      });
    }

    const { email, password } = req.body;

    // Rechercher l'utilisateur par email
    const user = await User.findOne({ email }).select('+password');
    if (!user) {
      return res.status(401).json({
        error: 'Email ou mot de passe incorrect'
      });
    }

    // Vérifier le mot de passe
    const isPasswordValid = await user.comparePassword(password);
    if (!isPasswordValid) {
      return res.status(401).json({
        error: 'Email ou mot de passe incorrect'
      });
    }

    // Vérifier que le compte est actif
    if (!user.isActive) {
      return res.status(401).json({
        error: 'Compte désactivé. Contactez l\'administrateur.'
      });
    }

    // Générer le token
    const token = generateToken(user._id);

    // Mettre à jour la dernière connexion
    user.lastLogin = new Date();
    await user.save();

    res.json({
      message: 'Connexion réussie',
      token,
      user: {
        id: user._id,
        firstName: user.firstName,
        lastName: user.lastName,
        phone: user.phone,
        email: user.email,
        role: user.role,
        isPhoneVerified: user.isPhoneVerified,
        isEmailVerified: user.isEmailVerified,
        lastLogin: user.lastLogin
      }
    });

  } catch (error) {
    console.error('Erreur connexion:', error);
    res.status(500).json({
      error: 'Erreur lors de la connexion'
    });
  }
});

module.exports = router;
