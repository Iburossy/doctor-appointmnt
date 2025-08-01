const mongoose = require('mongoose');

const doctorSchema = new mongoose.Schema({
  // Référence vers le User
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true
  },
  
  // Informations professionnelles
  medicalLicenseNumber: {
    type: String,
    required: [true, 'Le numéro d\'ordre est requis'],
    unique: true,
    trim: true
  },
  specialties: [{
    type: String,
    required: true,
    enum: [
      'Médecine générale',
      'Cardiologie',
      'Pédiatrie',
      'Gynécologie',
      'Dermatologie',
      'Ophtalmologie',
      'ORL',
      'Orthopédie',
      'Neurologie',
      'Psychiatrie',
      'Radiologie',
      'Anesthésie',
      'Chirurgie générale',
      'Urologie',
      'Pneumologie',
      'Gastro-entérologie',
      'Endocrinologie',
      'Rhumatologie',
      'Néphrologie',
      'Oncologie'
    ]
  }],
  yearsOfExperience: {
    type: Number,
    required: [true, 'Les années d\'expérience sont requises'],
    min: [1, 'Les années d\'expérience ne peuvent pas être inférieures à 1'],
    max: [50, 'Les années d\'expérience semblent trop élevées']
  },
  
  // Diplômes et certifications
  education: [{
    degree: {
      type: String,
      required: true
    },
    institution: {
      type: String,
      required: true
    },
    year: {
      type: Number,
      required: true
    },
    country: {
      type: String,
      default: 'Sénégal'
    }
  }],
  certifications: [{
    name: String,
    issuingOrganization: String,
    issueDate: Date,
    expiryDate: Date,
    documentUrl: String
  }],
  
  // Cabinet médical
  clinic: {
    name: {
      type: String,
      required: [true, 'Le nom du cabinet est requis']
    },
    address: {
      street: {
        type: String,
        required: [true, 'L\'adresse du cabinet est requise']
      },
      city: {
        type: String,
        required: [true, 'La ville est requise']
      },
      region: String,
      country: { type: String, default: 'Sénégal' },
      location: {
        type: { type: String, enum: ['Point'], default: 'Point' },
        coordinates: {
          // Format [longitude, latitude] - standard GeoJSON
          type: [Number],
          required: [true, 'Les coordonnées sont requises pour la géolocalisation']
        }
      }
    },
    phone: String,
    photos: [{
      filename: String,
      originalName: String,
      path: String,
      url: String,
      cloudinaryId: String,
      mimetype: String,
      size: Number,
      uploadedAt: Date
    }], // Photos du cabinet
    description: {
      type: String,
      maxlength: [500, 'La description ne peut pas dépasser 500 caractères']
    }
  },
  
  // Horaires de travail
  workingHours: {
    monday: {
      isWorking: { type: Boolean, default: false },
      startTime: { type: String, default: '08:00' },
      endTime: { type: String, default: '17:00' }
    },
    tuesday: {
      isWorking: { type: Boolean, default: false },
      startTime: { type: String, default: '08:00' },
      endTime: { type: String, default: '17:00' }
    },
    wednesday: {
      isWorking: { type: Boolean, default: false },
      startTime: { type: String, default: '08:00' },
      endTime: { type: String, default: '17:00' }
    },
    thursday: {
      isWorking: { type: Boolean, default: false },
      startTime: { type: String, default: '08:00' },
      endTime: { type: String, default: '17:00' }
    },
    friday: {
      isWorking: { type: Boolean, default: false },
      startTime: { type: String, default: '08:00' },
      endTime: { type: String, default: '17:00' }
    },
    saturday: {
      isWorking: { type: Boolean, default: false },
      startTime: { type: String, default: '08:00' },
      endTime: { type: String, default: '17:00' }
    },
    sunday: {
      isWorking: { type: Boolean, default: false },
      startTime: { type: String, default: '08:00' },
      endTime: { type: String, default: '17:00' }
    }
  },
  
  // Tarification
  consultationFee: {
    type: Number,
    required: [true, 'Le tarif de consultation est requis'],
    min: [0, 'Le tarif ne peut pas être négatif']
  },
  currency: {
    type: String,
    default: 'XOF' // Franc CFA
  },
  
  // Langues parlées
  languages: [{
    type: String,
    enum: ['Français', 'Wolof', 'Arabe', 'Anglais', 'Pulaar', 'Serer', 'Diola', 'Mandinka']
  }],
  
  // Statut de validation
  verificationStatus: {
    type: String,
    enum: ['pending', 'approved', 'rejected'],
    default: 'pending'
  },
  verificationDate: Date,
  verificationNotes: String,
  verifiedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  
  // Photo de profil
  profilePhoto: {
    filename: String,
    originalName: String,
    path: String,
    url: String,
    cloudinaryId: String,
    mimetype: String,
    size: Number,
    uploadedAt: Date
  },
  
  // Documents uploadés
  documents: {
    // Licence médicale
    medicalLicense: {
      filename: String,
      originalName: String,
      path: String,
      url: String,
      cloudinaryId: String,
      mimetype: String,
      size: Number,
      uploadedAt: Date
    },
    // Diplômes
    diplomas: [{
      filename: String,
      originalName: String,
      path: String,
      url: String,
      cloudinaryId: String,
      mimetype: String,
      size: Number,
      uploadedAt: Date
    }],
    // Certifications
    certifications: [{
      filename: String,
      originalName: String,
      path: String,
      url: String,
      cloudinaryId: String,
      mimetype: String,
      size: Number,
      uploadedAt: Date
    }]
  },
  
  // Statistiques et évaluations
  stats: {
    totalAppointments: { type: Number, default: 0 },
    completedAppointments: { type: Number, default: 0 },
    cancelledAppointments: { type: Number, default: 0 },
    averageRating: { type: Number, default: 0, min: 0, max: 5 },
    totalReviews: { type: Number, default: 0 }
  },
  
  // Disponibilité
  isAvailable: {
    type: Boolean,
    default: true
  },
  unavailableDates: [{
    date: Date,
    reason: String
  }],
  
  // Métadonnées
  isActive: {
    type: Boolean,
    default: true
  }
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Index pour la recherche géographique
doctorSchema.index({ "clinic.address.location": "2dsphere" });
doctorSchema.index({ specialties: 1 });
doctorSchema.index({ verificationStatus: 1 });
doctorSchema.index({ isActive: 1, isAvailable: 1 });

// Populate automatiquement les infos utilisateur
doctorSchema.pre(/^find/, function(next) {
  this.populate({
    path: 'userId',
    select: 'firstName lastName phone email profilePicture'
  });
  next();
});

// Virtual pour calculer la distance (sera utilisé dans les requêtes)
doctorSchema.virtual('distance');

module.exports = mongoose.model('Doctor', doctorSchema);
