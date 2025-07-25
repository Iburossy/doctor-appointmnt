const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Créer le dossier uploads s'il n'existe pas
const uploadDir = path.join(__dirname, '..', 'uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
  console.log('📁 Dossier uploads créé:', uploadDir);
}

// Configuration du stockage
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    console.log('📂 Destination appelée pour le fichier:', file.originalname);
    console.log('📂 Dossier de destination:', uploadDir);
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    // Générer un nom de fichier unique
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const extension = path.extname(file.originalname);
    const filename = file.fieldname + '-' + uniqueSuffix + extension;
    
    console.log('📝 Nom de fichier généré:', filename);
    console.log('📝 Fichier original:', file.originalname);
    console.log('📝 Type MIME:', file.mimetype);
    
    cb(null, filename);
  }
});

// Filtre pour les types de fichiers autorisés
const fileFilter = (req, file, cb) => {
  console.log('🔍 Vérification du type de fichier:', file.mimetype);
  console.log('🔍 Nom du champ:', file.fieldname);
  
  // Types de fichiers autorisés
  const allowedTypes = [
    'image/jpeg',
    'image/jpg', 
    'image/png',
    'image/gif',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ];
  
  if (allowedTypes.includes(file.mimetype)) {
    console.log('✅ Type de fichier autorisé');
    cb(null, true);
  } else {
    console.log('❌ Type de fichier non autorisé:', file.mimetype);
    cb(new Error(`Type de fichier non autorisé: ${file.mimetype}`), false);
  }
};

// Configuration multer
const upload = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB max
    files: 10 // Maximum 10 fichiers
  }
});

// Middleware avec logs détaillés
const uploadWithLogs = (fieldConfigs) => {
  return (req, res, next) => {
    console.log('\n🚀 === DÉBUT UPLOAD MIDDLEWARE ===');
    console.log('📨 Méthode:', req.method);
    console.log('📨 URL:', req.url);
    console.log('📨 Content-Type:', req.headers['content-type']);
    console.log('📨 Content-Length:', req.headers['content-length']);
    console.log('📨 User-Agent:', req.headers['user-agent']);
    
    // Log des champs attendus
    console.log('📋 Champs de fichiers attendus:', fieldConfigs);
    
    const multerUpload = upload.fields(fieldConfigs);
    
    multerUpload(req, res, (err) => {
      if (err) {
        console.error('❌ Erreur multer:', err.message);
        console.error('❌ Stack:', err.stack);
        return res.status(400).json({
          success: false,
          error: 'Erreur lors du téléchargement des fichiers',
          details: err.message
        });
      }
      
      console.log('📁 Fichiers reçus:', req.files ? Object.keys(req.files) : 'Aucun');
      
      if (req.files) {
        Object.keys(req.files).forEach(fieldName => {
          console.log(`📄 Champ "${fieldName}":`, req.files[fieldName].length, 'fichier(s)');
          req.files[fieldName].forEach((file, index) => {
            console.log(`  - Fichier ${index + 1}:`, {
              originalname: file.originalname,
              filename: file.filename,
              mimetype: file.mimetype,
              size: file.size,
              path: file.path
            });
          });
        });
      }
      
      console.log('📝 Corps de la requête (sans fichiers):', JSON.stringify(req.body, null, 2));
      console.log('🏁 === FIN UPLOAD MIDDLEWARE ===\n');
      
      next();
    });
  };
};

module.exports = {
  upload,
  uploadWithLogs
};
