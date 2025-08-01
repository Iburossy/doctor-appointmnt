const mongoose = require('mongoose');

/**
 * Modèle pour les logs d'audit des actions importantes
 * Utilisé pour tracer les opérations critiques comme les suppressions permanentes
 * et autres actions importantes pour des raisons légales et de sécurité
 */
const auditLogSchema = new mongoose.Schema(
  {
    action: {
      type: String,
      required: true,
      enum: [
        'PERMANENT_DELETE_USER',
        'ADMIN_CREATION',
        'ROLE_CHANGE',
        'MEDICAL_RECORD_ACCESS',
        'MEDICAL_RECORD_DELETION',
        'CONFIG_CHANGE',
        'PAYMENT_INFO_ACCESS',
        'LOGIN_ATTEMPT_FAILURE',
        'PATIENT_DATA_EXPORT',
        'DOCTOR_VERIFICATION_STATUS_CHANGE'
      ]
    },
    entityType: {
      type: String,
      required: true,
      enum: ['User', 'Patient', 'Doctor', 'MedicalRecord', 'Appointment', 'System', 'Payment']
    },
    entityId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true
    },
    description: {
      type: String,
      required: true
    },
    metadata: {
      type: Object,
      default: {}
    },
    performedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    },
    ipAddress: String,
    userAgent: String
  },
  {
    timestamps: true
  }
);

// Indexation pour améliorer les performances des recherches
auditLogSchema.index({ action: 1 });
auditLogSchema.index({ entityType: 1, entityId: 1 });
auditLogSchema.index({ performedBy: 1 });
auditLogSchema.index({ createdAt: 1 });

// Conservation des logs pour au moins 2 ans (RGPD et obligations légales)
auditLogSchema.index({ createdAt: 1 }, { expireAfterSeconds: 63072000 }); // 2 ans en secondes

const AuditLog = mongoose.model('AuditLog', auditLogSchema);

module.exports = AuditLog;
