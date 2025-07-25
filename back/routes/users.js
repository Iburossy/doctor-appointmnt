const express = require('express');
const { body, validationResult } = require('express-validator');
const User = require('../models/User');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

// @route   PUT /api/users/profile
// @desc    Mettre à jour le profil utilisateur
// @access  Private
router.put('/profile', authenticate, [
  body('firstName')
    .optional()
    .trim()
    .isLength({ min: 2, max: 50 })
    .withMessage('Le prénom doit contenir entre 2 et 50 caractères'),
  body('lastName')
    .optional()
    .trim()
    .isLength({ min: 2, max: 50 })
    .withMessage('Le nom doit contenir entre 2 et 50 caractères'),
  body('email')
    .optional()
    .isEmail()
    .withMessage('Email invalide'),
  body('dateOfBirth')
    .optional()
    .isISO8601()
    .withMessage('Date de naissance invalide'),
  body('gender')
    .optional()
    .isIn(['male', 'female', 'other'])
    .withMessage('Genre invalide')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Données invalides',
        details: errors.array()
      });
    }

    const user = req.user;
    const allowedUpdates = [
      'firstName', 'lastName', 'email', 'dateOfBirth', 'gender',
      'address', 'language', 'notifications'
    ];

    const updates = {};
    allowedUpdates.forEach(field => {
      if (req.body[field] !== undefined) {
        updates[field] = req.body[field];
      }
    });

    // Vérifier l'unicité de l'email si modifié
    if (updates.email && updates.email !== user.email) {
      const existingUser = await User.findOne({ 
        email: updates.email.toLowerCase(),
        _id: { $ne: user._id }
      });
      
      if (existingUser) {
        return res.status(400).json({
          error: 'Cet email est déjà utilisé'
        });
      }
      
      updates.email = updates.email.toLowerCase();
      updates.isEmailVerified = false; // Nécessite une nouvelle vérification
    }

    Object.assign(user, updates);
    await user.save();

    res.json({
      message: 'Profil mis à jour avec succès',
      user: {
        id: user._id,
        firstName: user.firstName,
        lastName: user.lastName,
        phone: user.phone,
        email: user.email,
        role: user.role,
        isPhoneVerified: user.isPhoneVerified,
        isEmailVerified: user.isEmailVerified,
        profilePicture: user.profilePicture,
        address: user.address,
        language: user.language,
        notifications: user.notifications,
        dateOfBirth: user.dateOfBirth,
        gender: user.gender
      }
    });

  } catch (error) {
    console.error('Erreur mise à jour profil:', error);
    res.status(500).json({
      error: 'Erreur lors de la mise à jour du profil'
    });
  }
});

// @route   PUT /api/users/change-password
// @desc    Changer le mot de passe
// @access  Private
router.put('/change-password', authenticate, [
  body('currentPassword')
    .isLength({ min: 1 })
    .withMessage('Mot de passe actuel requis'),
  body('newPassword')
    .isLength({ min: 6 })
    .withMessage('Le nouveau mot de passe doit contenir au moins 6 caractères'),
  body('confirmPassword')
    .custom((value, { req }) => {
      if (value !== req.body.newPassword) {
        throw new Error('La confirmation du mot de passe ne correspond pas');
      }
      return true;
    })
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Données invalides',
        details: errors.array()
      });
    }

    const { currentPassword, newPassword } = req.body;
    const user = req.user;

    // Vérifier le mot de passe actuel
    const isCurrentPasswordValid = await user.comparePassword(currentPassword);
    if (!isCurrentPasswordValid) {
      return res.status(400).json({
        error: 'Mot de passe actuel incorrect'
      });
    }

    // Mettre à jour le mot de passe
    user.password = newPassword;
    await user.save();

    res.json({
      message: 'Mot de passe modifié avec succès'
    });

  } catch (error) {
    console.error('Erreur changement mot de passe:', error);
    res.status(500).json({
      error: 'Erreur lors du changement de mot de passe'
    });
  }
});

// @route   POST /api/users/upload-avatar
// @desc    Upload de photo de profil
// @access  Private
router.post('/upload-avatar', authenticate, async (req, res) => {
  try {
    // TODO: Implémenter l'upload de fichier avec multer
    // Pour le moment, on accepte juste une URL
    const { profilePictureUrl } = req.body;

    if (!profilePictureUrl) {
      return res.status(400).json({
        error: 'URL de la photo de profil requise'
      });
    }

    const user = req.user;
    user.profilePicture = profilePictureUrl;
    await user.save();

    res.json({
      message: 'Photo de profil mise à jour avec succès',
      profilePicture: user.profilePicture
    });

  } catch (error) {
    console.error('Erreur upload avatar:', error);
    res.status(500).json({
      error: 'Erreur lors de l\'upload de la photo de profil'
    });
  }
});

// @route   PUT /api/users/location
// @desc    Mettre à jour la localisation
// @access  Private
router.put('/location', authenticate, [
  body('address.street')
    .optional()
    .trim()
    .isLength({ min: 5, max: 200 })
    .withMessage('Adresse invalide'),
  body('address.city')
    .optional()
    .trim()
    .isLength({ min: 2, max: 50 })
    .withMessage('Ville invalide'),
  body('address.coordinates.latitude')
    .isFloat({ min: -90, max: 90 })
    .withMessage('Latitude invalide'),
  body('address.coordinates.longitude')
    .isFloat({ min: -180, max: 180 })
    .withMessage('Longitude invalide')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Coordonnées invalides',
        details: errors.array()
      });
    }

    const user = req.user;
    const { address } = req.body;

    user.address = {
      ...user.address,
      ...address,
      country: 'Sénégal' // Forcer le pays
    };

    await user.save();

    res.json({
      message: 'Localisation mise à jour avec succès',
      address: user.address
    });

  } catch (error) {
    console.error('Erreur mise à jour localisation:', error);
    res.status(500).json({
      error: 'Erreur lors de la mise à jour de la localisation'
    });
  }
});

// @route   PUT /api/users/notifications
// @desc    Mettre à jour les préférences de notification
// @access  Private
router.put('/notifications', authenticate, [
  body('notifications.sms')
    .optional()
    .isBoolean()
    .withMessage('Préférence SMS invalide'),
  body('notifications.email')
    .optional()
    .isBoolean()
    .withMessage('Préférence email invalide'),
  body('notifications.push')
    .optional()
    .isBoolean()
    .withMessage('Préférence push invalide')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Préférences invalides',
        details: errors.array()
      });
    }

    const user = req.user;
    const { notifications } = req.body;

    user.notifications = {
      ...user.notifications,
      ...notifications
    };

    await user.save();

    res.json({
      message: 'Préférences de notification mises à jour',
      notifications: user.notifications
    });

  } catch (error) {
    console.error('Erreur mise à jour notifications:', error);
    res.status(500).json({
      error: 'Erreur lors de la mise à jour des préférences'
    });
  }
});

// @route   DELETE /api/users/account
// @desc    Supprimer le compte utilisateur
// @access  Private
router.delete('/account', authenticate, [
  body('password')
    .isLength({ min: 1 })
    .withMessage('Mot de passe requis pour supprimer le compte')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Mot de passe requis',
        details: errors.array()
      });
    }

    const { password } = req.body;
    const user = req.user;

    // Vérifier le mot de passe
    const isPasswordValid = await user.comparePassword(password);
    if (!isPasswordValid) {
      return res.status(400).json({
        error: 'Mot de passe incorrect'
      });
    }

    // Désactiver le compte plutôt que de le supprimer
    user.isActive = false;
    user.email = `deleted_${Date.now()}_${user.email}`;
    user.phone = `deleted_${Date.now()}_${user.phone}`;
    
    await user.save();

    res.json({
      message: 'Compte supprimé avec succès'
    });

  } catch (error) {
    console.error('Erreur suppression compte:', error);
    res.status(500).json({
      error: 'Erreur lors de la suppression du compte'
    });
  }
});

// @route   GET /api/users/me/appointments
// @desc    Obtenir les rendez-vous de l'utilisateur
// @access  Private
router.get('/me/appointments', authenticate, async (req, res) => {
  try {
    const { status, page = 1, limit = 10 } = req.query;
    
    const Appointment = require('../models/Appointment');
    
    let query = { patient: req.user._id };
    
    if (status) {
      query.status = status;
    }

    const skip = (page - 1) * limit;
    
    const appointments = await Appointment.find(query)
      .sort({ appointmentDate: -1, appointmentTime: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Appointment.countDocuments(query);

    res.json({
      appointments,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / limit),
        totalAppointments: total,
        hasNext: page * limit < total,
        hasPrev: page > 1
      }
    });

  } catch (error) {
    console.error('Erreur récupération rendez-vous:', error);
    res.status(500).json({
      error: 'Erreur lors de la récupération des rendez-vous'
    });
  }
});

module.exports = router;
