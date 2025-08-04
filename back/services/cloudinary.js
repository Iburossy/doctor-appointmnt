const cloudinary = require('cloudinary').v2;

// Configuration Cloudinary
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

/**
 * Upload un fichier vers Cloudinary
 * @param {Buffer} fileBuffer - Buffer du fichier
 * @param {Object} options - Options d'upload
 * @returns {Promise<Object>} - Résultat de l'upload
 */
const uploadToCloudinary = async (fileBuffer, options = {}) => {
  try {
    console.log('📤 Upload vers Cloudinary...');
    
    return new Promise((resolve, reject) => {
      cloudinary.uploader.upload_stream(
        {
          resource_type: 'auto', // Détecte automatiquement le type (image, video, raw)
          folder: options.folder || process.env.CLOUDINARY_DEFAULT_FOLDER || 'doctors_app', // Dossier dans Cloudinary
          public_id: options.public_id, // ID personnalisé (optionnel)
          transformation: options.transformation, // Transformations (resize, etc.)
          tags: options.tags || (process.env.CLOUDINARY_DEFAULT_TAGS || 'doctor_documents').split(','), // Tags pour organiser
        },
        (error, result) => {
          if (error) {
            console.error('❌ Erreur upload Cloudinary:', error);
            reject(error);
          } else {
            console.log('✅ Upload Cloudinary réussi:', result.public_id);
            resolve({
              public_id: result.public_id,
              secure_url: result.secure_url,
              url: result.url,
              format: result.format,
              resource_type: result.resource_type,
              bytes: result.bytes,
              width: result.width,
              height: result.height,
              created_at: result.created_at
            });
          }
        }
      ).end(fileBuffer);
    });
  } catch (error) {
    console.error('❌ Erreur service Cloudinary:', error);
    throw error;
  }
};

/**
 * Supprime un fichier de Cloudinary
 * @param {string} publicId - ID public du fichier à supprimer
 * @returns {Promise<Object>} - Résultat de la suppression
 */
const deleteFromCloudinary = async (publicId) => {
  try {
    console.log('🗑️ Suppression de Cloudinary:', publicId);
    const result = await cloudinary.uploader.destroy(publicId);
    console.log('✅ Suppression réussie:', result);
    return result;
  } catch (error) {
    console.error('❌ Erreur suppression Cloudinary:', error);
    throw error;
  }
};

/**
 * Upload multiple fichiers vers Cloudinary
 * @param {Array} files - Tableau de fichiers avec buffer et metadata
 * @param {Object} options - Options d'upload
 * @returns {Promise<Array>} - Résultats des uploads
 */
const uploadMultipleToCloudinary = async (files, options = {}) => {
  try {
    console.log(`📤 Upload de ${files.length} fichiers vers Cloudinary...`);
    
    const uploadPromises = files.map((file, index) => {
      const fileOptions = {
        ...options,
        public_id: options.public_id ? `${options.public_id}_${index}` : undefined,
        tags: [...(options.tags || []), file.fieldname]
      };
      
      return uploadToCloudinary(file.buffer, fileOptions);
    });
    
    const results = await Promise.all(uploadPromises);
    console.log(`✅ ${results.length} fichiers uploadés avec succès`);
    return results;
  } catch (error) {
    console.error('❌ Erreur upload multiple Cloudinary:', error);
    throw error;
  }
};

module.exports = {
  uploadToCloudinary,
  deleteFromCloudinary,
  uploadMultipleToCloudinary,
  cloudinary
};
