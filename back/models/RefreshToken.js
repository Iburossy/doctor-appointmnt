const mongoose = require('mongoose');

const refreshTokenSchema = new mongoose.Schema(
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
    isRevoked: {
      type: Boolean,
      default: false
    },
    revokedAt: {
      type: Date
    },
    deviceInfo: {
      deviceId: String,
      deviceType: String,
      browser: String,
      os: String,
      ipAddress: String,
      userAgent: String
    },
    lastUsedAt: {
      type: Date
    }
  },
  {
    timestamps: true
  }
);

// Indexation pour améliorer les performances des recherches
refreshTokenSchema.index({ token: 1 });
refreshTokenSchema.index({ isRevoked: 1 });

// TTL index pour supprimer automatiquement les tokens expirés
refreshTokenSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

const RefreshToken = mongoose.model('RefreshToken', refreshTokenSchema);

module.exports = RefreshToken;
