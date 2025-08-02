const express = require('express');
const { body, validationResult, query } = require('express-validator');
const Appointment = require('../models/Appointment');
const Doctor = require('../models/Doctor');
const User = require('../models/User');
const smsService = require('../services/smsService');
const { authenticate, authorize, requireVerification } = require('../middleware/auth');

const router = express.Router();

// @route   POST /api/appointments
// @desc    Créer un nouveau rendez-vous
// @access  Private (Patient vérifié)
router.post('/', authenticate, requireVerification, [
  body('doctorId')
    .isMongoId()
    .withMessage('ID médecin invalide'),
  body('appointmentDate')
    .isISO8601()
    .withMessage('Date de rendez-vous invalide'),
  body('appointmentTime')
    .matches(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/)
    .withMessage('Heure de rendez-vous invalide (HH:MM)'),
  body('reason')
    .trim()
    .isLength({ min: 10, max: 500 })
    .withMessage('Le motif doit contenir entre 10 et 500 caractères'),
  body('consultationType')
    .optional()
    .isIn(['first_visit', 'follow_up', 'emergency', 'routine_checkup'])
    .withMessage('Type de consultation invalide')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Données invalides',
        details: errors.array()
      });
    }

    const {
      doctorId,
      appointmentDate,
      appointmentTime,
      reason,
      consultationType = 'first_visit',
      symptoms,
      patientNotes
    } = req.body;

    const patient = req.user;

    // Vérifier que le médecin existe et est disponible
    const doctor = await Doctor.findById(doctorId)
      .populate('userId', 'firstName lastName');

    if (!doctor) {
      return res.status(404).json({
        error: 'Médecin non trouvé'
      });
    }

    if (doctor.verificationStatus !== 'approved' || !doctor.isActive || !doctor.isAvailable) {
      return res.status(400).json({
        error: 'Ce médecin n\'est pas disponible actuellement'
      });
    }

    // Vérifier que la date/heure est dans le futur
    const appointmentDateTime = new Date(`${appointmentDate}T${appointmentTime}`);
    if (appointmentDateTime <= new Date()) {
      return res.status(400).json({
        error: 'La date et l\'heure du rendez-vous doivent être dans le futur'
      });
    }

    // Vérifier la disponibilité du créneau
    const existingAppointment = await Appointment.findOne({
      doctor: doctorId,
      appointmentDate: new Date(appointmentDate),
      appointmentTime,
      status: { $in: ['pending', 'confirmed'] }
    });

    if (existingAppointment) {
      return res.status(400).json({
        error: 'Ce créneau n\'est pas disponible'
      });
    }

    // Vérifier que le patient n'a pas déjà un RDV à la même heure
    const patientConflict = await Appointment.findOne({
      patient: patient._id,
      appointmentDate: new Date(appointmentDate),
      appointmentTime,
      status: { $in: ['pending', 'confirmed'] }
    });

    if (patientConflict) {
      return res.status(400).json({
        error: 'Vous avez déjà un rendez-vous à cette heure'
      });
    }

    // Créer le rendez-vous
    const appointment = new Appointment({
      patient: patient._id,
      doctor: doctorId,
      appointmentDate: new Date(appointmentDate),
      appointmentTime,
      reason,
      consultationType,
      symptoms: symptoms || [],
      patientNotes,
      payment: {
        amount: doctor.consultationFee,
        currency: doctor.currency || 'XOF'
      },
      createdBy: 'patient'
    });

    await appointment.save();

    // Envoyer les notifications SMS
    try {
      // SMS au patient
      const patientSMSDetails = {
        doctorName: `${doctor.userId.firstName} ${doctor.userId.lastName}`,
        date: new Date(appointmentDate).toLocaleDateString('fr-FR'),
        time: appointmentTime,
        clinicName: doctor.clinic.name,
        clinicAddress: doctor.clinic.address.street
      };

      await smsService.sendAppointmentConfirmation(patient.phone, patientSMSDetails);

      // SMS au médecin (si numéro disponible)
      if (doctor.clinic.phone || doctor.userId.phone) {
        const doctorPhone = doctor.clinic.phone || doctor.userId.phone;
        const doctorSMSDetails = {
          patientName: `${patient.firstName} ${patient.lastName}`,
          date: new Date(appointmentDate).toLocaleDateString('fr-FR'),
          time: appointmentTime,
          reason: reason.substring(0, 100) // Limiter la longueur
        };

        const doctorMessage = `Nouveau RDV: ${doctorSMSDetails.patientName} le ${doctorSMSDetails.date} à ${doctorSMSDetails.time}. Motif: ${doctorSMSDetails.reason}`;
        
        if (process.env.NODE_ENV === 'development') {
          console.log(`📱 [DEV MODE] SMS médecin pour ${doctorPhone}: ${doctorMessage}`);
        }
      }
    } catch (smsError) {
      console.error('Erreur envoi SMS:', smsError);
      // Ne pas bloquer la création du RDV si l'SMS échoue
    }

    // Populate les données pour la réponse
    await appointment.populate([
      {
        path: 'patient',
        select: 'firstName lastName phone'
      },
      {
        path: 'doctor',
        select: 'userId specialties clinic consultationFee',
        populate: {
          path: 'userId',
          select: 'firstName lastName'
        }
      }
    ]);

    res.status(201).json({
      message: 'Rendez-vous créé avec succès',
      appointment
    });

  } catch (error) {
    console.error('Erreur création rendez-vous:', error);
    res.status(500).json({
      error: 'Erreur lors de la création du rendez-vous'
    });
  }
});

// @route   GET /api/appointments/doctor/my-appointments
// @desc    Récupérer les rendez-vous pour le médecin connecté
// @access  Private (Médecin)
router.get('/doctor/my-appointments', authenticate, authorize('doctor'), async (req, res) => {
  try {
    // 1. Trouver le profil du médecin associé à l'utilisateur connecté
    const doctorProfile = await Doctor.findOne({ userId: req.user._id });

    if (!doctorProfile) {
      console.log(`Aucun profil médecin trouvé pour l'utilisateur : ${req.user._id}`);
      return res.status(404).json({ error: 'Profil médecin non trouvé.' });
    }

    // 2. Récupérer tous les rendez-vous pour ce médecin
    const appointments = await Appointment.find({ doctor: doctorProfile._id })
      .populate({
        path: 'patient',
        select: 'firstName lastName email phone profilePicture dateOfBirth gender' // Champs utiles pour l'affichage
      })
      .sort({ appointmentDate: -1, appointmentTime: -1 }); // Trier par date et heure décroissantes

    // 3. Envoyer la réponse
    res.json({
      message: `${appointments.length} rendez-vous récupérés avec succès.`,
      appointments
    });

  } catch (error) {
    console.error('Erreur lors de la récupération des rendez-vous du médecin:', error);
    res.status(500).json({ error: 'Erreur serveur lors de la récupération des rendez-vous.' });
  }
});

// @route   PUT /api/appointments/:id/status
// @desc    Mettre à jour le statut d'un rendez-vous (par le médecin)
// @access  Private (Médecin)
router.put('/:id/status', authenticate, authorize('doctor'), [
  body('status')
    .trim()
    .isIn(['confirmed', 'cancelled', 'completed', 'rejected', 'pending'])
    .withMessage('Le statut fourni est invalide.')
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ error: 'Données de statut invalides', details: errors.array() });
  }

  try {
    const { id } = req.params;
    const { status } = req.body;
    const doctorUserId = req.user._id;

    // 1. Trouver le profil du médecin pour obtenir son ID de document Doctor
    const doctorProfile = await Doctor.findOne({ userId: doctorUserId });
    if (!doctorProfile) {
      return res.status(403).json({ error: 'Profil médecin non trouvé pour cet utilisateur.' });
    }

    // 2. Trouver le rendez-vous et vérifier que le médecin est le bon
    const appointment = await Appointment.findById(id);
    if (!appointment) {
      return res.status(404).json({ error: 'Rendez-vous non trouvé.' });
    }

    // 3. Vérifier que le médecin connecté est bien celui du rendez-vous
    // On compare l'ID stocké dans le rdv (appointment.doctor._id) avec l'ID du profil du médecin connecté.
    if (appointment.doctor._id.toString() !== doctorProfile._id.toString()) {
      return res.status(403).json({ error: 'Action non autorisée. Vous n\'êtes pas le médecin pour ce rendez-vous.' });
    }

    // 4. Mettre à jour le statut
    appointment.status = status;

    // S'assurer que le tableau history existe avant de push
    if (!Array.isArray(appointment.history)) {
        appointment.history = [];
    }
    
    appointment.history.push({
      status,
      updatedBy: 'doctor',
      timestamp: new Date(),
      notes: `Statut mis à jour à '${status}' par le médecin.`
    });

    await appointment.save();

    // Si le statut est 'completed', mettre à jour les statistiques du médecin
    if (status === 'completed') {
      try {
        // On a déjà le doctorProfile de la vérification d'autorisation
        const doctor = doctorProfile;

        // Initialiser l'objet stats s'il n'existe pas
        if (!doctor.stats) {
          doctor.stats = {
            totalAppointments: 0,
            totalPatients: 0,
            monthlyIncome: 0,
            totalIncome: 0,
            averageRating: 0,
            totalReviews: 0,
          };
        }

        const appointmentAmount = appointment.payment && typeof appointment.payment.amount === 'number' ? appointment.payment.amount : 0;

        // Mise à jour des statistiques
        doctor.stats.totalAppointments = (doctor.stats.totalAppointments || 0) + 1;
        doctor.stats.totalIncome = (doctor.stats.totalIncome || 0) + appointmentAmount;

        // Gestion des revenus mensuels
        const currentMonth = new Date().toISOString().slice(0, 7); // YYYY-MM
        if (doctor.stats.monthlyIncome && typeof doctor.stats.monthlyIncome === 'object' && doctor.stats.monthlyIncome.month === currentMonth) {
          doctor.stats.monthlyIncome.amount = (doctor.stats.monthlyIncome.amount || 0) + appointmentAmount;
        } else {
          // Nouveau mois ou première fois
          doctor.stats.monthlyIncome = {
            month: currentMonth,
            amount: appointmentAmount
          };
        }

        // Vérifier si c'est un nouveau patient pour ce médecin
        const existingAppointmentsWithPatient = await Appointment.countDocuments({
          doctor: doctor._id,
          patient: appointment.patient,
          status: 'completed',
          _id: { $ne: appointment._id } // Exclure le rdv actuel
        });

        if (existingAppointmentsWithPatient === 0) {
          doctor.stats.totalPatients = (doctor.stats.totalPatients || 0) + 1;
        }
        
        await doctor.save();

      } catch (statsError) {
        console.error('Erreur lors de la mise à jour des statistiques du médecin:', statsError);
        // On ne bloque pas la réponse principale pour une erreur de stats
      }
    }

    // 5. Renvoyer le rendez-vous mis à jour (populé)
    await appointment.populate([
        { path: 'patient', select: 'firstName lastName phone' },
        { path: 'doctor', populate: { path: 'userId', select: 'firstName lastName' } }
    ]);

    res.json({ message: 'Statut du rendez-vous mis à jour avec succès.', appointment });

  } catch (error) {
    console.error('Erreur lors de la mise à jour du statut du rendez-vous:', error);
    res.status(500).json({ error: 'Erreur serveur lors de la mise à jour du statut.' });
  }
});

// @route   GET /api/appointments/:id
// @desc    Obtenir les détails d'un rendez-vous
// @access  Private
router.get('/:id', authenticate, async (req, res) => {
  try {
    const appointment = await Appointment.findById(req.params.id);

    if (!appointment) {
      return res.status(404).json({
        error: 'Rendez-vous non trouvé'
      });
    }

    // Vérifier que l'utilisateur a le droit de voir ce RDV
    const isPatient = appointment.patient.toString() === req.user._id.toString();
    const isDoctor = req.user.role === 'doctor' && 
      await Doctor.findOne({ userId: req.user._id, _id: appointment.doctor });
    const isAdmin = req.user.role === 'admin';

    if (!isPatient && !isDoctor && !isAdmin) {
      return res.status(403).json({
        error: 'Accès refusé'
      });
    }

    res.json({ appointment });

  } catch (error) {
    console.error('Erreur récupération rendez-vous:', error);
    res.status(500).json({
      error: 'Erreur lors de la récupération du rendez-vous'
    });
  }
});

// @route   PUT /api/appointments/:id/cancel
// @desc    Annuler un rendez-vous
// @access  Private
router.put('/:id/cancel', authenticate, [
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

    const appointment = await Appointment.findById(req.params.id);

    if (!appointment) {
      return res.status(404).json({
        error: 'Rendez-vous non trouvé'
      });
    }

    // Vérifier les permissions
    const isPatient = appointment.patient.toString() === req.user._id.toString();
    const isDoctor = req.user.role === 'doctor' && 
      await Doctor.findOne({ userId: req.user._id, _id: appointment.doctor });
    const isAdmin = req.user.role === 'admin';

    if (!isPatient && !isDoctor && !isAdmin) {
      return res.status(403).json({
        error: 'Accès refusé'
      });
    }

    // Vérifier que le RDV peut être annulé
    if (!['pending', 'confirmed'].includes(appointment.status)) {
      return res.status(400).json({
        error: 'Ce rendez-vous ne peut pas être annulé'
      });
    }

    // Vérifier le délai d'annulation (ex: 2h avant)
    const appointmentDateTime = new Date(`${appointment.appointmentDate.toISOString().split('T')[0]}T${appointment.appointmentTime}`);
    const twoHoursFromNow = new Date(Date.now() + 2 * 60 * 60 * 1000);

    if (appointmentDateTime <= twoHoursFromNow && req.user.role !== 'admin') {
      return res.status(400).json({
        error: 'Impossible d\'annuler un rendez-vous moins de 2 heures avant'
      });
    }

    // Annuler le rendez-vous
    appointment.status = 'cancelled';
    appointment.cancellation = {
      cancelledBy: req.user.role,
      cancelledAt: new Date(),
      reason: req.body.reason
    };

    await appointment.save();

    // Envoyer les notifications d'annulation
    try {
      const doctor = await Doctor.findById(appointment.doctor)
        .populate('userId', 'firstName lastName phone');
      
      const patient = await User.findById(appointment.patient);

      const appointmentDetails = {
        doctorName: `${doctor.userId.firstName} ${doctor.userId.lastName}`,
        date: appointment.appointmentDate.toLocaleDateString('fr-FR'),
        time: appointment.appointmentTime,
        reason: req.body.reason
      };

      // SMS au patient si annulé par le médecin
      if (req.user.role === 'doctor') {
        await smsService.sendAppointmentCancellation(patient.phone, appointmentDetails);
      }

      // SMS au médecin si annulé par le patient
      if (req.user.role === 'patient' && (doctor.clinic.phone || doctor.userId.phone)) {
        const doctorPhone = doctor.clinic.phone || doctor.userId.phone;
        const doctorCancelDetails = {
          patientName: `${patient.firstName} ${patient.lastName}`,
          date: appointment.appointmentDate.toLocaleDateString('fr-FR'),
          time: appointment.appointmentTime,
          reason: req.body.reason
        };

        const message = `RDV annulé: ${doctorCancelDetails.patientName} le ${doctorCancelDetails.date} à ${doctorCancelDetails.time}. ${doctorCancelDetails.reason ? `Motif: ${doctorCancelDetails.reason}` : ''}`;
        
        if (process.env.NODE_ENV === 'development') {
          console.log(`📱 [DEV MODE] Annulation SMS médecin: ${message}`);
        }
      }
    } catch (smsError) {
      console.error('Erreur envoi SMS annulation:', smsError);
    }

    res.json({
      message: 'Rendez-vous annulé avec succès',
      appointment
    });

  } catch (error) {
    console.error('Erreur annulation rendez-vous:', error);
    res.status(500).json({
      error: 'Erreur lors de l\'annulation du rendez-vous'
    });
  }
});

// @route   PUT /api/appointments/:id/confirm
// @desc    Confirmer un rendez-vous (médecin seulement)
// @access  Private (Doctor)
router.put('/:id/confirm', authenticate, authorize('doctor'), async (req, res) => {
  try {
    const appointment = await Appointment.findById(req.params.id);

    if (!appointment) {
      return res.status(404).json({
        error: 'Rendez-vous non trouvé'
      });
    }

    // Vérifier que c'est le bon médecin
    const doctor = await Doctor.findOne({ userId: req.user._id });
    if (!doctor || appointment.doctor.toString() !== doctor._id.toString()) {
      return res.status(403).json({
        error: 'Accès refusé'
      });
    }

    if (appointment.status !== 'pending') {
      return res.status(400).json({
        error: 'Ce rendez-vous ne peut pas être confirmé'
      });
    }

    appointment.status = 'confirmed';
    await appointment.save();

    res.json({
      message: 'Rendez-vous confirmé avec succès',
      appointment
    });

  } catch (error) {
    console.error('Erreur confirmation rendez-vous:', error);
    res.status(500).json({
      error: 'Erreur lors de la confirmation du rendez-vous'
    });
  }
});

// @route   PUT /api/appointments/:id/complete
// @desc    Marquer un rendez-vous comme terminé
// @access  Private (Doctor)
router.put('/:id/complete', authenticate, authorize('doctor'), [
  body('doctorNotes')
    .optional()
    .trim()
    .isLength({ max: 2000 })
    .withMessage('Les notes ne peuvent pas dépasser 2000 caractères'),
  body('diagnosis')
    .optional()
    .trim()
    .isLength({ max: 1000 })
    .withMessage('Le diagnostic ne peut pas dépasser 1000 caractères'),
  body('prescription')
    .optional()
    .isArray()
    .withMessage('La prescription doit être un tableau')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Données invalides',
        details: errors.array()
      });
    }

    const appointment = await Appointment.findById(req.params.id);

    if (!appointment) {
      return res.status(404).json({
        error: 'Rendez-vous non trouvé'
      });
    }

    // Vérifier que c'est le bon médecin
    const doctor = await Doctor.findOne({ userId: req.user._id });
    if (!doctor || appointment.doctor.toString() !== doctor._id.toString()) {
      return res.status(403).json({
        error: 'Accès refusé'
      });
    }

    if (appointment.status !== 'confirmed') {
      return res.status(400).json({
        error: 'Seuls les rendez-vous confirmés peuvent être marqués comme terminés'
      });
    }

    // Mettre à jour le rendez-vous
    appointment.status = 'completed';
    appointment.doctorNotes = req.body.doctorNotes;
    appointment.diagnosis = req.body.diagnosis;
    appointment.prescription = req.body.prescription || [];
    appointment.payment.status = 'paid'; // Assumé payé en espèces

    if (req.body.followUp) {
      appointment.followUp = req.body.followUp;
    }

    await appointment.save();

    res.json({
      message: 'Rendez-vous marqué comme terminé',
      appointment
    });

  } catch (error) {
    console.error('Erreur finalisation rendez-vous:', error);
    res.status(500).json({
      error: 'Erreur lors de la finalisation du rendez-vous'
    });
  }
});

// @route   POST /api/appointments/:id/review
// @desc    Ajouter une évaluation au rendez-vous
// @access  Private (Patient)
router.post('/:id/review', authenticate, [
  body('rating')
    .isInt({ min: 1, max: 5 })
    .withMessage('La note doit être entre 1 et 5'),
  body('comment')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage('Le commentaire ne peut pas dépasser 500 caractères')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Données invalides',
        details: errors.array()
      });
    }

    const appointment = await Appointment.findById(req.params.id);

    if (!appointment) {
      return res.status(404).json({
        error: 'Rendez-vous non trouvé'
      });
    }

    // Vérifier que c'est le bon patient
    if (appointment.patient.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        error: 'Accès refusé'
      });
    }

    if (appointment.status !== 'completed') {
      return res.status(400).json({
        error: 'Seuls les rendez-vous terminés peuvent être évalués'
      });
    }

    if (appointment.review && appointment.review.rating) {
      return res.status(400).json({
        error: 'Ce rendez-vous a déjà été évalué'
      });
    }

    // Ajouter l'évaluation
    appointment.review = {
      rating: req.body.rating,
      comment: req.body.comment,
      reviewDate: new Date()
    };

    await appointment.save();

    // Mettre à jour les statistiques du médecin
    const doctor = await Doctor.findById(appointment.doctor);
    if (doctor) {
      const allReviews = await Appointment.find({
        doctor: doctor._id,
        'review.rating': { $exists: true }
      }).select('review.rating');

      const totalReviews = allReviews.length;
      const averageRating = allReviews.reduce((sum, app) => sum + app.review.rating, 0) / totalReviews;

      doctor.stats.totalReviews = totalReviews;
      doctor.stats.averageRating = Math.round(averageRating * 10) / 10;

      await doctor.save();
    }

    res.json({
      message: 'Évaluation ajoutée avec succès',
      review: appointment.review
    });

  } catch (error) {
    console.error('Erreur ajout évaluation:', error);
    res.status(500).json({
      error: 'Erreur lors de l\'ajout de l\'évaluation'
    });
  }
});

// @route   GET /api/appointments/availability/:doctorId
// @desc    Obtenir les créneaux horaires déjà réservés pour un médecin à une date donnée
// @access  Private
router.get('/availability/:doctorId', authenticate, [
  query('date').isISO8601().withMessage('Format de date invalide (YYYY-MM-DD)')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Date invalide', details: errors.array() });
    }

    const { doctorId } = req.params;
    const { date } = req.query;

    const searchDate = new Date(date);
    const startDate = new Date(searchDate.setHours(0, 0, 0, 0));
    const endDate = new Date(searchDate.setHours(23, 59, 59, 999));

    const appointments = await Appointment.find({
      doctor: doctorId,
      appointmentDate: { $gte: startDate, $lt: endDate },
      status: { $in: ['pending', 'confirmed'] }
    });

    const bookedSlots = appointments.map(app => app.appointmentTime);

    res.json({ bookedSlots });

  } catch (error) {
    console.error('Erreur récupération disponibilités:', error);
    res.status(500).json({ error: 'Erreur lors de la récupération des disponibilités' });
  }
});

// @route   GET /api/appointments/doctor/me
// @desc    Obtenir les rendez-vous du médecin connecté
// @access  Private (Doctor)
router.get('/doctor/me', authenticate, authorize('doctor'), async (req, res) => {
  try {
    const { status, date, page = 1, limit = 20 } = req.query;

    const doctor = await Doctor.findOne({ userId: req.user._id });
    if (!doctor) {
      return res.status(404).json({
        error: 'Profil médecin non trouvé'
      });
    }

    let query = { doctor: doctor._id };

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

    const skip = (page - 1) * limit;

    const appointments = await Appointment.find(query)
      .sort({ appointmentDate: 1, appointmentTime: 1 })
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
    console.error('Erreur récupération rendez-vous médecin:', error);
    res.status(500).json({
      error: 'Erreur lors de la récupération des rendez-vous'
    });
  }
});

module.exports = router;
