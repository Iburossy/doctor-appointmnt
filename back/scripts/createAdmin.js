const mongoose = require('mongoose');
const User = require('../models/User');
require('dotenv').config();

async function createAdmin() {
  try {
    // Connexion à MongoDB
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/doctors_app');
    console.log('✅ Connexion MongoDB réussie');

    // Vérifier si un admin existe déjà
    const existingAdmin = await User.findOne({ role: 'admin' });
    
    if (existingAdmin) {
      console.log('⚠️  Un administrateur existe déjà:', existingAdmin.email);
      console.log('🗑️  Suppression de l\'administrateur existant...');
      await User.deleteOne({ role: 'admin' });
      console.log('✅  Administrateur supprimé avec succès');
    }

    // Créer l'administrateur
    const adminData = {
      firstName: 'cheikh',
      lastName: 'dillo',
      phone: '+221777750078',
      email: process.env.ADMIN_EMAIL || 'doctors@app.sn',
      password: process.env.ADMIN_PASSWORD || 'passer@1',
      role: 'admin',
      isPhoneVerified: true,
      isEmailVerified: true,
      isActive: true,
      language: 'fr'
    };

    const admin = new User(adminData);
    await admin.save();

    console.log('🎉 Administrateur créé avec succès !');
    console.log('📧 Email:', admin.email);
    console.log('📱 Téléphone:', admin.phone);
    console.log('🔑 Mot de passe:', process.env.ADMIN_PASSWORD || 'passer@1');
    console.log('');
    console.log('⚠️  IMPORTANT: Changez le mot de passe après la première connexion !');

  } catch (error) {
    console.error('❌ Erreur lors de la création de l\'admin:', error);
  } finally {
    await mongoose.disconnect();
    console.log('🔌 Connexion MongoDB fermée');
    process.exit(0);
  }
}

// Exécuter le script
if (require.main === module) {
  createAdmin();
}

module.exports = createAdmin;
