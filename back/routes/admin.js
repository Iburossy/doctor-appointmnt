const express = require('express');
const { body, param, validationResult, query } = require('express-validator');
const User = require('../models/User');
const Doctor = require('../models/Doctor');
const Patient = require('../models/Patient');
const DoctorRequest = require('../models/doctorRequest');
const Appointment = require('../models/Appointment');
const MedicalRecord = require('../models/MedicalRecord');
const Notification = require('../models/Notification');
const RefreshToken = require('../models/RefreshToken');
const PasswordResetToken = require('../models/PasswordResetToken');
const AuditLog = require('../models/AuditLog');
const { authenticate: auth, authorize: adminCheck } = require('../middleware/auth');
const { sendPushNotification } = require('../services/pushNotification.service');

const router = express.Router();

// @route   GET /api/admin/dashboard
// @desc    Obtenir les statistiques du dashboard admin
// @access  Private (Admin)
router.get('/dashboard', auth, adminCheck('admin'), async (req, res) => {
  try {
    // Statistiques générales
    const totalUsers = await User.countDocuments({ isActive: true });
    const totalPatients = await User.countDocuments({ role: 'patient', isActive: true });
    const totalDoctors = await Doctor.countDocuments({ verificationStatus: 'approved', isActive: true });
    const pendingDoctorRequests = await DoctorRequest.countDocuments({ status: 'pending' });
    
    // Statistiques des rendez-vous
    const totalAppointments = await Appointment.countDocuments();
    const todayAppointments = await Appointment.countDocuments({
      appointmentDate: {
        $gte: new Date(new Date().setHours(0, 0, 0, 0)),
        $lt: new Date(new Date().setHours(23, 59, 59, 999))
      }
    });
    
    const appointmentsByStatus = await Appointment.aggregate([
      {
        $group: {
          _id: '$status',
          count: { $sum: 1 }
        }
      }
    ]);

    // Statistiques des derniers 30 jours
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    
    const newUsersLast30Days = await User.countDocuments({
      createdAt: { $gte: thirtyDaysAgo },
      isActive: true
    });
    
    const appointmentsLast30Days = await Appointment.countDocuments({
      createdAt: { $gte: thirtyDaysAgo }
    });

    // Top médecins par nombre de rendez-vous (simplifié pour debug)
    let topDoctors = [];
    try {
      topDoctors = await Appointment.aggregate([
        {
          $match: {
            status: 'completed',
            createdAt: { $gte: thirtyDaysAgo }
          }
        },
        {
          $group: {
            _id: '$doctor',
            appointmentCount: { $sum: 1 }
          }
        },
        {
          $lookup: {
            from: 'doctors',
            localField: '_id',
            foreignField: '_id',
            as: 'doctorInfo'
          }
        },
        {
          $unwind: '$doctorInfo'
        },
        {
          $lookup: {
            from: 'users',
            localField: 'doctorInfo.userId',
            foreignField: '_id',
            as: 'userInfo'
          }
        },
        {
          $unwind: '$userInfo'
        },
        {
          $project: {
            appointmentCount: 1,
            doctorName: {
              $concat: ['$userInfo.firstName', ' ', '$userInfo.lastName']
            },
            specialties: '$doctorInfo.specialties'
          }
        },
        {
          $sort: { appointmentCount: -1 }
        },
        {
          $limit: 5
        }
      ]);
    } catch (aggregationError) {
      console.error('Erreur agrégation top doctors:', aggregationError);
      topDoctors = [];
    }

    res.json({
      overview: {
        totalUsers,
        totalPatients,
        totalDoctors,
        pendingDoctorRequests,
        totalAppointments,
        todayAppointments
      },
      appointmentsByStatus: appointmentsByStatus.reduce((acc, item) => {
        acc[item._id] = item.count;
        return acc;
      }, {}),
      trends: {
        newUsersLast30Days,
        appointmentsLast30Days
      },
      topDoctors
    });

  } catch (error) {
    console.error('Erreur dashboard admin:', error);
    res.status(500).json({
      error: 'Erreur lors de la récupération des statistiques'
    });
  }
});

// @route   GET /api/admin/doctors/pending
// @desc    Obtenir la liste des médecins en attente de validation
// @access  Private (Admin)
router.get('/doctors/pending', auth, adminCheck('admin'), [
  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Numéro de page invalide'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 50 })
    .withMessage('Limite invalide (1-50)')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Paramètres invalides',
        details: errors.array()
      });
    }

    const { page = 1, limit = 10, status = 'pending' } = req.query;
    const skip = (page - 1) * limit;
    
    // Filtre par statut (pending, approved, rejected)
    const filter = status ? { status } : {};

    const doctorRequests = await DoctorRequest.find(filter)
      .populate('userId', 'firstName lastName phone email createdAt')
      .sort({ requestedAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await DoctorRequest.countDocuments(filter);

    res.json({
      doctorRequests,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / limit),
        totalRequests: total,
        hasNext: page * limit < total,
        hasPrev: page > 1
      },
      filters: {
        status
      }
    });

  } catch (error) {
    console.error('Erreur récupération médecins en attente:', error);
    res.status(500).json({
      error: 'Erreur lors de la récupération des médecins en attente'
    });
  }
});

// @route   GET /api/admin/doctor-requests
// @desc    Obtenir la liste de toutes les demandes d'upgrade médecin avec filtres
// @access  Private (Admin)
router.get('/doctor-requests', auth, adminCheck('admin'), [
  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Numéro de page invalide'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 50 })
    .withMessage('Limite invalide (1-50)'),
  query('status')
    .optional()
    .isIn(['pending', 'approved', 'rejected'])
    .withMessage('Statut invalide'),
  query('search')
    .optional()
    .trim()
    .isLength({ min: 2 })
    .withMessage('La recherche doit contenir au moins 2 caractères')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Paramètres invalides',
        details: errors.array()
      });
    }

    const { page = 1, limit = 10, status, search } = req.query;
    const skip = (page - 1) * limit;
    
    // Construction du filtre
    const filter = {};
    if (status) {
      filter.status = status;
    }
    
    // Recherche textuelle sur plusieurs champs
    if (search) {
      filter.$or = [
        { medicalLicenseNumber: { $regex: search, $options: 'i' } },
        { 'specialties': { $in: [new RegExp(search, 'i')] } },
        { bio: { $regex: search, $options: 'i' } }
      ];
    }

    const doctorRequests = await DoctorRequest.find(filter)
      .populate('userId', 'firstName lastName phone email createdAt')
      .populate('reviewedBy', 'firstName lastName email')
      .sort({ requestedAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await DoctorRequest.countDocuments(filter);

    // Statistiques par statut
    const statusStats = await DoctorRequest.aggregate([
      { $match: filter },
      {
        $group: {
          _id: '$status',
          count: { $sum: 1 }
        }
      }
    ]);

    res.json({
      success: true,
      data: {
        doctorRequests,
        pagination: {
          currentPage: parseInt(page),
          totalPages: Math.ceil(total / limit),
          totalRequests: total,
          hasNext: page * limit < total,
          hasPrev: page > 1
        },
        filters: {
          status,
          search
        },
        stats: {
          total,
          byStatus: statusStats.reduce((acc, stat) => {
            acc[stat._id] = stat.count;
            return acc;
          }, {})
        }
      }
    });

  } catch (error) {
    console.error('Erreur récupération demandes médecin:', error);
    res.status(500).json({
      error: 'Erreur lors de la récupération des demandes'
    });
  }
});

// @route   GET /api/admin/doctor-requests/:id
// @desc    Obtenir les détails d'une demande d'upgrade médecin spécifique
// @access  Private (Admin)
router.get('/doctor-requests/:id', auth, adminCheck('admin'), async (req, res) => {
  try {
    const { id } = req.params;

    const doctorRequest = await DoctorRequest.findById(id)
      .populate('userId', 'firstName lastName phone email createdAt')
      .populate('reviewedBy', 'firstName lastName email');

    if (!doctorRequest) {
      return res.status(404).json({
        error: 'Demande non trouvée'
      });
    }

    res.json({
      success: true,
      data: {
        id: doctorRequest._id,
        userId: doctorRequest.userId,
        specialties: doctorRequest.specialties,
        yearsOfExperience: doctorRequest.yearsOfExperience,
        medicalLicenseNumber: doctorRequest.medicalLicenseNumber,
        education: doctorRequest.education,
        consultationFee: doctorRequest.consultationFee,
        clinic: doctorRequest.clinic,
        languages: doctorRequest.languages,
        bio: doctorRequest.bio,
        documents: doctorRequest.documents,
        profilePhoto: doctorRequest.profilePhoto,
        status: doctorRequest.status,
        rejectionReason: doctorRequest.rejectionReason,
        adminNotes: doctorRequest.adminNotes,
        requestedAt: doctorRequest.requestedAt,
        reviewedAt: doctorRequest.reviewedAt,
        reviewedBy: doctorRequest.reviewedBy
      }
    });

  } catch (error) {
    console.error('Erreur récupération détails demande:', error);
    res.status(500).json({
      error: 'Erreur lors de la récupération des détails de la demande'
    });
  }
});

// ANCIENNE ROUTE SUPPRIMÉE - Remplacée par /doctor-requests/:id/approve et /doctor-requests/:id/reject
// qui utilisent le modèle DoctorRequest au lieu de Doctor

// @route   GET /api/admin/users
// @desc    Obtenir la liste des utilisateurs
// @access  Private (Admin)
router.get('/users', auth, adminCheck('admin'), [
  query('role')
    .optional()
    .isIn(['patient', 'doctor', 'admin'])
    .withMessage('Rôle invalide'),
  query('isActive')
    .optional()
    .isBoolean()
    .withMessage('Statut actif invalide'),
  query('search')
    .optional()
    .trim()
    .isLength({ min: 2 })
    .withMessage('Terme de recherche trop court'),
  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Numéro de page invalide'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 50 })
    .withMessage('Limite invalide (1-50)')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Paramètres invalides',
        details: errors.array()
      });
    }

    const { role, isActive, search, page = 1, limit = 20 } = req.query;
    const skip = (page - 1) * limit;

    // Construire la requête
    let query = {};

    if (role) {
      query.role = role;
    }

    if (isActive !== undefined) {
      query.isActive = isActive === 'true';
    }

    if (search) {
      query.$or = [
        { firstName: { $regex: search, $options: 'i' } },
        { lastName: { $regex: search, $options: 'i' } },
        { phone: { $regex: search, $options: 'i' } },
        { email: { $regex: search, $options: 'i' } }
      ];
    }

    const users = await User.find(query)
      .select('-password -phoneVerificationCode -emailVerificationCode -passwordResetCode')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await User.countDocuments(query);

    res.json({
      users,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / limit),
        totalUsers: total,
        hasNext: page * limit < total,
        hasPrev: page > 1
      },
      filters: {
        role,
        isActive,
        search
      }
    });

  } catch (error) {
    console.error('Erreur récupération utilisateurs:', error);
    res.status(500).json({
      error: 'Erreur lors de la récupération des utilisateurs'
    });
  }
});

// @route   PUT /api/admin/users/:id/status
// @desc    Activer/désactiver un utilisateur
// @access  Private (Admin)
router.put('/users/:id/status', auth, adminCheck('admin'), [
  body('isActive')
    .isBoolean()
    .withMessage('Statut actif requis (true/false)'),
  body('reason')
    .optional()
    .trim()
    .isLength({ max: 200 })
    .withMessage('La raison ne peut pas dépasser 200 caractères')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Données invalides',
        details: errors.array()
      });
    }

    const { isActive, reason } = req.body;
    const userId = req.params.id;

    const user = await User.findById(userId);

    if (!user) {
      return res.status(404).json({
        error: 'Utilisateur non trouvé'
      });
    }

    // Ne pas permettre de désactiver un admin
    if (user.role === 'admin' && !isActive) {
      return res.status(400).json({
        error: 'Impossible de désactiver un compte administrateur'
      });
    }

    // Ne pas permettre de se désactiver soi-même
    if (user._id.toString() === req.user._id.toString() && !isActive) {
      return res.status(400).json({
        error: 'Vous ne pouvez pas désactiver votre propre compte'
      });
    }

    user.isActive = isActive;
    await user.save();

    // Si c'est un médecin, mettre à jour aussi le profil médecin
    if (user.role === 'doctor') {
      await Doctor.findOneAndUpdate(
        { userId: user._id },
        { isActive: isActive }
      );
    }

    const action = isActive ? 'activé' : 'désactivé';
    console.log(`👤 Utilisateur ${user.firstName} ${user.lastName} ${action} par admin`);

    res.json({
      message: `Utilisateur ${action} avec succès`,
      user: {
        id: user._id,
        firstName: user.firstName,
        lastName: user.lastName,
        isActive: user.isActive
      }
    });

  } catch (error) {
    console.error('Erreur modification statut utilisateur:', error);
    res.status(500).json({
      error: 'Erreur lors de la modification du statut'
    });
  }
});

// @route   GET /api/admin/appointments
// @desc    Obtenir la liste des rendez-vous (admin)
// @access  Private (Admin)
router.get('/appointments', auth, adminCheck('admin'), [
  query('status')
    .optional()
    .isIn(['pending', 'confirmed', 'completed', 'cancelled', 'no_show'])
    .withMessage('Statut invalide'),
  query('date')
    .optional()
    .isISO8601()
    .withMessage('Format de date invalide'),
  query('doctorId')
    .optional()
    .isMongoId()
    .withMessage('ID médecin invalide'),
  query('patientId')
    .optional()
    .isMongoId()
    .withMessage('ID patient invalide'),
  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Numéro de page invalide'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 50 })
    .withMessage('Limite invalide (1-50)')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Paramètres invalides',
        details: errors.array()
      });
    }

    const { status, date, doctorId, patientId, page = 1, limit = 20 } = req.query;
    const skip = (page - 1) * limit;

    // Construire la requête
    let query = {};

    if (status) {
      query.status = status;
    }

    if (date) {
      const searchDate = new Date(date);
      query.appointmentDate = {
        $gte: new Date(searchDate.setHours(0, 0, 0, 0)),
        $lt: new Date(searchDate.setHours(23, 59, 59, 999))
      };
    }

    if (doctorId) {
      query.doctor = doctorId;
    }

    if (patientId) {
      query.patient = patientId;
    }

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
      },
      filters: {
        status,
        date,
        doctorId,
        patientId
      }
    });

  } catch (error) {
    console.error('Erreur récupération rendez-vous admin:', error);
    res.status(500).json({
      error: 'Erreur lors de la récupération des rendez-vous'
    });
  }
});

// @route   GET /api/admin/reports/monthly
// @desc    Rapport mensuel
// @access  Private (Admin)
router.get('/reports/monthly', auth, adminCheck('admin'), [
  query('year')
    .isInt({ min: 2020, max: 2030 })
    .withMessage('Année invalide'),
  query('month')
    .isInt({ min: 1, max: 12 })
    .withMessage('Mois invalide')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Paramètres invalides',
        details: errors.array()
      });
    }

    const { year, month } = req.query;
    const startDate = new Date(year, month - 1, 1);
    const endDate = new Date(year, month, 0, 23, 59, 59, 999);

    // Nouveaux utilisateurs
    const newUsers = await User.countDocuments({
      createdAt: { $gte: startDate, $lte: endDate },
      isActive: true
    });

    // Nouveaux médecins approuvés
    const newDoctors = await Doctor.countDocuments({
      verificationDate: { $gte: startDate, $lte: endDate },
      verificationStatus: 'approved'
    });

    // Rendez-vous du mois
    const appointmentsStats = await Appointment.aggregate([
      {
        $match: {
          appointmentDate: { $gte: startDate, $lte: endDate }
        }
      },
      {
        $group: {
          _id: '$status',
          count: { $sum: 1 },
          totalAmount: { $sum: '$payment.amount' }
        }
      }
    ]);

    // Rendez-vous par jour
    const dailyAppointments = await Appointment.aggregate([
      {
        $match: {
          appointmentDate: { $gte: startDate, $lte: endDate }
        }
      },
      {
        $group: {
          _id: {
            day: { $dayOfMonth: '$appointmentDate' },
            month: { $month: '$appointmentDate' },
            year: { $year: '$appointmentDate' }
          },
          count: { $sum: 1 }
        }
      },
      {
        $sort: { '_id.day': 1 }
      }
    ]);

    res.json({
      period: {
        year: parseInt(year),
        month: parseInt(month),
        startDate,
        endDate
      },
      summary: {
        newUsers,
        newDoctors,
        totalAppointments: appointmentsStats.reduce((sum, stat) => sum + stat.count, 0),
        totalRevenue: appointmentsStats.reduce((sum, stat) => sum + (stat.totalAmount || 0), 0)
      },
      appointmentsByStatus: appointmentsStats.reduce((acc, stat) => {
        acc[stat._id] = {
          count: stat.count,
          totalAmount: stat.totalAmount || 0
        };
        return acc;
      }, {}),
      dailyAppointments
    });

  } catch (error) {
    console.error('Erreur rapport mensuel:', error);
    res.status(500).json({
      error: 'Erreur lors de la génération du rapport mensuel'
    });
  }
});

// =============================================================================
// GESTION DES DEMANDES D'UPGRADE PATIENT → MÉDECIN
// =============================================================================

// @route   GET /api/admin/doctor-requests
// @desc    Obtenir toutes les demandes d'upgrade médecin
// @access  Private (Admin)
router.get('/doctor-requests', auth, adminCheck('admin'), [
  query('status')
    .optional()
    .isIn(['pending', 'approved', 'rejected'])
    .withMessage('Statut invalide'),
  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Page invalide'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limite invalide')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Paramètres invalides',
        details: errors.array()
      });
    }

    const { status, page = 1, limit = 10 } = req.query;
    const skip = (page - 1) * limit;

    // Construire le filtre
    let filter = {};
    if (status) {
      filter.status = status; // Utiliser 'status' au lieu de 'verificationStatus'
    }

    // Récupérer les demandes avec pagination
    const requests = await DoctorRequest.find(filter)
      .populate({
        path: 'userId',
        select: 'firstName lastName phone email createdAt',
        model: 'User'
      })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .lean();
      
    console.log('👤 Premier utilisateur:', requests[0]?.userId);

    // Compter le total
    const total = await DoctorRequest.countDocuments(filter);

    // Formater les données pour l'admin
    const formattedRequests = requests.map(request => {
      // Vérifier si userId est correctement populé
      const userId = request.userId || {};
      console.log('👤 Données utilisateur pour la demande:', request._id, userId);
      
      return {
        id: request._id,
        user: {
          id: userId._id || 'inconnu',
          firstName: userId.firstName || 'Utilisateur',
          lastName: userId.lastName || '',
          phone: userId.phone || '',
          email: userId.email || '',
          registeredAt: userId.createdAt || new Date()
        },
        specialties: request.specialties,
        yearsOfExperience: request.yearsOfExperience,
        education: request.education,
        documents: request.documents,
        workingHours: request.workingHours,
        consultationFee: request.consultationFee,
        clinic: request.clinic,
        languages: request.languages,
        bio: request.bio,
        status: request.status, // 'pending', 'approved', 'rejected'
        rejectionReason: request.rejectionReason,
        reviewedAt: request.reviewedAt,
        reviewedBy: request.reviewedBy,
        requestedAt: request.requestedAt || request.createdAt,
        updatedAt: request.updatedAt
      };
    });

    res.json({
      success: true,
      data: {
        requests: formattedRequests,
        pagination: {
          current: parseInt(page),
          total: Math.ceil(total / limit),
          count: formattedRequests.length,
          totalRequests: total
        }
      }
    });

  } catch (error) {
    console.error('Erreur récupération demandes:', error);
    res.status(500).json({
      error: 'Erreur lors de la récupération des demandes'
    });
  }
});

// @route   GET /api/admin/doctor-requests/:id
// @desc    Obtenir les détails d'une demande spécifique (accepte l'ID médecin ou l'ID utilisateur)
// @access  Private (Admin)
router.get('/doctor-requests/:id', auth, adminCheck('admin'), async (req, res) => {
  try {
    const { id } = req.params;
    
    // Essayer de trouver par ID de la demande d'abord
    let request = await DoctorRequest.findById(id)
      .populate('userId', 'firstName lastName phone email createdAt lastLogin')
      .populate('reviewedBy', 'firstName lastName')
      .lean();
    
    // Si non trouvé, essayer de trouver par ID utilisateur
    if (!request) {
      console.log(`Demande non trouvée avec l'ID ${id}, recherche par userId...`);
      request = await DoctorRequest.findOne({ userId: id })
        .populate('userId', 'firstName lastName phone email createdAt lastLogin')
        .populate('reviewedBy', 'firstName lastName')
        .lean();
    }

    if (!request) {
      return res.status(404).json({
        error: 'Demande non trouvée'
      });
    }

    // Pour les demandes approuvées, vérifier si un médecin existe déjà et récupérer ses statistiques
    let stats = null;
    let doctorRecord = null;
    if (request.status === 'approved' && request.userId) {
      // Essayer de trouver un médecin associé à cette demande approuvée
      doctorRecord = await Doctor.findOne({ userId: request.userId._id }).lean();
      
      // Si un médecin existe, récupérer ses statistiques
      if (doctorRecord) {
        const appointmentStats = await Appointment.aggregate([
          { $match: { doctor: doctorRecord._id } },
          {
            $group: {
              _id: '$status',
              count: { $sum: 1 }
            }
          }
        ]);

        const totalAppointments = await Appointment.countDocuments({ doctor: doctorRecord._id });
        const completedAppointments = await Appointment.countDocuments({ 
          doctor: doctorRecord._id, 
          status: 'completed' 
        });

        stats = {
          totalAppointments,
          completedAppointments,
          appointmentsByStatus: appointmentStats,
          successRate: totalAppointments > 0 ? ((completedAppointments / totalAppointments) * 100).toFixed(1) : 0
        };
      }
    }

    const formattedRequest = {
      id: request._id,
      user: {
        id: request.userId._id,
        firstName: request.userId.firstName,
        lastName: request.userId.lastName,
        phone: request.userId.phone,
        email: request.userId.email,
        registeredAt: request.userId.createdAt,
        lastLogin: request.userId.lastLogin
      },
      specialties: request.specialties,
      yearsOfExperience: request.yearsOfExperience,
      education: request.education,
      workingHours: request.workingHours,
      consultationFee: request.consultationFee,
      clinic: request.clinic,
      languages: request.languages,
      bio: request.bio,
      // Ajout des documents avec gestion des cas où documents est un tableau vide
      documents: request.documents && !Array.isArray(request.documents) ? request.documents : {
        medicalLicense: null,
        diplomas: [],
        certifications: []
      },
      profilePhoto: request.profilePhoto,
      status: request.status, // 'pending', 'approved', 'rejected'
      rejectionReason: request.rejectionReason,
      reviewedAt: request.reviewedAt,
      reviewedBy: request.reviewedBy ? {
        id: request.reviewedBy._id,
        name: `${request.reviewedBy.firstName} ${request.reviewedBy.lastName}`
      } : null,
      requestedAt: request.requestedAt || request.createdAt,
      updatedAt: request.updatedAt,
      doctorId: doctorRecord?._id, // ID du médecin si la demande a été approuvée et convertie
      stats
    };

    res.json({
      success: true,
      data: formattedRequest
    });

  } catch (error) {
    console.error('Erreur récupération détails demande:', error);
    res.status(500).json({
      error: 'Erreur lors de la récupération des détails'
    });
  }
});

// @route   POST /api/admin/doctor-requests/:id/approve
// @desc    Approuver une demande d'upgrade médecin
// @access  Private (Admin)
router.post('/doctor-requests/:id/approve', auth, adminCheck('admin'), [
  body('notes')
    .optional()
    .isLength({ max: 500 })
    .withMessage('Les notes ne peuvent pas dépasser 500 caractères')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Données invalides',
        details: errors.array()
      });
    }

    const { id } = req.params;
    const { notes } = req.body;
    const adminId = req.user.id;

    // Vérifier que la demande existe et est en attente
    const doctorRequest = await DoctorRequest.findById(id).populate('userId');
    if (!doctorRequest) {
      return res.status(404).json({
        error: 'Demande non trouvée'
      });
    }

    if (doctorRequest.status !== 'pending') {
      return res.status(400).json({
        error: 'Cette demande a déjà été traitée'
      });
    }

    // Approuver la demande
    doctorRequest.status = 'approved';
    doctorRequest.reviewedAt = new Date();
    doctorRequest.reviewedBy = adminId;
    doctorRequest.adminNotes = notes || '';
    await doctorRequest.save();

    // NOUVEAU: Créer un nouveau médecin à partir des données de la demande
    // Mapper correctement les champs education (graduationYear vers year)
    const educationMapped = doctorRequest.education.map(edu => {
      return {
        degree: edu.degree,
        institution: edu.institution,
        year: edu.graduationYear, // Mapper graduationYear vers year
        country: edu.country || 'Sénégal'
      };
    });
    
    // Transformer les coordonnées du format latitude/longitude au format GeoJSON Point
    // Créer une copie profonde de l'objet clinic pour éviter de modifier l'original
    const clinic = JSON.parse(JSON.stringify(doctorRequest.clinic));
    
    // Vérifier si les coordonnées existent
    if (clinic && clinic.address && clinic.address.coordinates) {
      // Transformer les coordonnées au format GeoJSON
      clinic.address.location = {
        type: 'Point',
        coordinates: [
          clinic.address.coordinates.longitude,  // Longitude d'abord
          clinic.address.coordinates.latitude    // Puis latitude
        ]
      };
      // Supprimer l'ancien champ coordinates
      delete clinic.address.coordinates;
    } else {
      console.warn('⚠️ Aucune coordonnée trouvée dans la demande de médecin, la validation pourrait échouer');
    }

    const newDoctor = new Doctor({
      userId: doctorRequest.userId._id,
      specialties: doctorRequest.specialties,
      medicalLicenseNumber: doctorRequest.medicalLicenseNumber,
      yearsOfExperience: doctorRequest.yearsOfExperience,
      education: educationMapped, // Utiliser les données mappées
      workingHours: doctorRequest.workingHours,
      consultationFee: doctorRequest.consultationFee,
      clinic: clinic, // Utiliser la version transformée avec GeoJSON
      languages: doctorRequest.languages,
      bio: doctorRequest.bio,
      documents: doctorRequest.documents,
      profilePhoto: doctorRequest.profilePhoto,
      verificationStatus: 'approved',
      verifiedAt: new Date(),
      verifiedBy: adminId,
      isActive: true
    });

    await newDoctor.save();
    console.log('✅ Nouveau médecin créé avec succès, ID:', newDoctor._id);

    // Mettre à jour le rôle de l'utilisateur et récupérer l'objet complet
    const user = await User.findById(doctorRequest.userId._id);
    if (!user) {
      console.error('Erreur critique: Utilisateur non trouvé pour la demande d\'approbation.');
      // Ne pas bloquer la réponse, mais logger l'erreur
    } else {
      user.role = 'doctor';
      await user.save();

      // Log de l'action admin
      console.log(`✅ Admin ${req.user.firstName} ${req.user.lastName} a approuvé la demande médecin de ${user.firstName} ${user.lastName}`);

      // Envoyer une notification push à l'utilisateur
      console.log(`Tentative d'envoi de notification à ${user.firstName} avec les tokens:`, user.fcmTokens);
      if (user.fcmTokens && user.fcmTokens.length > 0) {
        const title = 'Félicitations ! Votre demande a été approuvée.';
        const body = 'Vous pouvez maintenant vous connecter en tant que médecin et commencer à gérer vos rendez-vous.';
        sendPushNotification(user.fcmTokens, title, body)
          .then(() => console.log(`🚀 Notification d'approbation envoyée avec succès à ${user.firstName}`))
          .catch(err => console.error(`❌ Erreur lors de l'envoi de la notification d'approbation à ${user.firstName}:`, err));
      } else {
        console.log(`ℹ️ L'utilisateur ${user.firstName} n'a pas de token FCM enregistré. Notification non envoyée.`);
      }
    }

    res.json({
      success: true,
      message: 'Demande approuvée avec succès',
      data: {
        id: doctorRequest._id,
        status: 'approved',
        reviewedAt: doctorRequest.reviewedAt,
        reviewedBy: {
          id: req.user.id,
          name: `${req.user.firstName} ${req.user.lastName}`
        },
        doctorId: newDoctor._id // Ajout de l'ID du nouveau médecin créé
      }
    });

  } catch (error) {
    console.error('Erreur approbation demande:', error);
    res.status(500).json({
      error: 'Erreur lors de l\'approbation de la demande'
    });
  }
});

// @route   POST /api/admin/doctor-requests/:id/reject
// @desc    Rejeter une demande d'upgrade médecin
// @access  Private (Admin)
router.post('/doctor-requests/:id/reject', auth, adminCheck('admin'), [
  body('reason')
    .notEmpty()
    .isLength({ min: 10, max: 500 })
    .withMessage('La raison du rejet doit contenir entre 10 et 500 caractères'),
  body('notes')
    .optional()
    .isLength({ max: 500 })
    .withMessage('Les notes ne peuvent pas dépasser 500 caractères')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Données invalides',
        details: errors.array()
      });
    }

    const { id } = req.params;
    const { reason, notes } = req.body;
    const adminId = req.user.id;

    // Vérifier que la demande existe et est en attente
    const doctorRequest = await DoctorRequest.findById(id).populate('userId');
    if (!doctorRequest) {
      return res.status(404).json({
        error: 'Demande non trouvée'
      });
    }

    if (doctorRequest.status !== 'pending') {
      return res.status(400).json({
        error: 'Cette demande a déjà été traitée'
      });
    }

    // Rejeter la demande
    doctorRequest.status = 'rejected';
    doctorRequest.rejectionReason = reason;
    doctorRequest.reviewedAt = new Date();
    doctorRequest.reviewedBy = adminId;
    doctorRequest.adminNotes = notes || '';
    await doctorRequest.save();

    // Log de l'action admin
    const user = doctorRequest.userId;
    console.log(`❌ Admin ${req.user.firstName} ${req.user.lastName} a rejeté la demande médecin de ${user.firstName} ${user.lastName} - Raison: ${reason}`);

    // Envoyer une notification push à l'utilisateur
    if (user.fcmTokens && user.fcmTokens.length > 0) {
      const title = 'Mise à jour de votre demande de mise à niveau';
      const body = `Votre demande a été rejetée. Raison : ${reason}`;
      sendPushNotification(user.fcmTokens, title, body)
        .then(() => console.log(`🚀 Notification de rejet envoyée à ${user.firstName}`))
        .catch(err => console.error(`Erreur d'envoi de notification de rejet à ${user.firstName}:`, err));
    }

    res.json({
      success: true,
      message: 'Demande rejetée avec succès',
      data: {
        id: doctorRequest._id,
        status: 'rejected',
        reviewedAt: doctorRequest.reviewedAt,
        rejectionReason: reason,
        reviewedBy: {
          id: req.user.id,
          name: `${req.user.firstName} ${req.user.lastName}`
        }
      }
    });

  } catch (error) {
    console.error('Erreur rejet demande:', error);
    res.status(500).json({
      error: 'Erreur lors du rejet de la demande'
    });
  }
});

// @route   GET /api/admin/doctor-requests/stats
// @desc    Obtenir les statistiques des demandes d'upgrade
// @access  Private (Admin)
router.get('/doctor-requests/stats', auth, adminCheck('admin'), async (req, res) => {
  try {
    // Statistiques générales
    const totalRequests = await DoctorRequest.countDocuments();
    const pendingRequests = await DoctorRequest.countDocuments({ status: 'pending' });
    const approvedRequests = await DoctorRequest.countDocuments({ status: 'approved' });
    const rejectedRequests = await DoctorRequest.countDocuments({ status: 'rejected' });

    // Statistiques par période
    const today = new Date();
    const startOfDay = new Date(today.setHours(0, 0, 0, 0));
    const startOfWeek = new Date(today.setDate(today.getDate() - today.getDay()));
    const startOfMonth = new Date(today.getFullYear(), today.getMonth(), 1);

    const todayRequests = await DoctorRequest.countDocuments({
      requestedAt: { $gte: startOfDay }
    });

    const weekRequests = await DoctorRequest.countDocuments({
      requestedAt: { $gte: startOfWeek }
    });

    const monthRequests = await DoctorRequest.countDocuments({
      requestedAt: { $gte: startOfMonth }
    });

    // Statistiques par spécialité
    const specialtyStats = await DoctorRequest.aggregate([
      { $unwind: '$specialties' },
      {
        $group: {
          _id: '$specialties',
          count: { $sum: 1 },
          approved: {
            $sum: {
              $cond: [{ $eq: ['$status', 'approved'] }, 1, 0]
            }
          },
          pending: {
            $sum: {
              $cond: [{ $eq: ['$status', 'pending'] }, 1, 0]
            }
          }
        }
      },
      { $sort: { count: -1 } },
      { $limit: 10 }
    ]);

    // Tendances mensuelles (6 derniers mois)
    const sixMonthsAgo = new Date();
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);

    const monthlyTrends = await DoctorRequest.aggregate([
      {
        $match: {
          requestedAt: { $gte: sixMonthsAgo }
        }
      },
      {
        $group: {
          _id: {
            year: { $year: '$requestedAt' },
            month: { $month: '$requestedAt' }
          },
          total: { $sum: 1 },
          approved: {
            $sum: {
              $cond: [{ $eq: ['$status', 'approved'] }, 1, 0]
            }
          },
          rejected: {
            $sum: {
              $cond: [{ $eq: ['$status', 'rejected'] }, 1, 0]
            }
          }
        }
      },
      { $sort: { '_id.year': 1, '_id.month': 1 } }
    ]);

    res.json({
      success: true,
      data: {
        overview: {
          total: totalRequests,
          pending: pendingRequests,
          approved: approvedRequests,
          rejected: rejectedRequests,
          approvalRate: totalRequests > 0 ? ((approvedRequests / totalRequests) * 100).toFixed(1) : 0
        },
        period: {
          today: todayRequests,
          thisWeek: weekRequests,
          thisMonth: monthRequests
        },
        specialties: specialtyStats,
        trends: monthlyTrends
      }
    });

  } catch (error) {
    console.error('Erreur statistiques demandes:', error);
    res.status(500).json({
      error: 'Erreur lors de la récupération des statistiques'
    });
  }
});

// =============================================================================
// GESTION DES UTILISATEURS
// =============================================================================

// @route   GET /api/admin/users
// @desc    Obtenir la liste des utilisateurs avec filtres
// @access  Private (Admin)
router.get('/users', auth, adminCheck('admin'), [
  query('role')
    .optional()
    .isIn(['patient', 'doctor', 'admin'])
    .withMessage('Rôle invalide'),
  query('status')
    .optional()
    .isIn(['active', 'inactive'])
    .withMessage('Statut invalide'),
  query('search')
    .optional()
    .isLength({ min: 2 })
    .withMessage('La recherche doit contenir au moins 2 caractères'),
  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Page invalide'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limite invalide')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Paramètres invalides',
        details: errors.array()
      });
    }

    const { role, status, search, page = 1, limit = 20 } = req.query;
    const skip = (page - 1) * limit;

    // Construire le filtre
    let filter = {};
    
    if (role) {
      filter.role = role;
    }
    
    if (status) {
      filter.isActive = status === 'active';
    }
    
    if (search) {
      filter.$or = [
        { firstName: { $regex: search, $options: 'i' } },
        { lastName: { $regex: search, $options: 'i' } },
        { email: { $regex: search, $options: 'i' } },
        { phone: { $regex: search, $options: 'i' } }
      ];
    }

    // Récupérer les utilisateurs
    const users = await User.find(filter)
      .select('-password')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .lean();

    // Compter le total
    const total = await User.countDocuments(filter);

    // Pour les médecins, récupérer les informations supplémentaires
    const enrichedUsers = await Promise.all(users.map(async (user) => {
      let additionalInfo = {};
      
      if (user.role === 'doctor') {
        const doctorInfo = await Doctor.findOne({ userId: user._id })
          .select('specialties verificationStatus consultationFee')
          .lean();
        
        if (doctorInfo) {
          additionalInfo = {
            specialties: doctorInfo.specialties,
            verificationStatus: doctorInfo.verificationStatus,
            consultationFee: doctorInfo.consultationFee
          };
        }
        
        // Statistiques des rendez-vous
        const appointmentCount = await Appointment.countDocuments({ doctor: user._id });
        additionalInfo.totalAppointments = appointmentCount;
      } else if (user.role === 'patient') {
        // Statistiques des rendez-vous pour les patients
        const appointmentCount = await Appointment.countDocuments({ patient: user._id });
        additionalInfo.totalAppointments = appointmentCount;
      }
      
      return {
        ...user,
        ...additionalInfo
      };
    }));

    res.json({
      success: true,
      data: {
        users: enrichedUsers,
        pagination: {
          current: parseInt(page),
          total: Math.ceil(total / limit),
          count: enrichedUsers.length,
          totalUsers: total
        }
      }
    });

  } catch (error) {
    console.error('Erreur récupération utilisateurs:', error);
    res.status(500).json({
      error: 'Erreur lors de la récupération des utilisateurs'
    });
  }
});

// @route   GET /api/admin/users/:id
// @desc    Obtenir les détails d'un utilisateur spécifique
// @access  Private (Admin)
router.get('/users/:id', auth, adminCheck('admin'), async (req, res) => {
  try {
    const { id } = req.params;

    const user = await User.findById(id)
      .select('-password')
      .lean();

    if (!user) {
      return res.status(404).json({
        error: 'Utilisateur non trouvé'
      });
    }

    let additionalInfo = {};

    // Informations spécifiques selon le rôle
    if (user.role === 'doctor') {
      const doctorInfo = await Doctor.findOne({ userId: id }).lean();
      if (doctorInfo) {
        additionalInfo.doctorProfile = doctorInfo;
      }
      
      // Statistiques des rendez-vous
      const appointmentStats = await Appointment.aggregate([
        { $match: { doctor: user._id } },
        {
          $group: {
            _id: '$status',
            count: { $sum: 1 }
          }
        }
      ]);
      
      const totalAppointments = await Appointment.countDocuments({ doctor: user._id });
      additionalInfo.appointmentStats = {
        total: totalAppointments,
        byStatus: appointmentStats
      };
    } else if (user.role === 'patient') {
      // Historique des rendez-vous pour les patients
      const appointments = await Appointment.find({ patient: id })
        .populate('doctor', 'specialties')
        .select('appointmentDate status consultationType')
        .sort({ appointmentDate: -1 })
        .limit(10)
        .lean();
      
      additionalInfo.recentAppointments = appointments;
      additionalInfo.totalAppointments = await Appointment.countDocuments({ patient: id });
    }

    res.json({
      success: true,
      data: {
        ...user,
        ...additionalInfo
      }
    });

  } catch (error) {
    console.error('Erreur récupération détails utilisateur:', error);
    res.status(500).json({
      error: 'Erreur lors de la récupération des détails'
    });
  }
});

// @route   PUT /api/admin/users/:id/status
// @desc    Activer/Désactiver un utilisateur
// @access  Private (Admin)
router.put('/users/:id/status', auth, adminCheck('admin'), [
  body('isActive')
    .isBoolean()
    .withMessage('Le statut doit être un booléen'),
  body('reason')
    .optional()
    .isLength({ min: 5, max: 200 })
    .withMessage('La raison doit contenir entre 5 et 200 caractères')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Données invalides',
        details: errors.array()
      });
    }

    const { id } = req.params;
    const { isActive, reason } = req.body;

    // Vérifier que l'utilisateur existe
    const user = await User.findById(id);
    if (!user) {
      return res.status(404).json({
        error: 'Utilisateur non trouvé'
      });
    }

    // Empêcher la désactivation de son propre compte
    if (id === req.user.id) {
      return res.status(400).json({
        error: 'Vous ne pouvez pas modifier le statut de votre propre compte'
      });
    }

    // Mettre à jour le statut
    user.isActive = isActive;
    if (reason) {
      user.statusChangeReason = reason;
      user.statusChangedBy = req.user.id;
      user.statusChangedAt = new Date();
    }
    await user.save();

    // Si c'est un médecin, mettre à jour aussi son profil médecin
    if (user.role === 'doctor') {
      await Doctor.updateOne(
        { userId: id },
        { isActive: isActive }
      );
    }

    // Log de l'action
    const action = isActive ? 'activé' : 'désactivé';
    console.log(`🔄 Admin ${req.user.firstName} ${req.user.lastName} a ${action} l'utilisateur ${user.firstName} ${user.lastName}`);

    res.json({
      success: true,
      message: `Utilisateur ${action} avec succès`,
      data: {
        id: user._id,
        isActive: user.isActive,
        updatedAt: new Date()
      }
    });

  } catch (error) {
    console.error('Erreur modification statut utilisateur:', error);
    res.status(500).json({
      error: 'Erreur lors de la modification du statut'
    });
  }
});

// @route   DELETE /api/admin/users/:id
// @desc    Supprimer un utilisateur (soft delete)
// @access  Private (Admin)
router.delete('/users/:id', auth, adminCheck('admin'), [
  body('reason')
    .notEmpty()
    .isLength({ min: 10, max: 200 })
    .withMessage('La raison de suppression doit contenir entre 10 et 200 caractères')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Données invalides',
        details: errors.array()
      });
    }

    const { id } = req.params;
    const { reason } = req.body;

    // Vérifier que l'utilisateur existe
    const user = await User.findById(id);
    if (!user) {
      return res.status(404).json({
        error: 'Utilisateur non trouvé'
      });
    }

    // Empêcher la suppression de son propre compte
    if (id === req.user.id) {
      return res.status(400).json({
        error: 'Vous ne pouvez pas supprimer votre propre compte'
      });
    }

    // Empêcher la suppression d'autres admins
    if (user.role === 'admin') {
      return res.status(400).json({
        error: 'Vous ne pouvez pas supprimer un autre administrateur'
      });
    }

    // Soft delete - marquer comme supprimé
    user.isDeleted = true;
    user.deletedAt = new Date();
    user.deletedBy = req.user.id;
    user.deletionReason = reason;
    user.isActive = false;
    await user.save();

    // Si c'est un médecin, désactiver aussi son profil
    if (user.role === 'doctor') {
      await Doctor.updateOne(
        { userId: id },
        { 
          isActive: false,
          isDeleted: true,
          deletedAt: new Date()
        }
      );
    }

    // Annuler tous les rendez-vous futurs
    await Appointment.updateMany(
      {
        $or: [{ patient: id }, { doctor: id }],
        appointmentDate: { $gte: new Date() },
        status: { $in: ['pending', 'confirmed'] }
      },
      {
        status: 'cancelled',
        cancellationReason: 'Compte utilisateur supprimé',
        cancelledAt: new Date()
      }
    );

    // Log de l'action
    console.log(`🔒 Admin ${req.user.firstName} ${req.user.lastName} a désactivé l'utilisateur ${user.firstName} ${user.lastName} - Raison: ${reason}`);

    res.json({
      success: true,
      message: 'Utilisateur désactivé avec succès',
      data: {
        id: user._id,
        isActive: false,
        isDeleted: true,
        deletedAt: user.deletedAt
      }
    });

  } catch (error) {
    console.error('Erreur suppression utilisateur:', error);
    res.status(500).json({
      error: 'Erreur lors de la suppression'
    });
  }
});

// Supprimer définitivement un utilisateur (hard delete)
router.delete('/users/:id/permanent', auth, adminCheck('admin'), [
  param('id').isMongoId().withMessage('ID utilisateur invalide'),
  body('confirmation').isString().equals('SUPPRIMER DÉFINITIVEMENT')
    .withMessage('Texte de confirmation incorrect'),
  body('password').isString().notEmpty()
    .withMessage('Mot de passe administrateur requis'),
  body('reason').isString().notEmpty()
    .withMessage('Raison de la suppression requise')
], async (req, res) => {
  try {
    // Vérifier les erreurs de validation
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        success: false,
        error: errors.array()[0].msg 
      });
    }

    const { id } = req.params;
    const { confirmation, password, reason } = req.body;
    
    // Vérification supplémentaire du mot de passe administrateur
    const admin = await User.findById(req.user.id);
    const isPasswordValid = await admin.comparePassword(password);
    
    if (!isPasswordValid) {
      return res.status(403).json({
        success: false,
        error: 'Mot de passe administrateur incorrect'
      });
    }

    // Vérifier que l'utilisateur existe
    const user = await User.findById(id);
    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'Utilisateur non trouvé'
      });
    }

    // Empêcher la suppression d'administrateurs par des administrateurs
    if (user.role === 'admin' && req.user.role !== 'superadmin') {
      return res.status(403).json({
        success: false,
        error: 'Seul un super-administrateur peut supprimer un administrateur'
      });
    }

    // Supprimer définitivement les données personnelles tout en conservant les données médicales anonymisées
    if (user.role === 'patient') {
      // Récupérer l'ID du patient
      const patient = await Patient.findOne({ userId: id });
      
      if (patient) {
        // Anonymiser le patient
        await Patient.updateOne(
          { userId: id },
          {
            firstName: 'Anonymisé',
            lastName: 'Anonymisé',
            email: `anonyme-${Date.now()}@supprime.local`,
            phoneNumber: null,
            address: null,
            dateOfBirth: null,
            gender: 'non-spécifié',
            userId: null,
            isAnonymized: true,
            anonymizedAt: new Date(),
            anonymizedBy: req.user.id
          }
        );
        
        // Anonymiser les rendez-vous passés mais les conserver pour l'historique médical
        await Appointment.updateMany(
          {
            patient: patient._id,
            appointmentDate: { $lt: new Date() },
            status: 'completed'
          },
          {
            patientName: 'Patient anonymisé',
            patientContact: null,
            patientId: null,
            isAnonymized: true
          }
        );
        
        // Supprimer les rendez-vous futurs et annulés
        await Appointment.deleteMany({
          patient: patient._id,
          $or: [
            { appointmentDate: { $gte: new Date() } },
            { status: { $in: ['cancelled', 'pending', 'confirmed'] } }
          ]
        });
        
        // Anonymiser les dossiers médicaux mais les conserver
        await MedicalRecord.updateMany(
          { patientId: patient._id },
          {
            patientName: 'Patient anonymisé',
            isAnonymized: true,
            anonymizedAt: new Date()
          }
        );
      }
    } else if (user.role === 'doctor') {
      // Récupérer l'ID du médecin
      const doctor = await Doctor.findOne({ userId: id });
      
      if (doctor) {
        // Anonymiser les rendez-vous passés mais les conserver
        await Appointment.updateMany(
          {
            doctor: doctor._id,
            appointmentDate: { $lt: new Date() },
            status: 'completed'
          },
          {
            doctorName: 'Médecin anonymisé',
            doctorId: null,
            isAnonymized: true
          }
        );
        
        // Supprimer les rendez-vous futurs
        await Appointment.deleteMany({
          doctor: doctor._id,
          $or: [
            { appointmentDate: { $gte: new Date() } },
            { status: { $in: ['cancelled', 'pending', 'confirmed'] } }
          ]
        });
        
        // Supprimer définitivement le profil médecin
        await Doctor.deleteOne({ userId: id });
      }
    }
    
    // Supprimer les notifications
    await Notification.deleteMany({ userId: id });
    
    // Supprimer les tokens de rafraîchissement
    await RefreshToken.deleteMany({ userId: id });
    
    // Supprimer les tokens de réinitialisation de mot de passe
    await PasswordResetToken.deleteMany({ userId: id });
    
    // Enregistrer les logs de suppression définitive pour l'audit
    const deletionLog = new AuditLog({
      action: 'PERMANENT_DELETE_USER',
      entityType: 'User',
      entityId: id,
      description: `Suppression définitive de l'utilisateur ${user.firstName} ${user.lastName} (${user.email}) par l'administrateur ${req.user.firstName} ${req.user.lastName}`,
      metadata: {
        reason,
        userRole: user.role,
        userEmail: user.email
      },
      performedBy: req.user.id
    });
    await deletionLog.save();
    
    // Log de l'action dans la console
    console.log(`⚠️ SUPPRESSION PERMANENTE: Admin ${req.user.firstName} ${req.user.lastName} a supprimé définitivement l'utilisateur ${user.firstName} ${user.lastName} - Raison: ${reason}`);
    
    // Supprimer définitivement l'utilisateur
    await User.deleteOne({ _id: id });
    
    res.json({
      success: true,
      message: 'Utilisateur supprimé définitivement avec succès',
      data: {
        id: id,
        deletedAt: new Date()
      }
    });

  } catch (error) {
    console.error('Erreur suppression permanente utilisateur:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la suppression définitive'
    });
  }
});

module.exports = router;
