const express = require('express');
const { body, validationResult, query } = require('express-validator');
const User = require('../models/User');
const Doctor = require('../models/Doctor');
const Appointment = require('../models/Appointment');
const DoctorRequest = require('../models/doctorRequest');
const { authenticate, authorize, requireVerification } = require('../middleware/auth');
const { uploadWithLogs } = require('../middleware/upload');

const router = express.Router();

const normalizePath = (path) => path.replace(/\\/g, '/');

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
  // Middleware pour parser les données JSON du champ 'data'
  (req, res, next) => {
    if (req.body.data && typeof req.body.data === 'string') {
      try {
        const parsedData = JSON.parse(req.body.data);
        // Fusionner les données parsées avec req.body pour la validation
        req.body = { ...req.body, ...parsedData };
        console.log('✅ Données JSON parsées avec succès');
      } catch (e) {
        console.error('❌ Erreur de parsing du champ data JSON:', e);
        return res.status(400).json({
          error: 'Format JSON invalide dans le champ data',
          details: e.message
        });
      }
    }
    next();
  },
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
          path: normalizePath(req.files.medicalLicense[0].path),
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
          path: normalizePath(file.path),
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
          path: normalizePath(req.files.profilePhoto[0].path),
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
          path: normalizePath(file.path),
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
          path: normalizePath(file.path),
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
            distanceMultiplier: 0.001, // Convertir les mètres en km pour l'affichage
            key: "clinic.address.location", // Spécifier explicitement quel index utiliser
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
      if (sortBy === 'rating') sortOptions = { 'stats.averageRating': -1 };
      else if (sortBy === 'experience') sortOptions = { yearsOfExperience: -1 };
      else if (sortBy === 'fee') sortOptions = { consultationFee: 1 };
      else sortOptions = { 'stats.averageRating': -1 }; // Tri par défaut

      doctors = await Doctor.find(query)
        .populate('userId', 'firstName lastName profilePicture')
        .sort(sortOptions)
        .skip(skip)
        .limit(parseInt(limit));
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

// @route   GET /api/doctors/me
// @desc    Obtenir le profil du médecin connecté
// @access  Private (Doctor)
router.get('/me', authenticate, authorize('doctor'), async (req, res) => {
  try {
    const doctor = await Doctor.findOne({ userId: req.user._id })
      .populate('userId', 'firstName lastName email phone profilePicture');

    if (!doctor) {
      return res.status(404).json({ error: 'Profil médecin non trouvé' });
    }

    res.json(doctor);

  } catch (error) {
    console.error('Erreur profil médecin:', error);
    res.status(500).json({ error: 'Erreur lors de la récupération du profil' });
  }
});

// @route   GET /api/doctors/profile
// @desc    Obtenir le profil du médecin connecté (alias de /me pour compatibilité frontend)
// @access  Private (Doctor)
router.get('/profile', authenticate, authorize('doctor'), async (req, res) => {
  try {
    const doctor = await Doctor.findOne({ userId: req.user._id })
      .populate('userId', 'firstName lastName email phone profilePicture');

    if (!doctor) {
      return res.status(404).json({ error: 'Profil médecin non trouvé' });
    }

    res.json(doctor);

  } catch (error) {
    console.error('Erreur profil médecin:', error);
    res.status(500).json({ error: 'Erreur lors de la récupération du profil' });
  }
});



// @route   GET /api/doctors/check-role
// @desc    Vérifier le rôle actuel de l'utilisateur
// @access  Private
router.get('/check-role', authenticate, async (req, res) => {
  try {
    // L'utilisateur est déjà disponible grâce au middleware authenticate
    return res.status(200).json({
      success: true,
      role: req.user.role,
      isDoctor: req.user.role === 'doctor'
    });
  } catch (error) {
    console.error('Erreur lors de la vérification du rôle:', error);
    return res.status(500).json({
      success: false,
      message: 'Erreur serveur lors de la vérification du rôle'
    });
  }
});

// @route   GET /api/doctors/:id
// @desc    Obtenir les détails d'un médecin
// @access  Public
router.get('/:id', async (req, res) => {
  try {
    const doctor = await Doctor.findById(req.params.id)
      .populate('userId', 'firstName lastName profilePicture')
      .select('-documents'); // Exclure les documents sensibles

    if (!doctor) {
      return res.status(404).json({ error: 'Médecin non trouvé' });
    }

    res.json(doctor);

  } catch (error) {
    console.error('Erreur détails médecin:', error);
    if (error.kind === 'ObjectId') {
      return res.status(404).json({ error: 'Médecin non trouvé (ID invalide)' });
    }
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// @route   PUT /api/doctors/me
// @desc    Mettre à jour le profil du médecin connecté
// @access  Private (Doctor)
router.put('/me', authenticate, authorize('doctor'), async (req, res) => {
  try {
    const doctor = await Doctor.findOne({ userId: req.user._id });

    if (!doctor) {
      return res.status(404).json({ error: 'Profil médecin non trouvé' });
    }

    // Mettre à jour les champs autorisés
    const allowedUpdates = [
      'specialties',
      'yearsOfExperience',
      'clinic',
      'consultationFee',
      'languages',
      'education',
      'workingHours',
      'isAvailable'
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
      .select('stats verificationStatus currency');

    if (!doctor) {
      return res.status(404).json({ error: 'Profil médecin non trouvé' });
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

// @route   PUT /api/doctors/schedule
// @desc    Mettre à jour les horaires d'un médecin
// @access  Private (Médecin)

router.put('/schedule',
  authenticate,
  // Réactiver l'autorisation - elle est nécessaire pour la sécurité
  authorize('doctor'),
  [
    body('workingHours').isObject().withMessage('Les horaires de travail doivent être un objet.'),
    body('workingHours.*.isAvailable').isBoolean().withMessage('La disponibilité doit être un booléen.'),
    body('workingHours.*.startTime').matches(/^([01][0-9]|2[0-3]):[0-5][0-9]$/).withMessage('Heure de début invalide (HH:MM).'),
    body('workingHours.*.endTime').matches(/^([01][0-9]|2[0-3]):[0-5][0-9]$/).withMessage('Heure de fin invalide (HH:MM).'),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    try {
      const doctor = await Doctor.findOne({ userId: req.user._id });

      if (!doctor) {
        return res.status(404).json({ msg: 'Profil de médecin non trouvé' });
      }
      
      // Conversion du format frontend vers le format backend
      const frontendWorkingHours = req.body.workingHours;
      const backendWorkingHours = {};
      
      // Mapping des jours français vers anglais
      const dayMapping = {
        'Lundi': 'monday',
        'Mardi': 'tuesday',
        'Mercredi': 'wednesday',
        'Jeudi': 'thursday',
        'Vendredi': 'friday',
        'Samedi': 'saturday',
        'Dimanche': 'sunday'
      };
      
      // Conversion du format
      Object.keys(frontendWorkingHours).forEach(frenchDay => {
        const englishDay = dayMapping[frenchDay];
        if (englishDay) {
          const dayData = frontendWorkingHours[frenchDay];
          backendWorkingHours[englishDay] = {
            isWorking: dayData.isAvailable,
            startTime: dayData.startTime,
            endTime: dayData.endTime
          };
        }
      });
      
      // Mise à jour des horaires
      doctor.workingHours = backendWorkingHours;
      await doctor.save();
      
      // Récupérer le document mis à jour pour s'assurer d'avoir toutes les données
      const updatedDoctor = await Doctor.findById(doctor._id);
      
      console.log('Horaires mis à jour:', backendWorkingHours);
      // Renvoyer explicitement les données complètes
      res.json({ 
        msg: 'Horaires mis à jour avec succès', 
        workingHours: {
          monday: {
            isWorking: updatedDoctor.workingHours.monday.isWorking,
            startTime: updatedDoctor.workingHours.monday.startTime,
            endTime: updatedDoctor.workingHours.monday.endTime
          },
          tuesday: {
            isWorking: updatedDoctor.workingHours.tuesday.isWorking,
            startTime: updatedDoctor.workingHours.tuesday.startTime,
            endTime: updatedDoctor.workingHours.tuesday.endTime
          },
          wednesday: {
            isWorking: updatedDoctor.workingHours.wednesday.isWorking,
            startTime: updatedDoctor.workingHours.wednesday.startTime,
            endTime: updatedDoctor.workingHours.wednesday.endTime
          },
          thursday: {
            isWorking: updatedDoctor.workingHours.thursday.isWorking,
            startTime: updatedDoctor.workingHours.thursday.startTime,
            endTime: updatedDoctor.workingHours.thursday.endTime
          },
          friday: {
            isWorking: updatedDoctor.workingHours.friday.isWorking,
            startTime: updatedDoctor.workingHours.friday.startTime,
            endTime: updatedDoctor.workingHours.friday.endTime
          },
          saturday: {
            isWorking: updatedDoctor.workingHours.saturday.isWorking,
            startTime: updatedDoctor.workingHours.saturday.startTime,
            endTime: updatedDoctor.workingHours.saturday.endTime
          },
          sunday: {
            isWorking: updatedDoctor.workingHours.sunday.isWorking,
            startTime: updatedDoctor.workingHours.sunday.startTime,
            endTime: updatedDoctor.workingHours.sunday.endTime
          }
        }
      });
    } catch (err) {
      console.error(err.message);
      res.status(500).send('Erreur du serveur');
    }
  }
);

// @route   GET /api/doctors/me/patients
// @desc    Récupérer les patients d'un médecin
// @access  Private (Médecin)
router.get('/me/patients', authenticate, authorize('doctor'), async (req, res) => {
  try {
    const doctor = await Doctor.findOne({ userId: req.user._id });
    
    if (!doctor) {
      return res.status(404).json({ msg: 'Profil de médecin non trouvé' });
    }

    // Récupérer tous les rendez-vous confirmés ou terminés de ce médecin
    const appointments = await Appointment.find({
      doctor: doctor._id,
      status: { $in: ['confirmed', 'completed'] }
    })
    .populate('patient', 'firstName lastName phone email dateOfBirth gender address profilePicture')
    .sort({ appointmentDate: -1 });

    // Extraire les patients uniques avec leurs informations
    const patientsMap = new Map();
    
    appointments.forEach(appointment => {
      if (appointment.patient) {
        const patientId = appointment.patient._id.toString();
        
        if (!patientsMap.has(patientId)) {
          patientsMap.set(patientId, {
            id: appointment.patient._id,
            firstName: appointment.patient.firstName,
            lastName: appointment.patient.lastName,
            phone: appointment.patient.phone,
            email: appointment.patient.email,
            dateOfBirth: appointment.patient.dateOfBirth,
            gender: appointment.patient.gender,
            address: appointment.patient.address,
            profilePicture: appointment.patient.profilePicture,
            lastAppointment: appointment.appointmentDate,
            totalAppointments: 1,
            completedAppointments: appointment.status === 'completed' ? 1 : 0
          });
        } else {
          // Mettre à jour les statistiques du patient
          const existingPatient = patientsMap.get(patientId);
          existingPatient.totalAppointments += 1;
          if (appointment.status === 'completed') {
            existingPatient.completedAppointments += 1;
          }
          // Garder la date du dernier rendez-vous
          if (new Date(appointment.appointmentDate) > new Date(existingPatient.lastAppointment)) {
            existingPatient.lastAppointment = appointment.appointmentDate;
          }
        }
      }
    });

    // Convertir la Map en array
    const patients = Array.from(patientsMap.values());

    res.json({
      success: true,
      count: patients.length,
      patients
    });

  } catch (err) {
    console.error('Erreur lors de la récupération des patients:', err.message);
    res.status(500).json({ msg: 'Erreur du serveur' });
  }
});

// @route   PUT /api/doctors/me
// @desc    Mettre à jour le profil du médecin
// @access  Private (Doctor)
router.put('/me', authenticate, authorize('doctor'), async (req, res) => {
  try {
    const {
      yearsOfExperience,
      bio,
      languages,
      consultationFee,
      clinic
    } = req.body;

    // Trouver le profil du médecin
    const doctor = await Doctor.findOne({ userId: req.user._id });
    if (!doctor) {
      return res.status(404).json({ error: 'Profil médecin non trouvé' });
    }

    // Mettre à jour les champs modifiables
    if (yearsOfExperience !== undefined) doctor.yearsOfExperience = yearsOfExperience;
    if (bio !== undefined) doctor.bio = bio;
    if (languages !== undefined) doctor.languages = languages;
    if (consultationFee !== undefined) doctor.consultationFee = consultationFee;
    if (clinic !== undefined) doctor.clinic = clinic;

    await doctor.save();

    // Retourner le profil mis à jour avec les données utilisateur
    const updatedDoctor = await Doctor.findOne({ userId: req.user._id })
      .populate('userId', 'firstName lastName email phone profilePicture');

    res.json(updatedDoctor);
  } catch (error) {
    console.error('Erreur mise à jour profil médecin:', error);
    res.status(500).json({ error: 'Erreur lors de la mise à jour du profil' });
  }
});

// @route   POST /api/doctors/me/profile-image
// @desc    Upload de la photo de profil du médecin
// @access  Private (Doctor)
router.post('/me/profile-image', 
  authenticate, 
  authorize('doctor'),
  uploadWithLogs([{ name: 'profileImage', maxCount: 1 }]),
  async (req, res) => {
    try {
      if (!req.files || !req.files.profileImage || req.files.profileImage.length === 0) {
        return res.status(400).json({ error: 'Aucune image fournie' });
      }

      const profileImageFile = req.files.profileImage[0];
      // Convertir le chemin complet en chemin relatif
      const fullPath = normalizePath(profileImageFile.path);
      const profileImagePath = fullPath.replace(/.*[\\\/]uploads[\\\/]/, '/uploads/');

      // Mettre à jour la photo de profil dans le modèle User
      await User.findByIdAndUpdate(req.user._id, {
        profilePicture: profileImagePath
      });

      // Traiter les données additionnelles si présentes
      if (req.body.yearsOfExperience || req.body.bio || req.body.languages || 
          req.body.consultationFee || req.body.clinic) {
        
        const doctor = await Doctor.findOne({ userId: req.user._id });
        if (doctor) {
          if (req.body.yearsOfExperience !== undefined) {
            doctor.yearsOfExperience = parseInt(req.body.yearsOfExperience);
          }
          if (req.body.bio !== undefined) doctor.bio = req.body.bio;
          if (req.body.languages !== undefined) {
            try {
              if (Array.isArray(req.body.languages)) {
                doctor.languages = req.body.languages;
              } else if (typeof req.body.languages === 'string') {
                // Essayer de parser comme JSON d'abord
                try {
                  doctor.languages = JSON.parse(req.body.languages);
                } catch {
                  // Si ça échoue, traiter comme une chaîne simple avec des virgules
                  doctor.languages = req.body.languages
                    .replace(/[\[\]]/g, '') // Supprimer les crochets
                    .split(',')
                    .map(lang => lang.trim())
                    .filter(lang => lang.length > 0);
                }
              }
            } catch (error) {
              console.error('Erreur parsing languages:', error);
              doctor.languages = [];
            }
          }
          if (req.body.consultationFee !== undefined) {
            doctor.consultationFee = parseFloat(req.body.consultationFee);
          }
          if (req.body.clinic !== undefined) {
            try {
              doctor.clinic = typeof req.body.clinic === 'string' 
                ? JSON.parse(req.body.clinic) 
                : req.body.clinic;
            } catch (error) {
              console.error('Erreur parsing clinic:', error);
              // Garder la valeur existante en cas d'erreur
            }
          }
          
          await doctor.save();
        }
      }

      // Retourner le profil mis à jour
      const updatedDoctor = await Doctor.findOne({ userId: req.user._id })
        .populate('userId', 'firstName lastName email phone profilePicture');

      // Retourner directement les données du docteur pour compatibilité avec le frontend
      res.json(updatedDoctor);
    } catch (error) {
      console.error('Erreur upload photo profil:', error);
      res.status(500).json({ error: 'Erreur lors de l\'upload de la photo' });
    }
  }
);

module.exports = router;
