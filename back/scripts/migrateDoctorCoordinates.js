/**
 * Script de migration pour convertir les coordonnées des médecins
 * de l'ancien format {latitude, longitude} au format GeoJSON {type: "Point", coordinates: [lng, lat]}
 */

const mongoose = require('mongoose');
const config = require('../config');
const Doctor = require('../models/Doctor');

async function connectDB() {
  try {
    await mongoose.connect(config.mongoURI);
    console.log('✅ Connexion MongoDB réussie');
  } catch (err) {
    console.error('❌ Erreur de connexion MongoDB:', err.message);
    process.exit(1);
  }
}

async function migrateCoordinates() {
  try {
    console.log('🔄 Début de la migration des coordonnées...');
    
    // Récupérer tous les médecins
    const doctors = await Doctor.find({}).lean();
    console.log(`📊 ${doctors.length} médecins trouvés dans la base de données`);
    
    let successCount = 0;
    let errorCount = 0;
    
    // Pour chaque médecin
    for (const doctor of doctors) {
      try {
        // Vérifier si les coordonnées existent dans l'ancien format
        if (
          doctor.clinic && 
          doctor.clinic.address && 
          doctor.clinic.address.coordinates &&
          doctor.clinic.address.coordinates.latitude !== undefined &&
          doctor.clinic.address.coordinates.longitude !== undefined
        ) {
          const latitude = doctor.clinic.address.coordinates.latitude;
          const longitude = doctor.clinic.address.coordinates.longitude;
          
          console.log(`🔄 Migration du médecin ${doctor._id} - [${latitude}, ${longitude}]`);
          
          // Mettre à jour vers le nouveau format GeoJSON
          await Doctor.updateOne(
            { _id: doctor._id },
            { 
              $set: { 
                "clinic.address.location": {
                  type: "Point",
                  coordinates: [longitude, latitude] // Format GeoJSON: [longitude, latitude]
                }
              },
              $unset: { "clinic.address.coordinates": "" } // Supprimer l'ancien champ
            }
          );
          
          successCount++;
        } else {
          // Si le médecin a déjà le nouveau format ou n'a pas de coordonnées
          console.log(`⏭️ Médecin ${doctor._id} ignoré (format déjà correct ou pas de coordonnées)`);
        }
      } catch (error) {
        console.error(`❌ Erreur lors de la migration du médecin ${doctor._id}:`, error);
        errorCount++;
      }
    }
    
    console.log('✅ Migration terminée!');
    console.log(`📊 Résultats: ${successCount} médecins migrés avec succès, ${errorCount} erreurs`);
    
    // Reconstruire l'index 2dsphere
    console.log('🔄 Reconstruction de l\'index 2dsphere...');
    await Doctor.collection.createIndex({ "clinic.address.location": "2dsphere" });
    console.log('✅ Index 2dsphere recréé avec succès');
    
  } catch (error) {
    console.error('❌ Erreur générale lors de la migration:', error);
  } finally {
    mongoose.disconnect();
    console.log('👋 Déconnexion de MongoDB');
  }
}

// Exécuter la migration
connectDB()
  .then(() => migrateCoordinates())
  .catch((err) => {
    console.error('❌ Erreur:', err);
    process.exit(1);
  });
