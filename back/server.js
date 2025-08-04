const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const app = express();

// Security middleware
// Configuration de Helmet pour autoriser le chargement des ressources cross-origin (images, etc.)
app.use(helmet({ crossOriginResourcePolicy: { policy: "cross-origin" } }));
// Configuration CORS avec origines autorisées depuis les variables d'environnement
const whitelist = (process.env.CORS_ALLOWED_ORIGINS || 'http://localhost:3000').split(',').filter(Boolean);

// Pour Flutter qui n'a pas forcément d'origine - permettre null (requis pour les apps mobiles)
whitelist.push(null);

// Ajouter des domaines de production si nécessaire
if (process.env.NODE_ENV === 'production' && process.env.CORS_PRODUCTION_ORIGINS) {
  const productionOrigins = process.env.CORS_PRODUCTION_ORIGINS.split(',').filter(Boolean);
  whitelist.push(...productionOrigins);
}

console.log('🌐 CORS autorisé pour:', whitelist.filter(origin => origin !== null));

const corsOptions = {
  origin: function (origin, callback) {
    // `!origin` est utilisé pour autoriser les requêtes sans origine (ex: Postman, apps mobiles)
    if (whitelist.indexOf(origin) !== -1 || !origin) {
      const logMessage = origin ? `Autorisation de l'origine ${origin}` : "Autorisation pour une requête sans origine (ex: app mobile)";
      console.log(`CORS: ${logMessage}`);
      callback(null, true);
    } else {
      console.error(`CORS: Blocage de l'origine ${origin}`);
      callback(new Error('Non autorisé par CORS'));
    }
  },
  credentials: true,
};

app.use(cors(corsOptions));

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100,
  message: {
    error: 'Trop de requêtes, veuillez réessayer plus tard.'
  }
});
app.use('/api/', limiter);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Static files
app.use('/uploads', express.static('uploads'));

// Database connection
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/doctors_app', {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
.then(() => console.log('✅ Connexion MongoDB réussie'))
.catch(err => console.error('❌ Erreur connexion MongoDB:', err));

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/users', require('./routes/user.routes'));
app.use('/api/doctors', require('./routes/doctors'));
app.use('/api/appointments', require('./routes/appointments'));
app.use('/api/admin', require('./routes/admin'));
app.use('/api/upload', require('./routes/upload'));

// Health check
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'Doctors App API is running',
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ 
    error: 'Route non trouvée',
    path: req.originalUrl 
  });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error('❌ Erreur serveur:', err);
  
  if (err.name === 'ValidationError') {
    return res.status(400).json({
      error: 'Données invalides',
      details: Object.values(err.errors).map(e => e.message)
    });
  }
  
  if (err.name === 'CastError') {
    return res.status(400).json({
      error: 'ID invalide'
    });
  }
  
  res.status(500).json({
    error: 'Erreur interne du serveur',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Une erreur est survenue'
  });
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Serveur démarré sur le port ${PORT}`);
  console.log(`📱 API disponible sur http://localhost:${PORT}/api`);
  console.log(`📱 API disponible sur http://192.168.1.124:${PORT}/api (pour téléphone physique)`);
  console.log(`🏥 Environment: ${process.env.NODE_ENV || 'development'}`);
});
