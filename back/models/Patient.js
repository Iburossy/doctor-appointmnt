const mongoose = require('mongoose');

const patientSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      index: true
    },
    firstName: {
      type: String,
      required: function() {
        // Requis sauf si anonymisé
        return !this.isAnonymized;
      }
    },
    lastName: {
      type: String,
      required: function() {
        // Requis sauf si anonymisé
        return !this.isAnonymized;
      }
    },
    email: {
      type: String,
      match: [/^\w+([.-]?\w+)*@\w+([.-]?\w+)*(\.\w{2,3})+$/, 'Veuillez fournir un email valide'],
      index: true
    },
    phoneNumber: {
      type: String
    },
    address: {
      street: String,
      city: String,
      postalCode: String,
      country: String
    },
    dateOfBirth: {
      type: Date
    },
    gender: {
      type: String,
      enum: ['male', 'female', 'other', 'non-spécifié']
    },
    bloodGroup: {
      type: String,
      enum: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Inconnu']
    },
    allergies: [String],
    chronicDiseases: [String],
    medications: [{
      name: String,
      dosage: String,
      frequency: String,
      startDate: Date,
      endDate: Date
    }],
    emergencyContact: {
      name: String,
      relationship: String,
      phoneNumber: String
    },
    isActive: {
      type: Boolean,
      default: true
    },
    isDeleted: {
      type: Boolean,
      default: false
    },
    isAnonymized: {
      type: Boolean,
      default: false
    },
    anonymizedAt: {
      type: Date
    },
    anonymizedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User'
    },
    deletedAt: {
      type: Date
    }
  },
  {
    timestamps: true
  }
);

// Indexation pour améliorer les performances des recherches
patientSchema.index({ isActive: 1 });
patientSchema.index({ isDeleted: 1 });
patientSchema.index({ isAnonymized: 1 });
patientSchema.index({ firstName: 1, lastName: 1 });

const Patient = mongoose.model('Patient', patientSchema);

module.exports = Patient;
