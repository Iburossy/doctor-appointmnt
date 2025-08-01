const mongoose = require('mongoose');

const medicalRecordSchema = new mongoose.Schema(
  {
    patientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Patient',
      required: true,
      index: true
    },
    doctorId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Doctor',
      required: true,
      index: true
    },
    patientName: {
      type: String,
      required: true
    },
    doctorName: {
      type: String,
      required: true
    },
    consultationDate: {
      type: Date,
      required: true,
      default: Date.now
    },
    diagnosis: {
      type: String,
      required: true
    },
    symptoms: [String],
    treatment: {
      medications: [{
        name: String,
        dosage: String,
        frequency: String,
        duration: String,
        instructions: String
      }],
      procedures: [String],
      lifestyle: [String]
    },
    notes: String,
    followUpDate: Date,
    attachments: [{
      name: String,
      fileType: String,
      fileUrl: String,
      uploadDate: {
        type: Date,
        default: Date.now
      }
    }],
    isAnonymized: {
      type: Boolean,
      default: false
    },
    anonymizedAt: {
      type: Date
    },
    accessHistory: [{
      userId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
      },
      accessDate: {
        type: Date,
        default: Date.now
      },
      action: {
        type: String,
        enum: ['view', 'edit', 'print', 'share', 'delete']
      },
      ipAddress: String
    }]
  },
  {
    timestamps: true
  }
);

// Indexation pour améliorer les performances des recherches
medicalRecordSchema.index({ consultationDate: -1 });
medicalRecordSchema.index({ 'treatment.medications.name': 1 });
medicalRecordSchema.index({ isAnonymized: 1 });
medicalRecordSchema.index({ diagnosis: 'text' });

const MedicalRecord = mongoose.model('MedicalRecord', medicalRecordSchema);

module.exports = MedicalRecord;
