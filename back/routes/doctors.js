const express = require('express');
const { body, validationResult, query } = require('express-validator');
const User = require('../models/User');
const Doctor = require('../models/Doctor');
const DoctorRequest = require('../models/doctorRequest');
const { authenticate, authorize, requireVerification } = require('../middleware/auth');
const { uploadWithLogs } = require('../middleware/upload');

const router = express.Router();

// @route   POST /api/doctors/upgrade
// @desc    Upgrade d'un compte patient vers médecin
// @access  Private (Patient vérifié)
router.post('/upgrade', 
  authenticate, 
  requireVerification,
  // Middleware pour gérer les fichiers uploadés
  uploadWithLogs([
    { name: 'medicalLicense', maxCount: 1 },
    { name: 'diploma', maxCount: 3 },
    { name: 'profilePhoto', maxCount: 1 },
    { name: 'clinicPhotos', maxCount: 5 },
    { name: 'certifications', maxCount: 5 }
  ]),
  [
  body('medicalLicenseNumber')
    .trim()
    .isLength({ min: 5, max: 20 })
    .withMessage('Numéro d\'ordre médical invalide'),
  body('specialties')
    .isArray({ min: 1 })
    .withMessage('Au moins une spécialité est requise'),
  body('yearsOfExperience')
    .isInt({ min: 0, max: 50 })
    .withMessage('Années d\'expérience invalides'),
  body('clinic.name')
    .trim()
    .isLength({ min: 2, max: 100 })
    .withMessage('Nom du cabinet requis'),
  body('clinic.address.street')
    .trim()
    .isLength({ min: 5, max: 200 })
    .withMessage('Adresse du cabinet requise'),
  body('clinic.address.city')
    .trim()
    .isLength({ min: 2, max: 50 })
    .withMessage('Ville requise'),
  body('clinic.address.coordinates.latitude')
    .isFloat({ min: -90, max: 90 })
    .withMessage('Latitude invalide'),
  body('clinic.address.coordinates.longitude')
    .isFloat({ min: -180, max: 180 })
    .withMessage('Longitude invalide'),
  body('consultationFee')
    .isFloat({ min: 0 })
    .withMessage('Tarif de consultation invalide'),
  body('languages')
    .isArray({ min: 1 })
    .withMessage('Au moins une langue est requise')
], async (req, res) => {
  try {
    // Gestion du cas où les données sont envoyées via un champ 'data' JSON (multipart/form-data)
    let requestData = req.body;
    if (req.body.data && typeof req.body.data === 'string') {
      try {
        requestData = JSON.parse(req.body.data);
        // Fusionner les données parsées avec req.body pour la validation
        req.body = { ...req.body, ...requestData };
      } catch (e) {
        console.error('Erreur de parsing du champ data JSON:', e);
      }
    }

    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Données invalides',
        details: errors.array()
      });
    }

    const user = req.user;

    // Vérifier si l'utilisateur est déjà médecin
    const existingDoctor = await Doctor.findOne({ userId: user._id });
    if (existingDoctor) {
      return res.status(400).json({
        error: 'Vous êtes déjà enregistré comme médecin'
      });
    }

    // Vérifier l'unicité du numéro d'ordre
    const existingLicense = await Doctor.findOne({ 
      medicalLicenseNumber: req.body.medicalLicenseNumber 
    });
    if (existingLicense) {
      return res.status(400).json({
        error: 'Ce numéro d\'ordre médical est déjà utilisé'
      });
    }

    // Créer le profil médecin
    const doctorData = {
      userId: user._id,
      medicalLicenseNumber: req.body.medicalLicenseNumber,
      specialties: req.body.specialties,
      yearsOfExperience: req.body.yearsOfExperience,
      clinic: {
        name: req.body.clinic.name,
        address: {
          street: req.body.clinic.address.street,
          city: req.body.clinic.address.city,
          region: req.body.clinic.address.region,
          coordinates: {
            latitude: req.body.clinic.address.coordinates.latitude,
            longitude: req.body.clinic.address.coordinates.longitude
          }
        },
        phone: req.body.clinic.phone,
        description: req.body.clinic.description
      },
      consultationFee: req.body.consultationFee,
      languages: req.body.languages,
      verificationStatus: 'pending'
    };

    // Ajouter l'éducation si fournie
    if (req.body.education) {
      doctorData.education = req.body.education;
    }

    // Ajouter les horaires si fournis
    if (req.body.workingHours) {
      doctorData.workingHours = req.body.workingHours;
    }

    // Traitement des fichiers uploadés
    console.log('\n📁 === TRAITEMENT DES FICHIERS ===');
    console.log('📁 Fichiers reçus:', req.files ? Object.keys(req.files) : 'Aucun');
    
    if (req.files) {
      // Licence médicale
      if (req.files.medicalLicense && req.files.medicalLicense.length > 0) {
        doctorData.documents = doctorData.documents || {};
        doctorData.documents.medicalLicense = {
          filename: req.files.medicalLicense[0].filename,
          originalName: req.files.medicalLicense[0].originalname,
          path: req.files.medicalLicense[0].path,
          mimetype: req.files.medicalLicense[0].mimetype,
          size: req.files.medicalLicense[0].size,
          uploadedAt: new Date()
        };
        console.log('✅ Licence médicale sauvegardée:', doctorData.documents.medicalLicense.filename);
      }
      
      // Diplômes
      if (req.files.diploma && req.files.diploma.length > 0) {
        doctorData.documents = doctorData.documents || {};
        doctorData.documents.diplomas = req.files.diploma.map(file => ({
          filename: file.filename,
          originalName: file.originalname,
          path: file.path,
          mimetype: file.mimetype,
          size: file.size,
          uploadedAt: new Date()
        }));
        console.log('✅ Diplômes sauvegardés:', doctorData.documents.diplomas.length, 'fichier(s)');
      }
      
      // Photo de profil
      if (req.files.profilePhoto && req.files.profilePhoto.length > 0) {
        doctorData.profilePhoto = {
          filename: req.files.profilePhoto[0].filename,
          originalName: req.files.profilePhoto[0].originalname,
          path: req.files.profilePhoto[0].path,
          mimetype: req.files.profilePhoto[0].mimetype,
          size: req.files.profilePhoto[0].size,
          uploadedAt: new Date()
        };
        console.log('✅ Photo de profil sauvegardée:', doctorData.profilePhoto.filename);
      }
      
      // Photos de la clinique
      if (req.files.clinicPhotos && req.files.clinicPhotos.length > 0) {
        doctorData.clinic.photos = req.files.clinicPhotos.map(file => ({
          filename: file.filename,
          originalName: file.originalname,
          path: file.path,
          mimetype: file.mimetype,
          size: file.size,
          uploadedAt: new Date()
        }));
        console.log('✅ Photos de clinique sauvegardées:', doctorData.clinic.photos.length, 'fichier(s)');
      }
      
      // Certifications
      if (req.files.certifications && req.files.certifications.length > 0) {
        doctorData.documents = doctorData.documents || {};
        doctorData.documents.certifications = req.files.certifications.map(file => ({
          filename: file.filename,
          originalName: file.originalname,
          path: file.path,
          mimetype: file.mimetype,
          size: file.size,
          uploadedAt: new Date()
        }));
        console.log('✅ Certifications sauvegardées:', doctorData.documents.certifications.length, 'fichier(s)');
      }
    } else {
      console.log('⚠️ Aucun fichier reçu dans req.files');
    }
    
    console.log('📁 === FIN TRAITEMENT DES FICHIERS ===\n');

    // Création d'une demande d'upgrade au lieu d'un médecin directement
    // Le document Doctor ne sera créé qu'après approbation par l'admin
    const doctorRequest = new DoctorRequest(doctorData);
    await doctorRequest.save();
    
    console.log('✅ Demande de médecin créée avec succès, ID:', doctorRequest._id);

    res.status(201).json({
      message: 'Demande d\'upgrade envoyée avec succès. En attente de validation par un administrateur.',
      request: {
        id: doctorRequest._id,
        status: doctorRequest.status,
        specialties: doctorRequest.specialties,
        requestedAt: doctorRequest.requestedAt
      }
    });

  } catch (error) {
    console.error('Erreur upgrade médecin:', error);
    res.status(500).json({
      error: 'Erreur lors de l\'upgrade vers médecin'
    });
  }
});

// @route   GET /api/doctors/search
// @desc    Rechercher des médecins par localisation et spécialité
// @access  Public
router.get('/search', [
  query('latitude')
    .optional()
    .isFloat({ min: -90, max: 90 })
    .withMessage('Latitude invalide'),
  query('longitude')
    .optional()
    .isFloat({ min: -180, max: 180 })
    .withMessage('Longitude invalide'),
  query('radius')
    .optional()
    .isFloat({ min: 1, max: 50 })
    .withMessage('Rayon de recherche invalide (1-50 km)'),
  query('specialization')
    .optional()
    .trim()
    .isLength({ min: 2 })
    .withMessage('Spécialité invalide'),
  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Numéro de page invalide'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 50 })
    .withMessage('Limite invalide (1-50)'),
  query('search')
    .optional()
    .trim()
    .isLength({ min: 1 })
    .withMessage('Terme de recherche invalide'),
  query('isAvailable')
    .optional()
    .isBoolean()
    .withMessage('Disponibilité invalide'),
  query('sortBy')
    .optional()
    .isIn(['rating', 'distance', 'experience', 'fee'])
    .withMessage('Tri invalide')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Paramètres de recherche invalides',
        details: errors.array()
      });
    }

    const {
      latitude,
      longitude,
      radius = 10,
      specialization,
      search,
      isAvailable,
      sortBy,
      page = 1,
      limit = 20
    } = req.query;

    // Construire la requête de base
    // MODE TEST: Afficher tous les médecins, même non approuvés
    let query = {
      // verificationStatus: 'approved',  // Commenté pour le test
      // isActive: true                   // Commenté pour le test
    };
    
    // Filtrer par disponibilité si spécifié
    if (isAvailable !== undefined) {
      query.isAvailable = isAvailable === 'true';
    } else {
      query.isAvailable = true; // Par défaut, seulement les disponibles
    }

    // Filtrer par spécialité si fournie
    if (specialization) {
      query.specialties = { $regex: specialization, $options: 'i' };
    }
    
    // Recherche textuelle si fournie
    if (search) {
      query.$or = [
        { specialties: { $regex: search, $options: 'i' } },
        { 'clinic.name': { $regex: search, $options: 'i' } },
        { 'clinic.address.city': { $regex: search, $options: 'i' } }
      ];
    }

    let doctors;

    // Recherche géographique si coordonnées fournies
    if (latitude && longitude) {
      const radiusInMeters = radius * 1000; // Convertir km en mètres

      doctors = await Doctor.aggregate([
        {
          $geoNear: {
            near: {
              type: "Point",
              coordinates: [parseFloat(longitude), parseFloat(latitude)]
            },
            distanceField: "distance",
            maxDistance: radiusInMeters,
            spherical: true,
            query: query
          }
        },
        {
          $lookup: {
            from: 'users',
            localField: 'userId',
            foreignField: '_id',
            as: 'userInfo'
          }
        },
        {
          $unwind: '$userInfo'
        },
        {
          $project: {
            _id: 1,
            specialties: 1,
            yearsOfExperience: 1,
            clinic: 1,
            consultationFee: 1,
            languages: 1,
            stats: 1,
            distance: { $round: [{ $divide: ["$distance", 1000] }, 2] }, // Distance en km
            doctor: {
              firstName: '$userInfo.firstName',
              lastName: '$userInfo.lastName',
              profilePicture: '$userInfo.profilePicture'
            }
          }
        },
        // Ajouter le tri si spécifié
        ...(sortBy === 'rating' ? [{ $sort: { 'stats.averageRating': -1 } }] : 
            sortBy === 'experience' ? [{ $sort: { yearsOfExperience: -1 } }] :
            sortBy === 'fee' ? [{ $sort: { consultationFee: 1 } }] :
            sortBy === 'distance' ? [] : // Déjà trié par distance avec $geoNear
            [{ $sort: { 'stats.averageRating': -1 } }]),
        { $skip: (page - 1) * limit },
        { $limit: parseInt(limit) }
      ]);
    } else {
      // Recherche sans géolocalisation
      const skip = (page - 1) * limit;
      
      // Déterminer l'ordre de tri
      let sortOptions = {};
      switch (sortBy) {
        case 'rating':
          sortOptions = { 'stats.averageRating': -1, createdAt: -1 };
          break;
        case 'experience':
          sortOptions = { yearsOfExperience: -1, 'stats.averageRating': -1 };
          break;
        case 'fee':
          sortOptions = { consultationFee: 1, 'stats.averageRating': -1 };
          break;
        default:
          sortOptions = { 'stats.averageRating': -1, createdAt: -1 };
      }
      
      doctors = await Doctor.find(query)
        .populate('userId', 'firstName lastName profilePicture')
        .select('specialties yearsOfExperience clinic consultationFee languages stats')
        .sort(sortOptions)
        .skip(skip)
        .limit(parseInt(limit));

      // Formater la réponse pour correspondre au format géographique
      doctors = doctors.map(doctor => ({
        _id: doctor._id,
        specialties: doctor.specialties,
        yearsOfExperience: doctor.yearsOfExperience,
        clinic: doctor.clinic,
        consultationFee: doctor.consultationFee,
        languages: doctor.languages,
        stats: doctor.stats,
        distance: null,
        doctor: {
          firstName: doctor.userId.firstName,
          lastName: doctor.userId.lastName,
          profilePicture: doctor.userId.profilePicture
        }
      }));
    }

    // Compter le total pour la pagination
    const total = await Doctor.countDocuments(query);

    res.json({
      doctors,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / limit),
        totalDoctors: total,
        hasNext: page * limit < total,
        hasPrev: page > 1
      },
      searchParams: {
        latitude: latitude ? parseFloat(latitude) : null,
        longitude: longitude ? parseFloat(longitude) : null,
        radius: parseFloat(radius),
        specialization,
        search,
        isAvailable: isAvailable !== undefined ? isAvailable === 'true' : true,
        sortBy: sortBy || 'rating'
      }
    });

  } catch (error) {
    console.error('Erreur recherche médecins:', error);
    res.status(500).json({
      error: 'Erreur lors de la recherche de médecins'
    });
  }
});

// @route   GET /api/doctors/:id
// @desc    Obtenir les détails d'un médecin
// @access  Public
router.get('/:id', async (req, res) => {
  try {
    // Vérifier si l'ID est un ObjectId valide
    const mongoose = require('mongoose');
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({
        error: 'ID de médecin invalide'
      });
    }
    
    const doctor = await Doctor.findById(req.params.id)
      .populate('userId', 'firstName lastName phone email profilePicture')
      .select('-documents -verificationNotes');

    if (!doctor) {
      return res.status(404).json({
        error: 'Médecin non trouvé'
      });
    }

    if (doctor.verificationStatus !== 'approved' || !doctor.isActive) {
      return res.status(404).json({
        error: 'Médecin non disponible'
      });
    }

    res.json({ doctor });

  } catch (error) {
    console.error('Erreur récupération médecin:', error);
    res.status(500).json({
      error: 'Erreur lors de la récupération des informations du médecin'
    });
  }
});

// @route   GET /api/doctors/:id/availability
// @desc    Obtenir les créneaux disponibles d'un médecin
// @access  Public
router.get('/:id/availability', [
  query('date')
    .isISO8601()
    .withMessage('Format de date invalide (YYYY-MM-DD)'),
  query('days')
    .optional()
    .isInt({ min: 1, max: 30 })
    .withMessage('Nombre de jours invalide (1-30)')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Paramètres invalides',
        details: errors.array()
      });
    }

    const { date, days = 7 } = req.query;
    const doctorId = req.params.id;

    const doctor = await Doctor.findById(doctorId);
    if (!doctor || doctor.verificationStatus !== 'approved' || !doctor.isActive) {
      return res.status(404).json({
        error: 'Médecin non trouvé ou non disponible'
      });
    }

    // TODO: Implémenter la logique de calcul des créneaux disponibles
    // Cela nécessitera de croiser les horaires de travail avec les RDV existants

    const availability = {
      doctorId,
      startDate: date,
      days: parseInt(days),
      slots: [] // À implémenter
    };

    res.json({ availability });

  } catch (error) {
    console.error('Erreur disponibilités médecin:', error);
    res.status(500).json({
      error: 'Erreur lors de la récupération des disponibilités'
    });
  }
});

// @route   PUT /api/doctors/profile
// @desc    Mettre à jour le profil médecin
// @access  Private (Doctor)
router.put('/profile', authenticate, authorize('doctor'), async (req, res) => {
  try {
    const doctor = await Doctor.findOne({ userId: req.user._id });
    
    if (!doctor) {
      return res.status(404).json({
        error: 'Profil médecin non trouvé'
      });
    }

    // Champs modifiables
    const allowedUpdates = [
      'specialties', 'yearsOfExperience', 'clinic', 'consultationFee',
      'languages', 'workingHours', 'education', 'isAvailable'
    ];

    const updates = {};
    allowedUpdates.forEach(field => {
      if (req.body[field] !== undefined) {
        updates[field] = req.body[field];
      }
    });

    Object.assign(doctor, updates);
    await doctor.save();

    res.json({
      message: 'Profil mis à jour avec succès',
      doctor
    });

  } catch (error) {
    console.error('Erreur mise à jour profil médecin:', error);
    res.status(500).json({
      error: 'Erreur lors de la mise à jour du profil'
    });
  }
});

// @route   GET /api/doctors/me/stats
// @desc    Obtenir les statistiques du médecin connecté
// @access  Private (Doctor)
router.get('/me/stats', authenticate, authorize('doctor'), async (req, res) => {
  try {
    const doctor = await Doctor.findOne({ userId: req.user._id })
      .select('stats verificationStatus');

    if (!doctor) {
      return res.status(404).json({
        error: 'Profil médecin non trouvé'
      });
    }

    res.json({
      stats: doctor.stats,
      verificationStatus: doctor.verificationStatus
    });

  } catch (error) {
    console.error('Erreur statistiques médecin:', error);
    res.status(500).json({
      error: 'Erreur lors de la récupération des statistiques'
    });
  }
});

module.exports = router;
