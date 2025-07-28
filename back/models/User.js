const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  // Informations de base
  firstName: {
    type: String,
    required: [true, 'Le prénom est requis'],
    trim: true,
    maxlength: [50, 'Le prénom ne peut pas dépasser 50 caractères']
  },
  lastName: {
    type: String,
    required: [true, 'Le nom est requis'],
    trim: true,
    maxlength: [50, 'Le nom ne peut pas dépasser 50 caractères']
  },
  phone: {
    type: String,
    required: [true, 'Le numéro de téléphone est requis'],
    unique: true,
    match: [/^\+221[0-9]{8,9}$/, 'Format de téléphone sénégalais invalide (+221xxxxxxxx)']
  },
  email: {
    type: String,
    lowercase: true,
    trim: true,
    match: [/^\w+([.-]?\w+)*@\w+([.-]?\w+)*(\.\w{2,3})+$/, 'Email invalide']
  },
  password: {
    type: String,
    required: [true, 'Le mot de passe est requis'],
    minlength: [6, 'Le mot de passe doit contenir au moins 6 caractères']
  },
  
  // Rôle et statut
  role: {
    type: String,
    enum: ['patient', 'doctor', 'admin'],
    default: 'patient'
  },
  isActive: {
    type: Boolean,
    default: true
  },
  isPhoneVerified: {
    type: Boolean,
    default: false
  },
  isEmailVerified: {
    type: Boolean,
    default: false
  },
  
  // Informations personnelles
  dateOfBirth: Date,
  gender: {
    type: String,
    enum: ['male', 'female', 'other']
  },
  profilePicture: String,
  address: {
    street: String,
    city: String,
    region: String,
    country: { type: String, default: 'Sénégal' },
    coordinates: {
      latitude: Number,
      longitude: Number
    }
  },
  
  // Codes de vérification
  phoneVerificationCode: String,
  phoneVerificationExpires: Date,
  emailVerificationCode: String,
  emailVerificationExpires: Date,
  passwordResetCode: String,
  passwordResetExpires: Date,
  
  // Préférences
  language: {
    type: String,
    enum: ['fr', 'wo', 'ar'],
    default: 'fr'
  },
  notifications: {
    sms: { type: Boolean, default: true },
    email: { type: Boolean, default: true },
    push: { type: Boolean, default: true }
  },
  
  // Métadonnées
  lastLogin: Date,
  deviceInfo: {
    deviceId: String,
    platform: String,
    version: String
  },
  fcmTokens: [{ type: String }]
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Index pour la recherche géographique
userSchema.index({ "address.coordinates": "2dsphere" });

// Virtual pour le nom complet
userSchema.virtual('fullName').get(function() {
  return `${this.firstName} ${this.lastName}`;
});

// Hash password avant sauvegarde
userSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  
  try {
    const salt = await bcrypt.genSalt(12);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (error) {
    next(error);
  }
});

// Méthode pour comparer les mots de passe
userSchema.methods.comparePassword = async function(candidatePassword) {
  return await bcrypt.compare(candidatePassword, this.password);
};

// Méthode pour générer un code de vérification
userSchema.methods.generateVerificationCode = function() {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

// Ne pas retourner le mot de passe dans les réponses JSON
userSchema.methods.toJSON = function() {
  const userObject = this.toObject();
  delete userObject.password;
  delete userObject.phoneVerificationCode;
  delete userObject.emailVerificationCode;
  delete userObject.passwordResetCode;
  return userObject;
};

module.exports = mongoose.model('User', userSchema);
