const mongoose = require('mongoose');

const appointmentSchema = new mongoose.Schema({
  // Participants
  patient: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: [true, 'Le patient est requis']
  },
  doctor: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Doctor',
    required: [true, 'Le médecin est requis']
  },
  
  // Date et heure
  appointmentDate: {
    type: Date,
    required: [true, 'La date du rendez-vous est requise']
  },
  appointmentTime: {
    type: String,
    required: [true, 'L\'heure du rendez-vous est requise'],
    match: [/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/, 'Format d\'heure invalide (HH:MM)']
  },
  duration: {
    type: Number,
    default: 30, // minutes
    min: [15, 'La durée minimale est de 15 minutes'],
    max: [120, 'La durée maximale est de 2 heures']
  },
  
  // Statut du rendez-vous
  status: {
    type: String,
    enum: ['pending', 'confirmed', 'completed', 'cancelled', 'no_show'],
    default: 'pending'
  },
  
  // Type de consultation
  consultationType: {
    type: String,
    enum: ['first_visit', 'follow_up', 'emergency', 'routine_checkup'],
    default: 'first_visit'
  },
  
  // Motif de la consultation
  reason: {
    type: String,
    required: [true, 'Le motif de consultation est requis'],
    maxlength: [500, 'Le motif ne peut pas dépasser 500 caractères']
  },
  
  // Symptômes (optionnel)
  symptoms: [{
    type: String,
    maxlength: [100, 'Chaque symptôme ne peut pas dépasser 100 caractères']
  }],
  
  // Notes du patient
  patientNotes: {
    type: String,
    maxlength: [1000, 'Les notes ne peuvent pas dépasser 1000 caractères']
  },
  
  // Notes du médecin (après consultation)
  doctorNotes: {
    type: String,
    maxlength: [2000, 'Les notes du médecin ne peuvent pas dépasser 2000 caractères']
  },
  
  // Diagnostic (après consultation)
  diagnosis: {
    type: String,
    maxlength: [1000, 'Le diagnostic ne peut pas dépasser 1000 caractères']
  },
  
  // Prescription (après consultation)
  prescription: [{
    medication: {
      type: String,
      required: true
    },
    dosage: {
      type: String,
      required: true
    },
    frequency: {
      type: String,
      required: true
    },
    duration: {
      type: String,
      required: true
    },
    instructions: String
  }],
  
  // Informations de paiement
  payment: {
    amount: {
      type: Number,
      required: [true, 'Le montant est requis']
    },
    currency: {
      type: String,
      default: 'XOF'
    },
    method: {
      type: String,
      enum: ['cash', 'wave', 'orange_money', 'bank_transfer', 'insurance'],
      default: 'cash'
    },
    status: {
      type: String,
      enum: ['pending', 'paid', 'failed', 'refunded'],
      default: 'pending'
    },
    transactionId: String,
    paidAt: Date
  },
  
  // Rappels et notifications
  reminders: {
    patient: {
      sent: { type: Boolean, default: false },
      sentAt: Date
    },
    doctor: {
      sent: { type: Boolean, default: false },
      sentAt: Date
    }
  },
  
  // Annulation
  cancellation: {
    cancelledBy: {
      type: String,
      enum: ['patient', 'doctor', 'admin']
    },
    cancelledAt: Date,
    reason: String,
    refundStatus: {
      type: String,
      enum: ['not_applicable', 'pending', 'processed', 'failed'],
      default: 'not_applicable'
    }
  },
  
  // Évaluation (après consultation)
  review: {
    rating: {
      type: Number,
      min: [1, 'La note minimale est 1'],
      max: [5, 'La note maximale est 5']
    },
    comment: {
      type: String,
      maxlength: [500, 'Le commentaire ne peut pas dépasser 500 caractères']
    },
    reviewDate: Date
  },
  
  // Suivi
  followUp: {
    required: { type: Boolean, default: false },
    scheduledDate: Date,
    notes: String
  },
  
  // Métadonnées
  createdBy: {
    type: String,
    enum: ['patient', 'doctor', 'admin'],
    default: 'patient'
  },
  source: {
    type: String,
    enum: ['mobile_app', 'web_app', 'phone_call', 'walk_in'],
    default: 'mobile_app'
  }
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Index pour optimiser les requêtes
appointmentSchema.index({ patient: 1, appointmentDate: -1 });
appointmentSchema.index({ doctor: 1, appointmentDate: 1 });
appointmentSchema.index({ status: 1 });
appointmentSchema.index({ appointmentDate: 1, appointmentTime: 1 });

// Index composé pour éviter les doublons
appointmentSchema.index({ 
  doctor: 1, 
  appointmentDate: 1, 
  appointmentTime: 1 
}, { 
  unique: true,
  partialFilterExpression: { 
    status: { $in: ['pending', 'confirmed'] } 
  }
});

// Virtual pour la date/heure complète
appointmentSchema.virtual('fullDateTime').get(function() {
  if (this.appointmentDate && this.appointmentTime) {
    const [hours, minutes] = this.appointmentTime.split(':');
    const dateTime = new Date(this.appointmentDate);
    dateTime.setHours(parseInt(hours), parseInt(minutes), 0, 0);
    return dateTime;
  }
  return null;
});

// Virtual pour vérifier si le RDV est passé
appointmentSchema.virtual('isPast').get(function() {
  if (this.fullDateTime) {
    return this.fullDateTime < new Date();
  }
  return false;
});

// Populate automatiquement les références
appointmentSchema.pre(/^find/, function(next) {
  this.populate({
    path: 'patient',
    select: 'firstName lastName phone profilePicture'
  }).populate({
    path: 'doctor',
    select: 'userId specialties clinic.name consultationFee',
    populate: {
      path: 'userId',
      select: 'firstName lastName profilePicture'
    }
  });
  next();
});

// Middleware pour mettre à jour les stats du médecin
appointmentSchema.post('save', async function() {
  if (this.status === 'completed') {
    const Doctor = mongoose.model('Doctor');
    await Doctor.findByIdAndUpdate(this.doctor, {
      $inc: { 'stats.completedAppointments': 1 }
    });
  }
});

module.exports = mongoose.model('Appointment', appointmentSchema);
