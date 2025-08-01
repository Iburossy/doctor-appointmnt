const mongoose = require('mongoose');

const passwordResetTokenSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true
    },
    token: {
      type: String,
      required: true,
      unique: true
    },
    expiresAt: {
      type: Date,
      required: true,
      index: true
    },
    isUsed: {
      type: Boolean,
      default: false
    },
    usedAt: {
      type: Date
    },
    ipRequest: {
      type: String
    },
    ipUsed: {
      type: String
    }
  },
  {
    timestamps: true
  }
);

// Indexation pour améliorer les performances des recherches
passwordResetTokenSchema.index({ token: 1 });
passwordResetTokenSchema.index({ isUsed: 1 });

// TTL index pour supprimer automatiquement les tokens expirés (après 24h)
passwordResetTokenSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

const PasswordResetToken = mongoose.model('PasswordResetToken', passwordResetTokenSchema);

module.exports = PasswordResetToken;
