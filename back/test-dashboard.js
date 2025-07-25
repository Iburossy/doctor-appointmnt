/**
 * Script de diagnostic pour le dashboard admin
 */

const mongoose = require('mongoose');
const User = require('./models/User');
const Doctor = require('./models/Doctor');
const Appointment = require('./models/Appointment');
require('dotenv').config();

async function testDashboard() {
  try {
    // Connexion à MongoDB
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/doctors_app');
    console.log('✅ Connexion MongoDB réussie');

    console.log('\n🔍 Diagnostic du dashboard admin');

    // Test 1: Statistiques générales
    console.log('\n--- Statistiques générales ---');
    const totalUsers = await User.countDocuments({ isActive: true });
    const totalPatients = await User.countDocuments({ role: 'patient', isActive: true });
    const totalDoctors = await Doctor.countDocuments({ verificationStatus: 'approved', isActive: true });
    const pendingDoctors = await Doctor.countDocuments({ verificationStatus: 'pending' });
    
    console.log(`Utilisateurs actifs: ${totalUsers}`);
    console.log(`Patients actifs: ${totalPatients}`);
    console.log(`Médecins approuvés: ${totalDoctors}`);
    console.log(`Médecins en attente: ${pendingDoctors}`);

    // Test 2: Statistiques des rendez-vous
    console.log('\n--- Statistiques des rendez-vous ---');
    const totalAppointments = await Appointment.countDocuments();
    console.log(`Total rendez-vous: ${totalAppointments}`);

    // Test 3: Vérifier la structure des données Doctor
    console.log('\n--- Structure des données Doctor ---');
    const sampleDoctor = await Doctor.findOne().lean();
    if (sampleDoctor) {
      console.log('Champs disponibles dans Doctor:');
      Object.keys(sampleDoctor).forEach(key => {
        console.log(`  - ${key}: ${typeof sampleDoctor[key]}`);
      });
    } else {
      console.log('⚠️ Aucun médecin trouvé dans la base');
    }

    // Test 4: Test de l'agrégation problématique
    console.log('\n--- Test agrégation top médecins ---');
    try {
      const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
      
      const topDoctors = await Appointment.aggregate([
        {
          $match: {
            status: 'completed',
            createdAt: { $gte: thirtyDaysAgo }
          }
        },
        {
          $group: {
            _id: '$doctor',
            appointmentCount: { $sum: 1 }
          }
        },
        {
          $lookup: {
            from: 'doctors',
            localField: '_id',
            foreignField: '_id',
            as: 'doctorInfo'
          }
        },
        {
          $unwind: '$doctorInfo'
        },
        {
          $lookup: {
            from: 'users',
            localField: 'doctorInfo.userId',
            foreignField: '_id',
            as: 'userInfo'
          }
        },
        {
          $unwind: '$userInfo'
        },
        {
          $project: {
            appointmentCount: 1,
            doctorName: {
              $concat: ['$userInfo.firstName', ' ', '$userInfo.lastName']
            },
            specialties: '$doctorInfo.specialties'
          }
        },
        {
          $sort: { appointmentCount: -1 }
        },
        {
          $limit: 5
        }
      ]);

      console.log('✅ Agrégation réussie');
      console.log(`Top médecins trouvés: ${topDoctors.length}`);
      
    } catch (error) {
      console.log('❌ Erreur dans l\'agrégation:', error.message);
    }

    console.log('\n✅ Diagnostic terminé');

  } catch (error) {
    console.error('❌ Erreur lors du diagnostic:', error);
  } finally {
    await mongoose.disconnect();
    console.log('🔌 Connexion MongoDB fermée');
  }
}

// Exécuter le diagnostic
testDashboard();
