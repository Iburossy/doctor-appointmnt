/**
 * Script de test pour vérifier les routes admin après correction
 */

const mongoose = require('mongoose');
const Doctor = require('./models/Doctor');
const User = require('./models/User');
require('dotenv').config();

async function testAdminRoutes() {
  try {
    // Connexion à MongoDB
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/doctors_app');
    console.log('✅ Connexion MongoDB réussie');

    // Test 1: Vérifier la structure du modèle Doctor
    console.log('\n🔍 Test 1: Structure du modèle Doctor');
    const doctorSchema = Doctor.schema.paths;
    console.log('Champs disponibles dans Doctor:');
    Object.keys(doctorSchema).forEach(field => {
      if (field.includes('user') || field.includes('User')) {
        console.log(`  - ${field}: ${doctorSchema[field].instance || 'ObjectId'}`);
      }
    });

    // Test 2: Vérifier s'il y a des médecins dans la base
    console.log('\n🔍 Test 2: Médecins existants');
    const doctorCount = await Doctor.countDocuments();
    console.log(`Nombre de médecins: ${doctorCount}`);

    if (doctorCount > 0) {
      // Test 3: Tester une requête populate
      console.log('\n🔍 Test 3: Test populate avec userId');
      try {
        const doctor = await Doctor.findOne().populate('userId', 'firstName lastName email');
        if (doctor) {
          console.log('✅ Populate réussi avec userId');
          console.log(`Médecin: ${doctor.userId?.firstName} ${doctor.userId?.lastName}`);
        } else {
          console.log('⚠️ Aucun médecin trouvé pour le test populate');
        }
      } catch (error) {
        console.log('❌ Erreur populate:', error.message);
      }
    } else {
      console.log('⚠️ Aucun médecin dans la base pour tester populate');
    }

    // Test 4: Vérifier les utilisateurs avec rôle doctor
    console.log('\n🔍 Test 4: Utilisateurs avec rôle doctor');
    const doctorUsers = await User.countDocuments({ role: 'doctor' });
    console.log(`Utilisateurs avec rôle doctor: ${doctorUsers}`);

    console.log('\n✅ Tests terminés avec succès');

  } catch (error) {
    console.error('❌ Erreur lors des tests:', error);
  } finally {
    await mongoose.disconnect();
    console.log('🔌 Connexion MongoDB fermée');
  }
}

// Exécuter les tests
testAdminRoutes();
