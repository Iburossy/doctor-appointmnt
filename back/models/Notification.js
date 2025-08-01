const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true
    },
    title: {
      type: String,
      required: true
    },
    message: {
      type: String,
      required: true
    },
    type: {
      type: String,
      enum: ['appointment', 'message', 'system', 'payment', 'reminder', 'profile'],
      required: true
    },
    relatedId: {
      type: mongoose.Schema.Types.ObjectId,
      refPath: 'relatedModel'
    },
    relatedModel: {
      type: String,
      enum: ['Appointment', 'Message', 'Payment', 'User', 'Doctor']
    },
    isRead: {
      type: Boolean,
      default: false
    },
    readAt: {
      type: Date
    },
    metadata: {
      type: Object,
      default: {}
    },
    expiresAt: {
      type: Date
    }
  },
  {
    timestamps: true
  }
);

// Indexation pour améliorer les performances des recherches
notificationSchema.index({ isRead: 1 });
notificationSchema.index({ type: 1 });
notificationSchema.index({ createdAt: -1 });

// TTL index pour supprimer automatiquement les notifications après 30 jours
notificationSchema.index({ createdAt: 1 }, { expireAfterSeconds: 2592000 }); // 30 jours en secondes

// Créer un TTL index basé sur le champ expiresAt si présent
notificationSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

const Notification = mongoose.model('Notification', notificationSchema);

module.exports = Notification;
