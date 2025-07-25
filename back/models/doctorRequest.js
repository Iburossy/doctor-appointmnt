const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const FileSchema = new Schema({
  filename: { type: String },
  originalName: { type: String },
  url: { type: String },
  cloudinaryId: { type: String },
  mimetype: { type: String },
  size: { type: Number },
  uploadedAt: { type: Date, default: Date.now }
});

const DocumentsSchema = new Schema({
  medicalLicense: { type: FileSchema },
  diplomas: [FileSchema],
  certifications: [FileSchema]
});

/**
 * Modèle pour les demandes d'upgrade patient→médecin
 * Ces demandes sont stockées séparément des médecins validés
 */
const DoctorRequestSchema = new Schema({
  userId: {
    type: Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  // Informations professionnelles
  specialties: [{
    type: String,
    required: true
  }],
  yearsOfExperience: {
    type: Number,
    required: true,
    min: 0
  },
  medicalLicenseNumber: {
    type: String,
    required: true
  },
  education: [{
    institution: { type: String },
    degree: { type: String },
    field: { type: String },
    graduationYear: { type: Number }
  }],
  
  // Informations pour les consultations
  consultationFee: {
    type: Number
  },
  currency: {
    type: String,
    default: 'XOF'
  },
  
  // Informations du cabinet
  clinic: {
    name: { type: String },
    address: {
      street: { type: String, required: true },
      city: { type: String, required: true },
      region: { type: String },
      country: { type: String, default: 'Sénégal' },
      coordinates: {
        latitude: { type: Number, required: true },
        longitude: { type: Number, required: true }
      }
    },
    phone: { type: String },
    description: { type: String },
    photos: [FileSchema]
  },
  
  // Informations personnelles
  languages: [{ type: String }],
  bio: { type: String },
  
  // Documents uploadés
  documents: {
    type: DocumentsSchema,
    default: {
      diplomas: [],
      certifications: []
    }
  },
  profilePhoto: { type: FileSchema },
  
  // Statut de vérification
  status: {
    type: String,
    enum: ['pending', 'approved', 'rejected'],
    default: 'pending'
  },
  rejectionReason: { type: String },
  adminNotes: { type: String },
  
  // Suivi administratif
  requestedAt: { type: Date, default: Date.now },
  reviewedAt: { type: Date },
  reviewedBy: {
    type: Schema.Types.ObjectId,
    ref: 'User'
  }
}, {
  timestamps: true
});

// Indexation pour les recherches fréquentes
DoctorRequestSchema.index({ userId: 1 });
DoctorRequestSchema.index({ status: 1 });
DoctorRequestSchema.index({ 'specialties': 1 });

// Vérifier si le modèle existe déjà avant de le créer
module.exports = mongoose.models.DoctorRequest || mongoose.model('DoctorRequest', DoctorRequestSchema);
