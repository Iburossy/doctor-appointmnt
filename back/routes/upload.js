const express = require('express');
const multer = require('multer');
const Doctor = require('../models/Doctor');
const { authenticate } = require('../middleware/auth');
const { uploadToCloudinary } = require('../services/cloudinary');

const router = express.Router();

// Configuration multer pour stocker en mémoire (pour Cloudinary)
const storage = multer.memoryStorage();
const upload = multer({
  storage: storage,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB max
  },
  fileFilter: (req, file, cb) => {
    console.log('🔍 Vérification du fichier:', {
      fieldname: file.fieldname,
      originalname: file.originalname,
      mimetype: file.mimetype
    });
    
    // Types de fichiers autorisés
    const allowedTypes = [
      'image/jpeg',
      'image/jpg', 
      'image/png',
      'image/gif',
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/octet-stream' // Ajout pour supporter les uploads depuis Flutter
    ];
    
    if (allowedTypes.includes(file.mimetype)) {
      console.log('✅ Type de fichier autorisé');
      cb(null, true);
    } else {
      console.log('❌ Type de fichier non autorisé:', file.mimetype);
      cb(new Error(`Type de fichier non autorisé: ${file.mimetype}`), false);
    }
  }
});

// @route   POST /api/upload/doctor/:doctorId/documents
// @desc    Upload des documents pour un médecin
// @access  Private
router.post('/doctor/:doctorId/documents', authenticate, upload.single('file'), async (req, res) => {
  try {
    console.log('\n🚀 === DÉBUT UPLOAD DOCUMENT ===');
    console.log('👤 User ID:', req.user._id);
    console.log('🏥 Doctor ID:', req.params.doctorId);
    console.log('📄 Document Type:', req.body.documentType);
    console.log('📁 Fichier reçu:', req.file ? req.file.originalname : 'Aucun');

    if (!req.file) {
      return res.status(400).json({
        success: false,
        error: 'Aucun fichier fourni'
      });
    }

    // Vérifier que le médecin existe et appartient à l'utilisateur
    const doctor = await Doctor.findOne({
      _id: req.params.doctorId,
      userId: req.user._id
    });

    if (!doctor) {
      return res.status(404).json({
        success: false,
        error: 'Médecin non trouvé ou non autorisé'
      });
    }

    // Déterminer le dossier Cloudinary selon le type de document
    const documentType = req.body.documentType;
    let folder = `doctors_app/${req.user._id}`;
    let tags = ['doctor_documents', documentType];

    switch (documentType) {
      case 'license':
        folder += '/license';
        tags.push('medical_license');
        break;
      case 'diploma':
        folder += '/diplomas';
        tags.push('diploma');
        break;
      case 'certification':
        folder += '/certifications';
        tags.push('certification');
        break;
      case 'profile':
        folder += '/profile';
        tags.push('profile_photo');
        break;
      case 'clinic':
        folder += '/clinic';
        tags.push('clinic_photo');
        break;
      default:
        folder += '/documents';
    }

    console.log('📂 Dossier Cloudinary:', folder);
    console.log('🏷️ Tags:', tags);

    // Upload vers Cloudinary
    const uploadResult = await uploadToCloudinary(req.file.buffer, {
      folder: folder,
      tags: tags,
      public_id: `${documentType}_${Date.now()}`
    });

    console.log('✅ Upload Cloudinary réussi:', uploadResult.public_id);

    // Mettre à jour le document dans la base de données
    const documentData = {
      filename: uploadResult.public_id,
      originalName: req.file.originalname,
      url: uploadResult.secure_url,
      cloudinaryId: uploadResult.public_id,
      mimetype: req.file.mimetype,
      size: uploadResult.bytes,
      uploadedAt: new Date()
    };

    // Mettre à jour selon le type de document
    let updateQuery = {};
    
    switch (documentType) {
      case 'license':
        updateQuery = { 'documents.medicalLicense': documentData };
        break;
      case 'diploma':
        updateQuery = { $push: { 'documents.diplomas': documentData } };
        break;
      case 'certification':
        updateQuery = { $push: { 'documents.certifications': documentData } };
        break;
      case 'profile':
        updateQuery = { profilePhoto: documentData };
        break;
      case 'clinic':
        updateQuery = { $push: { 'clinic.photos': documentData } };
        break;
    }

    await Doctor.findByIdAndUpdate(req.params.doctorId, updateQuery);

    console.log('✅ Document sauvegardé en base de données');
    console.log('🏁 === FIN UPLOAD DOCUMENT ===\n');

    res.status(200).json({
      success: true,
      message: 'Document uploadé avec succès',
      data: {
        documentType: documentType,
        url: uploadResult.secure_url,
        cloudinaryId: uploadResult.public_id,
        originalName: req.file.originalname
      }
    });

  } catch (error) {
    console.error('❌ Erreur upload document:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de l\'upload du document',
      details: error.message
    });
  }
});

// @route   DELETE /api/upload/doctor/:doctorId/documents/:documentType/:cloudinaryId
// @desc    Supprimer un document
// @access  Private
router.delete('/doctor/:doctorId/documents/:documentType/:cloudinaryId', authenticate, async (req, res) => {
  try {
    console.log('\n🗑️ === DÉBUT SUPPRESSION DOCUMENT ===');
    console.log('👤 User ID:', req.user._id);
    console.log('🏥 Doctor ID:', req.params.doctorId);
    console.log('📄 Document Type:', req.params.documentType);
    console.log('☁️ Cloudinary ID:', req.params.cloudinaryId);

    // Vérifier que le médecin existe et appartient à l'utilisateur
    const doctor = await Doctor.findOne({
      _id: req.params.doctorId,
      userId: req.user._id
    });

    if (!doctor) {
      return res.status(404).json({
        success: false,
        error: 'Médecin non trouvé ou non autorisé'
      });
    }

    // Supprimer de Cloudinary
    const { deleteFromCloudinary } = require('../services/cloudinary');
    await deleteFromCloudinary(req.params.cloudinaryId);

    // Supprimer de la base de données selon le type
    const documentType = req.params.documentType;
    let updateQuery = {};

    switch (documentType) {
      case 'license':
        updateQuery = { $unset: { 'documents.medicalLicense': 1 } };
        break;
      case 'diploma':
        updateQuery = { $pull: { 'documents.diplomas': { cloudinaryId: req.params.cloudinaryId } } };
        break;
      case 'certification':
        updateQuery = { $pull: { 'documents.certifications': { cloudinaryId: req.params.cloudinaryId } } };
        break;
      case 'profile':
        updateQuery = { $unset: { profilePhoto: 1 } };
        break;
      case 'clinic':
        updateQuery = { $pull: { 'clinic.photos': { cloudinaryId: req.params.cloudinaryId } } };
        break;
    }

    await Doctor.findByIdAndUpdate(req.params.doctorId, updateQuery);

    console.log('✅ Document supprimé avec succès');
    console.log('🏁 === FIN SUPPRESSION DOCUMENT ===\n');

    res.status(200).json({
      success: true,
      message: 'Document supprimé avec succès'
    });

  } catch (error) {
    console.error('❌ Erreur suppression document:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la suppression du document',
      details: error.message
    });
  }
});

module.exports = router;
